import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/incident/upload_queue.dart';

void main() {
  group('queue entry', () {
    test('round trips through JSON', () {
      final entry = QueueEntry(
        token: 'token',
        audioPath: '/tmp/nightjar/token.m4a',
        createdAt: DateTime(2026, 10, 17, 12),
        attempts: 2,
        lastError: 'timeout',
      );
      final restored = QueueEntry.fromJson(entry.toJson());
      expect(restored.token, entry.token);
      expect(restored.audioPath, entry.audioPath);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.attempts, 2);
      expect(restored.lastError, 'timeout');
    });

    test('expires after one hour', () {
      final entry = QueueEntry(
        token: 'token',
        audioPath: '/tmp/nightjar/token.m4a',
        createdAt: DateTime(2026, 10, 17, 12),
      );
      expect(entry.isExpired(DateTime(2026, 10, 17, 12, 59)), isFalse);
      expect(entry.isExpired(DateTime(2026, 10, 17, 13, 1)), isTrue);
    });

    test('carries no location or contact data', () {
      final entry = QueueEntry(
        token: 'token',
        audioPath: '/tmp/nightjar/token.m4a',
        createdAt: DateTime(2026, 10, 17, 12),
      );
      final json = entry.toJson();
      expect(json.keys.toSet(), {
        'token',
        'audioPath',
        'createdAt',
        'attempts',
        'lastError',
      });
    });
  });

  group('memory queue', () {
    test('holds one entry at a time', () async {
      final queue = MemoryUploads();
      expect(await queue.read(), isNull);
      await queue.write(
        QueueEntry(
          token: 'first',
          audioPath: 'a',
          createdAt: DateTime(2026, 10, 17, 12),
        ),
      );
      await queue.write(
        QueueEntry(
          token: 'second',
          audioPath: 'b',
          createdAt: DateTime(2026, 10, 17, 12),
        ),
      );
      expect((await queue.read())?.token, 'second');
      await queue.clear();
      expect(await queue.read(), isNull);
    });
  });
}
