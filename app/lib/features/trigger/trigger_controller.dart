import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/foreground_service.dart';
import '../../services/secure_store.dart';
import '../incident/audio_recorder.dart';
import '../incident/incident.dart';
import '../incident/incident_repository.dart';
import '../incident/location_tracker.dart';
import '../incident/sms_sender.dart';
import '../incident/upload_queue.dart';

enum TriggerState { idle, starting, active, canceling, finalizing, ended, error }

enum TriggerDecision { started, busy, notReady }

class TriggerConfig {
  const TriggerConfig({
    this.debounce = Timing.triggerDebounce,
    this.cooldown = Timing.triggerCooldown,
    this.recordingWindow = Timing.recordingWindow,
    this.testRecordingWindow = Timing.testRecordingWindow,
    this.locationWindow = Timing.locationWindow,
    this.testLocationWindow = Timing.testLocationWindow,
    this.firstFixTimeout = Timing.firstFixTimeout,
    this.hardCap = Timing.serviceHardCap,
    this.locationThrottle = Timing.locationThrottle,
    this.cancelUploadGrace = const Duration(seconds: 5),
  });

  final Duration debounce;
  final Duration cooldown;
  final Duration recordingWindow;
  final Duration testRecordingWindow;
  final Duration locationWindow;
  final Duration testLocationWindow;
  final Duration firstFixTimeout;
  final Duration hardCap;
  final Duration locationThrottle;
  final Duration cancelUploadGrace;
}

class TriggerServices {
  const TriggerServices({
    required this.store,
    required this.writer,
    required this.audio,
    required this.location,
    required this.messenger,
    required this.keeper,
    required this.queue,
    required this.uploader,
    required this.appVersion,
  });

  final SetupStore store;
  final IncidentWriter writer;
  final AudioCapture audio;
  final LocationSource location;
  final AlertMessenger messenger;
  final ProcessKeeper keeper;
  final PendingUploads queue;
  final AudioUploader uploader;
  final String appVersion;
}

/// Runs one alert at a time (SPEC 27).
class TriggerController {
  TriggerController({required this.services, this.config = const TriggerConfig()});

  final TriggerServices services;
  final TriggerConfig config;

  TriggerState _state = TriggerState.idle;
  DateTime? _endedAt;
  _Session? _session;
  Future<void>? _finished;
  bool _cancelRequested = false;
  List<SmsResult> _lastDelivery = const <SmsResult>[];
  Completer<List<SmsResult>> _delivery = Completer<List<SmsResult>>();

  TriggerState get state => _state;

  /// Completes when the SMS phase of the current run ends, so the test alert
  /// screen can report per-contact results without waiting for the location
  /// window (SPEC 23.6).
  Future<List<SmsResult>> deliveryResult() => _delivery.future;

  bool get isActive => switch (_state) {
        TriggerState.idle ||
        TriggerState.ended ||
        TriggerState.error =>
          false,
        _ => true,
      };

  DateTime? get endedAt => _endedAt;

  List<SmsResult> get lastDelivery => List.unmodifiable(_lastDelivery);

  Future<void>? whenFinished() => _finished;

