import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/incident/audio_recorder.dart';
import 'package:nightjar/features/incident/incident.dart';
import 'package:nightjar/features/incident/incident_repository.dart';
import 'package:nightjar/features/incident/location_tracker.dart';
import 'package:nightjar/features/incident/sms_sender.dart';
import 'package:nightjar/features/incident/upload_queue.dart';
import 'package:nightjar/features/trigger/pin_hasher.dart';
import 'package:nightjar/features/trigger/trigger_controller.dart';
import 'package:nightjar/services/foreground_service.dart';
import 'package:nightjar/services/secure_store.dart';

class FakeWriter implements IncidentWriter {
  final List<Incident> created = <Incident>[];
  final List<AcceptedFix> fixes = <AcceptedFix>[];
  final List<List<DeliveryEntry>> deliveries = <List<DeliveryEntry>>[];
  final List<AudioStatus> audioStatuses = <AudioStatus>[];
  final List<String> ended = <String>[];

  @override
  Future<Incident> create({
    required TriggerKind trigger,
    required String ownerName,
    required String appVersion,
  }) async {
    final now = DateTime(2026, 10, 17, 12);
    final incident = Incident(
      token: 'token${created.length}',
      ownerUid: 'uid',
      trigger: trigger,
      createdAt: now,
      expiresAt: expiryFor(trigger, now),
      appVersion: appVersion,
      ownerName: ownerName,
    );
    created.add(incident);
    return incident;
  }

  @override
  Future<void> publishFix({
    required Incident incident,
    required AcceptedFix fix,
  }) async {
    fixes.add(fix);
  }

  @override
  Future<void> publishDelivery({
    required String token,
    required List<DeliveryEntry> delivery,
  }) async {
    deliveries.add(delivery);
  }

  @override
  Future<void> publishAudio({
    required String token,
    required AudioStatus status,
    String? path,
    int? durationSec,
    int? sizeBytes,
  }) async {
    audioStatuses.add(status);
  }

  @override
  Future<void> markEnded({required String token}) async {
    ended.add(token);
  }
}

class FakeAudio implements AudioCapture {
  FakeAudio({
    this.status = AudioStatus.ready,
    this.path = '/nonexistent/nightjar/token.m4a',
    this.durationSec = 30,
  });

  AudioStatus status;
  String? path;
  int durationSec;
  bool started = false;

  @override
  Future<AudioCaptureResult> record({
    required String token,
    required Duration duration,
  }) async {
    started = true;
    await Future<void>.delayed(duration);
    return AudioCaptureResult(
      status: status,
      path: path,
      durationSec: durationSec,
      sizeBytes: 1024,
    );
  }

  @override
  Future<void> stopEarly() async {}

  @override
  Future<void> dispose() async {}
}

class FakeLocation implements LocationSource {
  FakeLocation({this.cached, this.fresh, this.stream});

  AcceptedFix? cached;
  AcceptedFix? fresh;
  List<AcceptedFix>? stream;
  Duration? firstFixDelay;

  @override
  Future<AcceptedFix?> cachedFix() async => cached;

  @override
  Future<AcceptedFix?> firstFix(Duration timeout) async {
    if (firstFixDelay != null) {
      await Future<void>.delayed(firstFixDelay!);
    }
    return fresh;
  }

  @override
  Stream<AcceptedFix> updates(Duration throttle) =>
      Stream<AcceptedFix>.fromIterable(stream ?? const <AcceptedFix>[]);
}

class FakeMessenger implements AlertMessenger {
  List<SmsResult> results = const <SmsResult>[
    SmsResult(status: SmsResult.sent),
    SmsResult(status: SmsResult.sent),
    SmsResult(status: SmsResult.sent),
  ];

  List<String>? phones;
  String? message;
  int calls = 0;

  @override
  Future<List<SmsResult>> sendAlerts({
    required List<String> phones,
    required String message,
    required String token,
  }) async {
    calls++;
    this.phones = phones;
    this.message = message;
    return results;
  }
}

class FakeKeeper implements ProcessKeeper {
  int starts = 0;
  int stops = 0;
  bool startResult = true;

