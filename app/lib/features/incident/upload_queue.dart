import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

class QueueEntry {
  const QueueEntry({
    required this.token,
    required this.audioPath,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String token;
  final String audioPath;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  QueueEntry copyWith({int? attempts, String? lastError}) => QueueEntry(
        token: token,
        audioPath: audioPath,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  Map<String, Object?> toJson() => {
        'token': token,
        'audioPath': audioPath,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  factory QueueEntry.fromJson(Map<String, dynamic> json) => QueueEntry(
        token: json['token'] as String,
        audioPath: json['audioPath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );

  bool isExpired(DateTime now) =>
      now.difference(createdAt) > Timing.audioLocalMaxAge;
}

/// One entry at most, in app-private storage, never in secure storage. It holds
/// no location and no contact data (SPEC 19.1).
abstract class PendingUploads {
  Future<QueueEntry?> read();

  Future<void> write(QueueEntry entry);

  Future<void> clear();
}

class UploadQueue implements PendingUploads {
  static const _fileName = 'queue.json';

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');

  @override
  Future<QueueEntry?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return QueueEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(QueueEntry entry) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(entry.toJson()));
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class MemoryUploads implements PendingUploads {
  QueueEntry? entry;

  @override
  Future<QueueEntry?> read() async => entry;

  @override
  Future<void> write(QueueEntry value) async => entry = value;

  @override
  Future<void> clear() async => entry = null;
}

abstract class AudioUploader {
  Future<bool> upload({
    required String token,
    required String path,
    required int durationSec,
    required DateTime recordedAt,
  });
}

/// Uploads to `incidents/{token}/audio.m4a` with retries of 2, 5, then 15
/// seconds while the service is alive (SPEC 15.4). A failed upload keeps the
/// queue entry so the next app open can retry inside the one hour window.
class StorageAudioUploader implements AudioUploader {
  StorageAudioUploader({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<bool> upload({
    required String token,
    required String path,
    required int durationSec,
    required DateTime recordedAt,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return false;
    }
    final size = await file.length();
    if (size <= 0 || size > AudioFormat.maxUploadBytes) {
      return false;
    }
    final reference = _storage.ref('incidents/$token/audio.m4a');
    final metadata = SettableMetadata(
      contentType: 'audio/mp4',
      customMetadata: <String, String>{
        'token': token,
        'durationSec': '$durationSec',
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'schemaVersion': '${AppInfo.schemaVersion}',
      },
    );
    for (var attempt = 0; attempt <= Timing.uploadRetryDelays.length; attempt++) {
      try {
        await reference.putFile(file, metadata);
        return true;
      } catch (_) {
        if (attempt == Timing.uploadRetryDelays.length) {
          return false;
        }
        await Future<void>.delayed(Timing.uploadRetryDelays[attempt]);
      }
    }
    return false;
  }
}
