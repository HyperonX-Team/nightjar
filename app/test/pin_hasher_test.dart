import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/core/constants.dart';
import 'package:nightjar/features/trigger/pin_hasher.dart';

String hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('pbkdf2-hmac-sha256', () {
    test('matches the RFC 7914 vector at one iteration', () {
      final hash = pbkdf2Sha256(
        password: 'passwd'.codeUnits,
        salt: 'salt'.codeUnits,
        iterations: 1,
        keyBytes: 64,
      );
      expect(
        hex(hash),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('matches the RFC 7914 vector at 80,000 iterations', () {
      final hash = pbkdf2Sha256(
        password: 'Password'.codeUnits,
        salt: 'NaCl'.codeUnits,
        iterations: 80000,
        keyBytes: 64,
      );
      expect(
        hex(hash),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });

    test('matches an independent 210,000 iteration derivation', () {
      final hash = pbkdf2Sha256(
        password: '4826'.codeUnits,
        salt: '0123456789abcdef'.codeUnits,
        iterations: PinRules.iterations,
        keyBytes: PinRules.keyBytes,
      );
      expect(
        hex(hash),
        '3f3a91d162a83c703d6002b2ffbe00ed6cdab2e02d43f6547651c98e9a30be48',
      );
    });
  });

  group('constant time comparison', () {
    test('equal bytes match', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('a single flipped byte fails', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('different lengths fail', () {
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
    });
  });

  group('pin rules', () {
    test('accepts an ordinary four digit PIN', () {
      expect(validatePinRules('4826'), isNull);
    });

    test('accepts an ordinary eight digit PIN', () {
      expect(validatePinRules('48260317'), isNull);
    });

    test('accepts non sequential digits', () {
      expect(validatePinRules('1357'), isNull);
    });

    test('rejects a three digit PIN', () {
      expect(validatePinRules('482'), 'Use 4 to 8 digits.');
    });

    test('rejects a nine digit PIN', () {
      expect(validatePinRules('482603171'), 'Use 4 to 8 digits.');
    });

    test('rejects digits only exceptions', () {
      expect(validatePinRules('48a6'), 'Use 4 to 8 digits.');
    });

    test('rejects four identical digits', () {
      expect(validatePinRules('0000'), 'Avoid repeated or sequential numbers.');
    });

    test('rejects eight identical digits', () {
      expect(validatePinRules('11111111'), 'Avoid repeated or sequential numbers.');
    });

    test('rejects an ascending run', () {
      expect(validatePinRules('1234'), 'Avoid repeated or sequential numbers.');
    });

    test('rejects a descending run', () {
      expect(validatePinRules('9876'), 'Avoid repeated or sequential numbers.');
    });

    test('rejects a closing sequence', () {
      expect(validatePinRules('4321'), 'Avoid repeated or sequential numbers.');
    });

    test('rejects a longer ascending run', () {
      expect(validatePinRules('12345'), 'Avoid repeated or sequential numbers.');
    });

    test('accepts a run broken in the middle', () {
      expect(validatePinRules('1235'), isNull);
    });
  });

  group('lockout arithmetic', () {
    final now = DateTime(2026, 10, 17, 12);

    test('four failures do not lock', () {
      var state = const LockoutState();
      for (var i = 0; i < 4; i++) {
        state = state.afterFailure(now);
      }
      expect(state.failures, 4);
      expect(state.isLocked(now), isFalse);
    });

    test('the fifth failure locks for 30 seconds', () {
      var state = const LockoutState();
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.isLocked(now), isTrue);
      expect(state.remaining(now), const Duration(seconds: 30));
      expect(state.failures, 0);
    });

    test('the lockout ladder is 30s, 1m, 5m, 15m, then 15m', () {
      var state = const LockoutState();
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.remaining(now), const Duration(seconds: 30));
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.remaining(now), const Duration(minutes: 1));
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.remaining(now), const Duration(minutes: 5));
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.remaining(now), const Duration(minutes: 15));
      for (var i = 0; i < 5; i++) {
        state = state.afterFailure(now);
      }
      expect(state.remaining(now), const Duration(minutes: 15));
    });

    test('a success resets the counter and the ladder', () {
      var state = const LockoutState();
      for (var i = 0; i < 7; i++) {
        state = state.afterFailure(now);
      }
      state = state.afterSuccess();
      expect(state.failures, 0);
      expect(state.lockouts, 0);
      expect(state.isLocked(now), isFalse);
    });

    test('an expired lockout reports as unlocked', () {
      final state = const LockoutState().afterFailure(now);
      final later = now.add(const Duration(minutes: 5));
      expect(state.isLocked(later), isFalse);
      expect(state.remaining(later), Duration.zero);
    });

    test('lockout copy uses seconds below a minute', () {
      expect(
        lockoutMessage(const Duration(seconds: 30)),
        'Too many attempts. Try again in 30 seconds.',
      );
    });

    test('lockout copy uses minutes above a minute', () {
      expect(
        lockoutMessage(const Duration(minutes: 5)),
        'Too many attempts. Try again in 5 minutes.',
      );
    });
  });

  group('pin record', () {
    test('create and verify round trip', () {
      final record = PinHasher.create('4826');
      expect(record.length, 4);
      expect(record.salt.length, PinRules.saltBytes);
      expect(record.hash.length, PinRules.keyBytes);
      expect(record.iterations, PinRules.iterations);
      expect(PinHasher.verify('4826', record), isTrue);
      expect(PinHasher.verify('4827', record), isFalse);
    });

    test('a wrong length is rejected before hashing', () {
      final record = PinHasher.create('4826');
      expect(PinHasher.verify('48261', record), isFalse);
    });

    test('two records for the same PIN differ, salt is random', () {
      final first = PinHasher.create('4826');
      final second = PinHasher.create('4826');
      expect(hex(first.salt), isNot(hex(second.salt)));
      expect(hex(first.hash), isNot(hex(second.hash)));
    });

    test('derivation through the isolate service matches the sync path',
        () async {
      final service = ComputePinService();
      final record = await service.create('4826');
      expect(PinHasher.verify('4826', record), isTrue);
      expect(await service.verify('4826', record), isTrue);
      expect(await service.verify('9999', record), isFalse);
    });
  });
}