  @override
  Future<bool> start() async {
    starts++;
    return startResult;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class FakeUploader implements AudioUploader {
  bool result = true;
  int calls = 0;

  @override
  Future<bool> upload({
    required String token,
    required String path,
    required int durationSec,
    required DateTime recordedAt,
  }) async {
    calls++;
    return result;
  }
}

/// A stand in for the isolate PBKDF2 path: fast, and no platform channels.
/// The "hash" is the PIN itself, so a record written by this fake can be
/// verified by any instance.
class FakePinService implements PinService {
  FakePinService([this.knownPin]);

  final String? knownPin;

  @override
  Future<PinRecord> create(String pin) async => PinRecord(
        salt: Uint8List(16),
        iterations: 1,
        hash: Uint8List.fromList(
          pin.codeUnits.take(32).toList(growable: false),
        ),
        length: pin.length,
      );

  @override
  Future<bool> verify(String pin, PinRecord record) async {
    final candidate = pin.codeUnits.take(32).toList(growable: false);
    if (candidate.length == record.hash.length) {
      var matches = true;
      for (var i = 0; i < candidate.length; i++) {
        if (candidate[i] != record.hash[i]) {
          matches = false;
        }
      }
      if (matches) {
        return true;
      }
    }
    return knownPin != null && pin == knownPin;
  }
}

class FakeTriggerServiceFactory implements TriggerServiceFactory {
  FakeTriggerServiceFactory(this.controller);

  final TriggerController controller;
  int builds = 0;

  @override
  Future<TriggerController> build() async {
    builds++;
    return controller;
  }
}

AcceptedFix sampleFix({double accuracy = 20}) => AcceptedFix(
      latitude: 1.3521,
      longitude: 103.8198,
      accuracyMeters: accuracy,
      at: DateTime(2026, 10, 17, 12),
    );

/// Scales the spec windows down so tests run in milliseconds.
const testConfig = TriggerConfig(
  debounce: Duration(milliseconds: 10),
  cooldown: Duration(milliseconds: 60),
  recordingWindow: Duration(milliseconds: 60),
  testRecordingWindow: Duration(milliseconds: 40),
  locationWindow: Duration(milliseconds: 80),
  testLocationWindow: Duration(milliseconds: 60),
  firstFixTimeout: Duration(milliseconds: 30),
  hardCap: Duration(seconds: 5),
  locationThrottle: Duration(milliseconds: 10),
  cancelUploadGrace: Duration(seconds: 5),
);

typedef Harness = ({
  TriggerController controller,
  FakeTriggerServiceFactory factory,
  FakeWriter writer,
  FakeAudio audio,
  FakeLocation location,
  FakeMessenger messenger,
  FakeKeeper keeper,
  MemoryUploads queue,
  FakeUploader uploader,
  SetupStore store,
});

Future<Harness> buildHarness({
  bool withPin = true,
  int contactCount = 3,
  TriggerConfig config = testConfig,
  FakeAudio? audio,
  FakeLocation? location,
  FakeUploader? uploader,
  PinService? pinService,
}) async {
  final store = SetupStore(MemorySecretStore());
  if (withPin) {
    await store.writePin(
      pinService == null
          ? PinHasher.create('4826')
          : await pinService.create('4826'),
    );
  }
  await store.writeContacts([
    for (var i = 0; i < contactCount; i++)
      Contact(name: 'Contact $i', phone: '+65912345${i.toString()}7'),
  ]);
  await store.writeOwnerName('Amal');
  final writer = FakeWriter();
  final audioFake = audio ?? FakeAudio();
  final locationFake = location ?? FakeLocation(fresh: sampleFix());
  final messenger = FakeMessenger();
  final keeper = FakeKeeper();
  final queue = MemoryUploads();
  final uploaderFake = uploader ?? FakeUploader();
  final controller = TriggerController(
    config: config,
    services: TriggerServices(
      store: store,
      writer: writer,
      audio: audioFake,
      location: locationFake,
      messenger: messenger,
      keeper: keeper,
      queue: queue,
      uploader: uploaderFake,
      appVersion: '1.0.0+1',
    ),
  );
  return (
    controller: controller,
    factory: FakeTriggerServiceFactory(controller),
    writer: writer,
    audio: audioFake,
    location: locationFake,
    messenger: messenger,
    keeper: keeper,
    queue: queue,
    uploader: uploaderFake,
    store: store,
  );
}

/// Waits until the incident document exists and the pipeline is active, so a
/// cancel lands inside the recording window rather than during startup.
Future<void> waitForActive(TriggerController controller) async {
  for (var attempt = 0;
      attempt < 500 && controller.state != TriggerState.active;
      attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(controller.state, TriggerState.active);
}