  Duration cooldownRemaining() {
    final endedAt = _endedAt;
    if (endedAt == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(endedAt);
    return elapsed >= config.cooldown ? Duration.zero : config.cooldown - elapsed;
  }

  /// Returns quickly: the pipeline continues in [_run]. The caller clears the
  /// display and pulses haptics before calling this (SPEC 13.3).
  Future<TriggerDecision> trigger(TriggerKind kind) async {
    if (_state != TriggerState.idle || cooldownRemaining() > Duration.zero) {
      _delivery = Completer<List<SmsResult>>()..complete(const <SmsResult>[]);
      return TriggerDecision.busy;
    }
    final contacts = await services.store.readContacts();
    final pin = await services.store.readPin();
    if (pin == null || contacts.length < ContactRules.required) {
      _delivery = Completer<List<SmsResult>>()..complete(const <SmsResult>[]);
      return TriggerDecision.notReady;
    }
    _cancelRequested = false;
    _lastDelivery = const <SmsResult>[];
    _delivery = Completer<List<SmsResult>>();
    _state = TriggerState.starting;
    _finished = _run(kind, contacts);
    return TriggerDecision.started;
  }

  Future<void> cancel() async {
    if (!isActive) {
      return;
    }
    _cancelRequested = true;
    _state = TriggerState.canceling;
    await services.audio.stopEarly();
    final session = _session;
    session?.cancelled = true;
    if (session != null && !session.locationDone.isCompleted) {
      session.locationDone.complete();
    }
    if (session != null) {
      _stopLocation(session);
    }
    await _finished;
  }

  Future<void> _run(TriggerKind kind, List<Contact> contacts) async {
    final test = kind == TriggerKind.test;
    final recordingWindow =
        test ? config.testRecordingWindow : config.recordingWindow;
    final locationWindow =
        test ? config.testLocationWindow : config.locationWindow;
    Incident? incident;
    var keeperReady = false;
    try {
      // The service starts before the incident document is written: the write
      // needs the network, and the service is what keeps the process alive
      // while it completes (SPEC 33.2 timing budgets).
      keeperReady = await services.keeper.start();
      if (!keeperReady || _cancelRequested) {
        await _cleanup();
        return;
      }
      final ownerName = await services.store.readOwnerName();
      incident = await services.writer.create(
        trigger: kind,
        ownerName: ownerName,
        appVersion: services.appVersion,
      );
      if (_cancelRequested) {
        await _safe(() => services.writer.markEnded(token: incident!.token));
        await _cleanup(keeperReady: keeperReady);
        return;
      }
      final session = _Session(
        incident: incident,
        recordingWindow: recordingWindow,
        locationWindow: locationWindow,
      );
      _session = session;
      _state = TriggerState.active;
      session.hardCap = Timer(config.hardCap, () {
        session.cancelled = true;
        if (!session.locationDone.isCompleted) {
          session.locationDone.complete();
        }
      });

      final capture = services.audio.record(
        token: incident.token,
        duration: recordingWindow,
      );
      final provisional = await services.location.cachedFix();
      if (provisional != null) {
        await _safePublish(session, provisional);
      }
      final fresh = await services.location.firstFix(config.firstFixTimeout);
      if (fresh != null) {
        await _safePublish(session, fresh);
      }
      if (!session.cancelled) {
        await _sendAlerts(session, contacts, fresh ?? provisional);
      }

      final locationDone = _runLocationWindow(session);
      final captureResult = await capture;
      await _handleAudio(session, captureResult);
      await locationDone;

      // The incident ends whether it ran its full window or was cancelled
      // (SPEC 27.2, 13.3 step 12).
      await _safe(() => services.writer.markEnded(token: incident!.token));
      await _cleanup(keeperReady: keeperReady);
    } catch (_) {
      if (incident != null) {
        await _safe(() => services.writer.markEnded(token: incident!.token));
      }
      await _cleanup(keeperReady: keeperReady);
      _state = TriggerState.error;
      _state = TriggerState.idle;
    }
  }

  Future<void> _sendAlerts(
    _Session session,
    List<Contact> contacts,
    AcceptedFix? fix,
  ) async {
    final ownerName = await services.store.readOwnerName();
    final message = MessageComposer.build(
      ownerName: ownerName,
      token: session.incident.token,
      fix: fix,
    );
    final results = await services.messenger.sendAlerts(
      phones: [for (final contact in contacts) contact.phone],
      message: message,
      token: session.incident.token,
    );
    _lastDelivery = results;
    if (!_delivery.isCompleted) {
      _delivery.complete(results);
    }
    await _safe(
      () => services.writer.publishDelivery(
        token: session.incident.token,
        delivery: [
          for (final result in results)
            DeliveryEntry(channel: 'sms', status: result.status),
        ],
      ),
    );
  }

  Future<void> _runLocationWindow(_Session session) async {
    session.locationSub = services.location
        .updates(config.locationThrottle)
        .listen((fix) => _safePublish(session, fix));
    session.locationTimer = Timer(session.locationWindow, () {
      if (!session.locationDone.isCompleted) {
        session.locationDone.complete();
      }
    });
    await session.locationDone.future;
    // The cancel is not awaited: stopping the window must not depend on the
    // platform stream settling, or the pipeline can hang on a quiet stream.
    _stopLocation(session);
  }

  void _stopLocation(_Session session) {
    session.locationTimer?.cancel();
    final subscription = session.locationSub;
    session.locationSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  Future<void> _handleAudio(
    _Session session,
    AudioCaptureResult capture,
  ) async {
    final token = session.incident.token;
    final path = capture.path;
    if (path == null) {
      await _safe(
        () => services.writer.publishAudio(
          token: token,
          status: AudioStatus.failed,
        ),
      );
      return;
    }
    final keepOnCancel = capture.durationSec >= config.cancelUploadGrace.inSeconds;
    if (session.cancelled && !keepOnCancel) {
      await deleteLocalAudio(path);
      await _safe(
        () => services.writer.publishAudio(
          token: token,
          status: AudioStatus.failed,
        ),
      );
      return;
    }
    await services.queue.write(
      QueueEntry(token: token, audioPath: path, createdAt: DateTime.now()),
    );
    final uploaded = await services.uploader.upload(
      token: token,
      path: path,
      durationSec: capture.durationSec,
      recordedAt: session.incident.createdAt,
    );
    if (uploaded) {
      await deleteLocalAudio(path);
      await services.queue.clear();
      await _safe(
        () => services.writer.publishAudio(
          token: token,
          status: capture.status,
          path: 'incidents/$token/audio.m4a',
          durationSec: capture.durationSec,
          sizeBytes: capture.sizeBytes,
        ),
      );
      return;
    }
    // Failed upload: the file and the queue entry stay for the next open
    // inside the one hour window (SPEC 19.3).
    await _safe(
      () => services.writer.publishAudio(
        token: token,
        status: AudioStatus.failed,
      ),
    );
  }

  Future<void> _safePublish(_Session session, AcceptedFix fix) async {
    if (session.cancelled) {
      return;
    }
    await _safe(
      () => services.writer.publishFix(incident: session.incident, fix: fix),
    );
  }

  Future<void> _cleanup({bool keeperReady = false}) async {
    final session = _session;
    _session = null;
    if (session != null) {
      session.hardCap?.cancel();
      _stopLocation(session);
    }
    if (keeperReady) {
      await _safe(services.keeper.stop);
    }
    _state = TriggerState.finalizing;
    await _safe(
      () => cleanStaleAudio(maxAge: Timing.audioLocalMaxAge),
    );
    _endedAt = DateTime.now();
    _state = TriggerState.ended;
    _state = TriggerState.idle;
    if (!_delivery.isCompleted) {
      _delivery.complete(_lastDelivery);
    }
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A failed write must not abort the rest of the alert pipeline.
    }
  }
}

class _Session {
  _Session({
    required this.incident,
    required this.recordingWindow,
    required this.locationWindow,
  });

