import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/incident/incident_repository.dart';
import 'package:nightjar/features/incident/sms_sender.dart';

AcceptedFix fix({double latitude = 1.3521, double longitude = 103.8198}) =>
    AcceptedFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 12,
      at: DateTime(2026, 10, 17, 12),
    );

void main() {
  const token = '8Fj2xxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  group('message template', () {
    test('carries the name, coordinates, and page link', () {
      final message = MessageComposer.build(
        ownerName: 'Amal',
        token: token,
        fix: fix(),
      );
      expect(
        message,
        'Alert from Amal. Live location: '
        'https://maps.google.com/?q=1.352100,103.819800 '
        'Details: https://quiet-tally.web.app/i/$token',
      );
    });

    test('drops the coordinate link when there is no fix', () {
      final message = MessageComposer.build(ownerName: 'Amal', token: token);
      expect(
        message,
        'Alert from Amal. Details: https://quiet-tally.web.app/i/$token',
      );
    });

    test('formats coordinates to six decimals', () {
      final message = MessageComposer.build(
        ownerName: 'Amal',
        token: token,
        fix: fix(latitude: -33.8688, longitude: 151.2093),
      );
      expect(message, contains('https://maps.google.com/?q=-33.868800,151.209300'));
    });

    test('defaults the name when none is set', () {
      final message = MessageComposer.build(ownerName: '', token: token);
      expect(message, startsWith('Alert from a contact.'));
    });

    test('falls back when the name carries a forbidden term', () {
      final message = MessageComposer.build(ownerName: 'Help me', token: token);
      expect(message, startsWith('Alert from a contact.'));
    });

    test('falls back when the name is too long', () {
      final message = MessageComposer.build(
        ownerName: 'Amal Amal Amal Amal Amal',
        token: token,
      );
      expect(message, startsWith('Alert from a contact.'));
    });

    test('falls back when the name is not ASCII', () {
      final message = MessageComposer.build(ownerName: 'Am\u00e4l', token: token);
      expect(message, startsWith('Alert from a contact.'));
    });

    test('has no em dash and no product name', () {
      final message = MessageComposer.build(
        ownerName: 'Amal',
        token: token,
        fix: fix(),
      );
      expect(message.contains('\u2014'), isFalse);
      expect(message.toLowerCase().contains('nightjar'), isFalse);
    });
  });

  group('message validation', () {
    test('accepts the composed message', () {
      final message = MessageComposer.build(
        ownerName: 'Amal',
        token: token,
        fix: fix(),
      );
      expect(MessageComposer.validate(message), isNull);
      expect(message.length, lessThan(300));
    });

    test('flags a message over 300 characters', () {
      expect(MessageComposer.validate('a' * 301), 'too_long');
    });

    test('flags a non ASCII message', () {
      expect(MessageComposer.validate('Alert \u00e4'), 'not_ascii');
    });

    test('flags each forbidden term', () {
      expect(MessageComposer.validate('this is an SOS'), 'forbidden_term');
      expect(MessageComposer.validate('nightjar'), 'forbidden_term');
      expect(MessageComposer.validate('abuse'), 'forbidden_term');
      expect(MessageComposer.validate('help me please'), 'forbidden_term');
    });
  });

  group('sms result parsing', () {
    test('reads a sent result', () {
      final result = SmsResult.fromMap({'status': 'sent'});
      expect(result.status, 'sent');
      expect(result.reason, isNull);
    });

    test('reads a failure with a reason', () {
      final result = SmsResult.fromMap(
        {'status': 'failed', 'reason': 'timeout'},
      );
      expect(result.status, 'failed');
      expect(result.reason, 'timeout');
    });

    test('reads a permission denial', () {
      final result = SmsResult.fromMap({'status': 'permission_denied'});
      expect(result.status, SmsResult.permissionDenied);
    });

    test('treats malformed payloads as failed', () {
      expect(SmsResult.fromMap(null).status, 'failed');
      expect(SmsResult.fromMap('nonsense').reason, 'malformed_result');
    });
  });
}
