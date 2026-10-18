import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../core/constants.dart';

/// PBKDF2-HMAC-SHA256 output plus the parameters needed to re-derive it.
class PinRecord {
  const PinRecord({
    required this.salt,
    required this.iterations,
    required this.hash,
    required this.length,
  });

  final Uint8List salt;
  final int iterations;
  final Uint8List hash;
  final int length;
}

class PinDeriveInput {
  const PinDeriveInput({
    required this.pin,
    required this.salt,
    required this.iterations,
    required this.keyBytes,
  });

  final String pin;
  final Uint8List salt;
  final int iterations;
  final int keyBytes;
}

/// Top-level so it can run through compute() off the UI thread.
Uint8List derivePinHash(PinDeriveInput input) => pbkdf2Sha256(
      password: input.pin.codeUnits,
      salt: input.salt,
      iterations: input.iterations,
      keyBytes: input.keyBytes,
    );

class PinHasher {
  static PinRecord create(String pin) {
    final salt = randomBytes(PinRules.saltBytes);
    final hash = pbkdf2Sha256(
      password: pin.codeUnits,
      salt: salt,
      iterations: PinRules.iterations,
      keyBytes: PinRules.keyBytes,
    );
    return PinRecord(
      salt: salt,
      iterations: PinRules.iterations,
      hash: hash,
      length: pin.length,
    );
  }

  static bool verify(String pin, PinRecord record) {
    if (pin.length != record.length) {
      return false;
    }
    final candidate = pbkdf2Sha256(
      password: pin.codeUnits,
      salt: record.salt,
      iterations: record.iterations,
      keyBytes: record.hash.length,
    );
    return constantTimeEquals(candidate, record.hash);
  }
}

Uint8List pbkdf2Sha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  required int keyBytes,
}) {
  final hmac = Hmac(sha256, password);
  const hLen = 32;
  final blockCount = (keyBytes / hLen).ceil();
  final output = Uint8List(blockCount * hLen);
  for (var block = 1; block <= blockCount; block++) {
    final saltBlock = Uint8List(salt.length + 4);
    saltBlock.setRange(0, salt.length, salt);
    ByteData.view(saltBlock.buffer).setUint32(salt.length, block);
    var u = hmac.convert(saltBlock).bytes;
    final accumulator = Uint8List.fromList(u);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < accumulator.length; i++) {
        accumulator[i] ^= u[i];
      }
    }
    output.setRange((block - 1) * hLen, block * hLen, accumulator);
  }
  return Uint8List.sublistView(output, 0, keyBytes);
}

/// Length check kept before the XOR loop so the compare does not short circuit
/// on content (SPEC 10).
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

Uint8List randomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// Returns the copy from the deck for the first rule the PIN breaks, or null.
String? validatePinRules(String pin) {
  if (pin.length < PinRules.minLength ||
      pin.length > PinRules.maxLength ||
      !RegExp(r'^\d+$').hasMatch(pin)) {
    return 'Use 4 to 8 digits.';
  }
  if (_allSameDigit(pin) || _isSequence(pin)) {
    return 'Avoid repeated or sequential numbers.';
  }
  return null;
}

bool _allSameDigit(String pin) => pin.split('').toSet().length == 1;

bool _isSequence(String pin) {
  var ascending = true;
  var descending = true;
  for (var i = 1; i < pin.length; i++) {
    final delta = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1);
    if (delta != 1) {
      ascending = false;
    }
    if (delta != -1) {
      descending = false;
    }
  }
  return ascending || descending;
}

/// Failed attempt and lockout arithmetic for the PIN gate. Kept in secure
/// storage so a process restart does not reset it (SPEC 9).
class LockoutState {
  const LockoutState({
    this.failures = 0,
    this.lockouts = 0,
    this.lockedUntil,
  });

  final int failures;
  final int lockouts;
  final DateTime? lockedUntil;

  bool isLocked(DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) {
      return Duration.zero;
    }
    return until.difference(now);
  }

  LockoutState afterFailure(DateTime now) {
    final next = failures + 1;
    if (next < PinRules.maxAttempts) {
      return LockoutState(failures: next, lockouts: lockouts);
    }
    final level = min(lockouts + 1, PinRules.lockoutLadder.length);
    return LockoutState(
      failures: 0,
      lockouts: level,
      lockedUntil: now.add(PinRules.lockoutLadder[level - 1]),
    );
  }

  LockoutState afterSuccess() => const LockoutState();
}

String lockoutMessage(Duration remaining) {
  if (remaining.inSeconds <= 60) {
    // Round up on milliseconds so a fresh 30 second lock does not read as 29.
    final shown = max(1, (remaining.inMilliseconds / 1000).ceil());
    return 'Too many attempts. Try again in $shown seconds.';
  }
  final minutes = max(1, (remaining.inMilliseconds / 60000).ceil());
  return minutes == 1
      ? 'Too many attempts. Try again in 1 minute.'
      : 'Too many attempts. Try again in $minutes minutes.';
}

/// Hashing entry point. The 210,000 iteration derivation runs in an isolate so
/// the PIN gate and the trigger never block the UI thread.
abstract class PinService {
  Future<PinRecord> create(String pin);

  Future<bool> verify(String pin, PinRecord record);
}

class ComputePinService implements PinService {
  @override
  Future<PinRecord> create(String pin) async {
    final salt = randomBytes(PinRules.saltBytes);
    final hash = await compute(
      derivePinHash,
      PinDeriveInput(
        pin: pin,
        salt: salt,
        iterations: PinRules.iterations,
        keyBytes: PinRules.keyBytes,
      ),
    );
    return PinRecord(
      salt: salt,
      iterations: PinRules.iterations,
      hash: hash,
      length: pin.length,
    );
  }

  @override
  Future<bool> verify(String pin, PinRecord record) async {
    if (pin.length != record.length) {
      return false;
    }
    final candidate = await compute(
      derivePinHash,
      PinDeriveInput(
        pin: pin,
        salt: record.salt,
        iterations: record.iterations,
        keyBytes: record.hash.length,
      ),
    );
    return constantTimeEquals(candidate, record.hash);
  }
}