  final Incident incident;
  final Duration recordingWindow;
  final Duration locationWindow;
  final Completer<void> locationDone = Completer<void>();
  Timer? hardCap;
  Timer? locationTimer;
  StreamSubscription<AcceptedFix>? locationSub;
  bool cancelled = false;
}

abstract class TriggerServiceFactory {
  Future<TriggerController> build();
}

class DeviceTriggerServiceFactory implements TriggerServiceFactory {
  DeviceTriggerServiceFactory({SetupStore? store})
      : _store = store ?? SetupStore(SecureStore());

  /// One controller per process: the calculator, the setup stack, and the test
  /// alert screen all reach the same active incident.
  static final DeviceTriggerServiceFactory instance =
      DeviceTriggerServiceFactory();

  final SetupStore _store;
  TriggerController? _controller;

  @override
  Future<TriggerController> build() async {
    final existing = _controller;
    if (existing != null) {
      return existing;
    }
    final uid = await FirebaseBootstrap.ensureOwnerUid(_store);
    final info = await PackageInfo.fromPlatform();
    final controller = TriggerController(
      services: TriggerServices(
        store: _store,
        writer: FirestoreIncidentRepository(ownerUid: uid),
        audio: DeviceAudioCapture(),
        location: DeviceLocationSource(),
        messenger: PlatformSmsSender(),
        keeper: ForegroundServiceKeeper(),
        queue: UploadQueue(),
        uploader: StorageAudioUploader(),
        appVersion: '${info.version}+${info.buildNumber}',
      ),
    );
    _controller = controller;
    return controller;
  }
}
