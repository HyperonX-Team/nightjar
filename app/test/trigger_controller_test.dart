import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/core/constants.dart';
import 'package:nightjar/features/incident/incident.dart';
import 'package:nightjar/features/incident/sms_sender.dart';
import 'package:nightjar/features/trigger/trigger_controller.dart';

import 'support/fakes.dart';

void main() {
  test('refuses to start without a PIN', () async {
    final harness = await buildHarness(withPin: false);
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.notReady);
    expect(harness.writer.created, isEmpty);
    expect(harness.keeper.starts, 0);
  });

  test('refuses to start without three contacts', () async {
    final harness = await buildHarness(contactCount: 2);
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.notReady);
    expect(harness.writer.created, isEmpty);
  });

  test('a PIN trigger runs the full pipeline', () async {
    final harness = await buildHarness();
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.started);
    await harness.controller.whenFinished();

    expect(harness.keeper.starts, 1);
    expect(harness.keeper.stops, 1);
    expect(harness.writer.created.single.trigger, TriggerKind.pin);
    expect(harness.writer.fixes, isNotEmpty);
    expect(harness.writer.ended, contains('token0'));
    expect(harness.messenger.calls, 1);
    expect(harness.messenger.phones, hasLength(3));
    expect(harness.messenger.message, contains('/i/token0'));
    expect(harness.messenger.message, contains('Alert from Amal.'));
    expect(harness.writer.deliveries.single, hasLength(3));
    expect(
      harness.writer.deliveries.single.every((entry) => entry.status == 'sent'),
      isTrue,
    );
    expect(harness.writer.audioStatuses, contains(AudioStatus.ready));
    expect(harness.uploader.calls, 1);
    expect(await harness.queue.read(), isNull);
    expect(harness.controller.state, TriggerState.idle);
    expect(harness.controller.endedAt, isNotNull);
  });

  test('a test trigger uses the short windows and reports delivery', () async {
    final harness = await buildHarness();
    expect(
      await harness.controller.trigger(TriggerKind.test),
      TriggerDecision.started,
    );
    final delivered = await harness.controller.deliveryResult();
    expect(delivered, hasLength(3));
    await harness.controller.whenFinished();
    expect(harness.writer.created.single.trigger, TriggerKind.test);
    expect(
      harness.writer.created.single.expiresAt.difference(
        harness.writer.created.single.createdAt,
      ),
      const Duration(hours: 1),
    );
  });

  test('a missing fresh fix still sends the page link', () async {
    final harness = await buildHarness(location: FakeLocation());
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.messenger.calls, 1);
    expect(harness.messenger.message, isNot(contains('maps.google.com')));
    expect(harness.messenger.message, contains('/i/token0'));
    expect(harness.writer.fixes, isEmpty);
  });

  test('a cached fix is published as provisional', () async {
    final harness = await buildHarness(
      location: FakeLocation(cached: sampleFix(accuracy: 40)),
    );
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.writer.fixes, hasLength(1));
    expect(harness.messenger.message, contains('maps.google.com'));
  });

  test('location updates keep arriving inside the window', () async {
    final harness = await buildHarness(
      location: FakeLocation(fresh: sampleFix(), stream: [sampleFix()]),
    );
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.writer.fixes.length, greaterThanOrEqualTo(1));
  });

  test('a failed upload keeps the queue entry and marks the audio failed',
      () async {
    final uploader = FakeUploader()..result = false;
    final harness = await buildHarness(uploader: uploader);
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.writer.audioStatuses, contains(AudioStatus.failed));
    expect(await harness.queue.read(), isNotNull);
  });

  test('recording without a file marks the audio failed', () async {
    final harness = await buildHarness(
      audio: FakeAudio(status: AudioStatus.failed, path: null),
    );
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.writer.audioStatuses, contains(AudioStatus.failed));
    expect(harness.uploader.calls, 0);
  });

  test('a cancelled alert before five seconds discards the audio', () async {
    final harness = await buildHarness(
      audio: FakeAudio(status: AudioStatus.partial, durationSec: 2),
    );
    await harness.controller.trigger(TriggerKind.pin);
    await waitForActive(harness.controller);
    await harness.controller.cancel();
    await harness.controller.whenFinished();
    expect(harness.uploader.calls, 0);
    expect(harness.writer.audioStatuses, contains(AudioStatus.failed));
    expect(await harness.queue.read(), isNull);
    expect(harness.writer.ended, contains('token0'));
  });

  test('a cancelled alert after five seconds keeps a partial recording',
      () async {
    final harness = await buildHarness(
      audio: FakeAudio(status: AudioStatus.partial, durationSec: 12),
    );
    await harness.controller.trigger(TriggerKind.pin);
    await waitForActive(harness.controller);
    await harness.controller.cancel();
    await harness.controller.whenFinished();
    expect(harness.uploader.calls, 1);
    expect(harness.writer.audioStatuses, contains(AudioStatus.partial));
  });

  test('cancelling before the SMS phase sends no message', () async {
    final location = FakeLocation(fresh: sampleFix())
      ..firstFixDelay = const Duration(milliseconds: 400);
    final harness = await buildHarness(location: location);
    await harness.controller.trigger(TriggerKind.pin);
    await waitForActive(harness.controller);
    await harness.controller.cancel();
    await harness.controller.whenFinished();
    expect(harness.messenger.calls, 0);
    expect(harness.writer.ended, contains('token0'));
  });

  test('a second trigger during an active alert is refused', () async {
    final harness = await buildHarness();
    await harness.controller.trigger(TriggerKind.pin);
    expect(
      await harness.controller.trigger(TriggerKind.pin),
      TriggerDecision.busy,
    );
    await harness.controller.cancel();
    await harness.controller.whenFinished();
  });

  test('the cooldown blocks a new trigger until it expires', () async {
    final harness = await buildHarness();
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    expect(harness.controller.cooldownRemaining(), greaterThan(Duration.zero));
    expect(
      await harness.controller.trigger(TriggerKind.pin),
      TriggerDecision.busy,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.started);
    await harness.controller.whenFinished();
  });

  test('a failed service start leaves no incident behind', () async {
    final harness = await buildHarness();
    harness.keeper.startResult = false;
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.started);
    await harness.controller.whenFinished();
    expect(harness.keeper.stops, 0);
    expect(harness.writer.created, isEmpty);
    expect(harness.controller.state, TriggerState.idle);
  });

  test('cancel only needs an active run', () async {
    final harness = await buildHarness();
    await harness.controller.trigger(TriggerKind.pin);
    expect(harness.controller.isActive, isTrue);
    await harness.controller.cancel();
    await harness.controller.whenFinished();
    expect(harness.controller.isActive, isFalse);
  });

  test('a trigger without setup completes the delivery future', () async {
    final harness = await buildHarness(withPin: false);
    expect(await harness.controller.trigger(TriggerKind.pin),
        TriggerDecision.notReady);
    expect(await harness.controller.deliveryResult(), isEmpty);
  });

  test('contact data never reaches the incident writer', () async {
    final harness = await buildHarness();
    await harness.controller.trigger(TriggerKind.pin);
    await harness.controller.whenFinished();
    final incident = harness.writer.created.single;
    expect(incident.ownerName, 'Amal');
    expect(harness.writer.deliveries.single.first.channel, 'sms');
    expect(
      harness.writer.deliveries.single.first.toMap().containsKey('phone'),
      isFalse,
    );
  });

  test('three contacts are alerted through the platform messenger', () async {
    final harness = await buildHarness();
    await harness.controller.trigger(TriggerKind.pin);
    final results = await harness.controller.deliveryResult();
    expect(results, hasLength(3));
    expect(
      results.every((result) => result.status == SmsResult.sent),
      isTrue,
    );
    await harness.controller.whenFinished();
  });

  test('the default cooldown and windows match the spec', () {
    const config = TriggerConfig();
    expect(config.cooldown, Timing.triggerCooldown);
    expect(config.recordingWindow, Timing.recordingWindow);
    expect(config.locationWindow, Timing.locationWindow);
    expect(config.firstFixTimeout, Timing.firstFixTimeout);
    expect(config.hardCap, Timing.serviceHardCap);
    expect(config.cancelUploadGrace, const Duration(seconds: 5));
  });
}
