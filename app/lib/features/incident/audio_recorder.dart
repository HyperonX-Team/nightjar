import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

import '../../core/constants.dart';
import 'incident.dart';

class AudioCaptureResult {
  const AudioCaptureResult({
    required this.status,
    this.path,
    this.durationSec = 0,
    this.sizeBytes,
  });

  final AudioStatus status;
  final String? path;
  final int durationSec;
  final int? sizeBytes;

  bool get hasFile => path != null;
}

abstract class AudioCapture {
  Future<AudioCaptureResult> record({
    required String token,
    required Duration duration,
  });

  /// Ends the recording window early, for cancel. The result arrives through
  /// the future returned by [record].
  Future<void> stopEarly();

  Future<void> dispose();
}

/// Records MP4/AAC LC, 16 kHz, mono (SPEC 15.1) through the Android plugin.
/// The platform interface is used directly: the umbrella `record` package
/// pulls in implementations for other platforms, one of which does not
/// compile, and this app is Android only.
class DeviceAudioCapture implements AudioCapture {
  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: AudioFormat.bitRate,
    sampleRate: AudioFormat.sampleRate,
    numChannels: 1,
  );

  final RecordPlatform _platform = RecordPlatform.instance;
  Completer<void>? _window;
  Future<AudioCaptureResult>? _inflight;
  String? _recorderId;
  DateTime? _startedAt;
  String? _path;
  Timer? _timer;
  Duration _windowDuration = Duration.zero;

  @override
  Future<AudioCaptureResult> record({
    required String token,
    required Duration duration,
  }) {
    _windowDuration = duration;
    final future = _run(token, duration);
    _inflight = future;
    return future;
  }

  Future<AudioCaptureResult> _run(String token, Duration duration) async {
    final directory = Directory('${(await getTemporaryDirectory()).path}/nightjar');
    await directory.create(recursive: true);
    final path = '${directory.path}/$token.m4a';
    final id = 'nightjar-${DateTime.now().microsecondsSinceEpoch}';
    _recorderId = id;
    try {
      await _platform.create(id);
      // Never request the microphone here: a system dialog during an alert
      // would expose it. Missing permission degrades to audio unavailable.
      final permitted = await _platform.hasPermission(id, request: false);
      if (!permitted) {
        await _release(id);
        return const AudioCaptureResult(status: AudioStatus.failed);
      }
      await _platform.start(id, _config, path: path);
    } catch (_) {
      await _release(id);
      return const AudioCaptureResult(status: AudioStatus.failed);
    }
    _startedAt = DateTime.now();
    _path = path;
    final window = Completer<void>();
    _window = window;
    _timer = Timer(duration, () {
      if (!window.isCompleted) {
        window.complete();
      }
    });
    await window.future;
    return _finalize();
  }

  @override
  Future<void> stopEarly() async {
    final window = _window;
    if (window != null && !window.isCompleted) {
      window.complete();
    }
    await _inflight;
  }

  Future<AudioCaptureResult> _finalize() async {
    _timer?.cancel();
    final startedAt = _startedAt;
    final expected = _path;
    final windowDuration = _windowDuration;
    final id = _recorderId;
    _window = null;
    _startedAt = null;
    _path = null;
    _recorderId = null;
    _inflight = null;
    if (startedAt == null || expected == null || id == null) {
      return const AudioCaptureResult(status: AudioStatus.failed);
    }
    final elapsed = DateTime.now().difference(startedAt);
    String? stopped;
    try {
      stopped = await _platform.stop(id);
    } catch (_) {
      stopped = null;
    } finally {
      await _release(id);
    }
    final file = File(stopped ?? expected);
    if (!await file.exists()) {
      return const AudioCaptureResult(status: AudioStatus.failed);
    }
    final size = await file.length();
    if (size <= 0) {
      return const AudioCaptureResult(status: AudioStatus.failed);
    }
    final ranFullWindow =
        elapsed >= windowDuration - const Duration(milliseconds: 200);
    return AudioCaptureResult(
      status: ranFullWindow ? AudioStatus.ready : AudioStatus.partial,
      path: file.path,
      durationSec: math.min(elapsed.inSeconds, windowDuration.inSeconds + 1),
      sizeBytes: size,
    );
  }

  Future<void> _release(String id) async {
    try {
      await _platform.dispose(id);
    } catch (_) {
      // Releasing an already released recorder is not an error worth raising.
    }
  }

  @override
  Future<void> dispose() async {}
}

Future<void> deleteLocalAudio(String? path) async {
  if (path == null) {
    return;
  }
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Files left by an incident that never uploaded are deleted after one hour,
/// checked on app start and after every incident end (SPEC 15.3).
Future<void> cleanStaleAudio({
  required Duration maxAge,
  DateTime? now,
}) async {
  final Directory directory;
  try {
    directory = Directory('${(await getTemporaryDirectory()).path}/nightjar');
  } catch (_) {
    // No temporary directory on this platform: nothing to clean.
    return;
  }
  if (!await directory.exists()) {
    return;
  }
  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  await for (final entity in directory.list()) {
    if (entity is! File) {
      continue;
    }
    try {
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete();
      }
    } catch (_) {
      // A locked or already removed file is not worth failing startup over.
    }
  }
}
