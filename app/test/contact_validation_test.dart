import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/features/setup/contacts_screen.dart';

void main() {
  group('contact validation', () {
    test('accepts a full E.164 number', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '+6591234567',
        takenPhones: const [],
      );
      expect(result.error, isNull);
      expect(result.contact?.phone, '+6591234567');
      expect(result.contact?.name, 'Amal');
    });

    test('normalises a spaced international number', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '+65 9123 4567',
        takenPhones: const [],
      );
      expect(result.contact?.phone, '+6591234567');
    });

    test('rejects a number without a country code', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '91234567',
        takenPhones: const [],
      );
      expect(result.contact, isNull);
      expect(result.error, 'Use the full number with country code.');
    });

    test('rejects a too short number', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '+1 555 0100',
        takenPhones: const [],
      );
      expect(result.contact, isNull);
      expect(result.error, 'Use the full number with country code.');
    });

    test('rejects a duplicate of another slot', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '+6591234567',
        takenPhones: const ['+6591234567'],
      );
      expect(result.contact, isNull);
      expect(result.error, 'That number is already added.');
    });

    test('a duplicate in a different format is still rejected', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '+65 9123 4567',
        takenPhones: const ['+6591234567'],
      );
      expect(result.contact, isNull);
      expect(result.error, 'That number is already added.');
    });

    test('an empty phone keeps save disabled without an error', () {
      final result = validateContact(
        name: 'Amal',
        rawPhone: '',
        takenPhones: const [],
      );
      expect(result.contact, isNull);
      expect(result.error, isNull);
    });

    test('an empty name keeps save disabled', () {
      final result = validateContact(
        name: '   ',
        rawPhone: '+6591234567',
        takenPhones: const [],
      );
      expect(result.contact, isNull);
      expect(result.error, isNull);
    });

    test('a name of 40 characters is accepted', () {
      final result = validateContact(
        name: 'A' * 40,
        rawPhone: '+6591234567',
        takenPhones: const [],
      );
      expect(result.contact?.name.length, 40);
    });

    test('a name past 40 characters keeps save disabled', () {
      final result = validateContact(
        name: 'A' * 41,
        rawPhone: '+6591234567',
        takenPhones: const [],
      );
      expect(result.contact, isNull);
    });

    test('the name is trimmed', () {
      final result = validateContact(
        name: '  Amal  ',
        rawPhone: '+6591234567',
        takenPhones: const [],
      );
      expect(result.contact?.name, 'Amal');
    });
  });

  group('phone masking', () {
    test('keeps the country code and last two digits', () {
      final masked = maskPhone('+6591234567');
      expect(masked.startsWith('+65'), isTrue);
      expect(masked.endsWith('67'), isTrue);
      expect(masked.length, '+6591234567'.length);
      expect(masked.contains('\u2022'), isTrue);
    });

    test('leaves short values alone', () {
      expect(maskPhone('+65'), '+65');
    });
  });
}
