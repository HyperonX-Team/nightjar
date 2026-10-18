import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/incident/incident.dart';

void main() {
  group('token', () {
    test('is 32 characters of base64url without padding', () {
      final token = generateToken();
      expect(token.length, 32);
      expect(RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(token), isTrue);
      expect(token.contains('='), isFalse);
    });

    test('is unique across 100,000 samples', () {
      final seen = <String>{};
      for (var i = 0; i < 100000; i++) {
        expect(seen.add(generateToken()), isTrue, reason: 'collision at $i');
      }
    });
  });

  group('expiry', () {
    final created = DateTime(2026, 10, 17, 12);

    test('a real incident expires in 24 hours', () {
      expect(
        expiryFor(TriggerKind.pin, created).difference(created),
        const Duration(hours: 24),
      );
      expect(
        expiryFor(TriggerKind.tripleTap, created).difference(created),
        const Duration(hours: 24),
      );
    });

    test('a test incident expires in 1 hour', () {
      expect(
        expiryFor(TriggerKind.test, created).difference(created),
        const Duration(hours: 1),
      );
    });
  });

  group('trigger names', () {
    test('round trips through the wire names', () {
      for (final kind in TriggerKind.values) {
        expect(triggerFromName(triggerName(kind)), kind);
      }
    });

    test('uses the spec wire names', () {
      expect(triggerName(TriggerKind.pin), 'pin');
      expect(triggerName(TriggerKind.tripleTap), 'triple_tap');
      expect(triggerName(TriggerKind.test), 'test');
    });

    test('unknown names are rejected', () {
      expect(triggerFromName('duress'), isNull);
    });
  });

  group('delivery row', () {
    test('carries channel and status only', () {
      const entry = DeliveryEntry(channel: 'sms', status: 'sent');
      expect(entry.toMap(), {'channel': 'sms', 'status': 'sent'});
      expect(entry.toMap().containsKey('phone'), isFalse);
    });
  });
}
