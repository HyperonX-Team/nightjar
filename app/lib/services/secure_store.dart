import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/trigger/pin_hasher.dart';
import 'dart:typed_data';

/// Key value storage for everything that must not leak outside the app's
/// Keystore-backed storage.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureStore implements SecretStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class SecretKeys {
  static const pinHash = 'pin.hash';
  static const pinSalt = 'pin.salt';
  static const pinIterations = 'pin.iterations';
  static const pinLength = 'pin.length';
  static const lockoutFailures = 'pin.lockout.failures';
  static const lockoutCount = 'pin.lockout.count';
  static const lockoutUntil = 'pin.lockout.until';
  static const contacts = 'contacts.json';
  static const ownerName = 'owner.name';
  static const authUid = 'auth.uid';
  static const lastTest = 'test.last';
  static const tripleTapEnabled = 'trigger.tripleTap';
}

/// Reads and writes the setup state stored on this device only.
class SetupStore {
  SetupStore(this._store);

  final SecretStore _store;

  Future<PinRecord?> readPin() async {
    final hash = await _store.read(SecretKeys.pinHash);
    final salt = await _store.read(SecretKeys.pinSalt);
    final iterations = await _store.read(SecretKeys.pinIterations);
    final length = await _store.read(SecretKeys.pinLength);
    if (hash == null || salt == null || iterations == null || length == null) {
      return null;
    }
    return PinRecord(
      salt: Uint8List.fromList(base64Decode(salt)),
      iterations: int.parse(iterations),
      hash: Uint8List.fromList(base64Decode(hash)),
      length: int.parse(length),
    );
  }

  Future<void> writePin(PinRecord record) async {
    await _store.write(SecretKeys.pinHash, base64Encode(record.hash));
    await _store.write(SecretKeys.pinSalt, base64Encode(record.salt));
    await _store.write(SecretKeys.pinIterations, record.iterations.toString());
    await _store.write(SecretKeys.pinLength, record.length.toString());
  }

  Future<void> clearPin() async {
    await _store.delete(SecretKeys.pinHash);
    await _store.delete(SecretKeys.pinSalt);
    await _store.delete(SecretKeys.pinIterations);
    await _store.delete(SecretKeys.pinLength);
  }

  Future<LockoutState> readLockout() async {
    final failures = await _store.read(SecretKeys.lockoutFailures);
    final count = await _store.read(SecretKeys.lockoutCount);
    final until = await _store.read(SecretKeys.lockoutUntil);
    return LockoutState(
      failures: failures == null ? 0 : int.parse(failures),
      lockouts: count == null ? 0 : int.parse(count),
      lockedUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.parse(until)),
    );
  }

  Future<void> writeLockout(LockoutState state) async {
    await _store.write(
      SecretKeys.lockoutFailures,
      state.failures.toString(),
    );
    await _store.write(SecretKeys.lockoutCount, state.lockouts.toString());
    if (state.lockedUntil == null) {
      await _store.delete(SecretKeys.lockoutUntil);
    } else {
      await _store.write(
        SecretKeys.lockoutUntil,
        state.lockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<List<Contact>> readContacts() async {
    final raw = await _store.read(SecretKeys.contacts);
    if (raw == null || raw.isEmpty) {
      return <Contact>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in decoded)
        Contact.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> writeContacts(List<Contact> contacts) async {
    await _store.write(
      SecretKeys.contacts,
      jsonEncode([for (final contact in contacts) contact.toJson()]),
    );
  }

  Future<String> readOwnerName() async =>
      await _store.read(SecretKeys.ownerName) ?? '';

  Future<void> writeOwnerName(String name) =>
      _store.write(SecretKeys.ownerName, name);

  Future<String?> readUid() => _store.read(SecretKeys.authUid);

  Future<void> writeUid(String uid) => _store.write(SecretKeys.authUid, uid);

  Future<DateTime?> readLastTest() async {
    final raw = await _store.read(SecretKeys.lastTest);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> writeLastTest(DateTime at) =>
      _store.write(SecretKeys.lastTest, at.toIso8601String());

  Future<void> clearLastTest() => _store.delete(SecretKeys.lastTest);

  Future<bool> readTripleTapEnabled() async =>
      (await _store.read(SecretKeys.tripleTapEnabled)) != 'false';

  Future<void> writeTripleTapEnabled(bool enabled) =>
      _store.write(SecretKeys.tripleTapEnabled, enabled ? 'true' : 'false');

  Future<void> clearAllSettings() async {
    await clearPin();
    await _store.delete(SecretKeys.contacts);
    await _store.delete(SecretKeys.ownerName);
    await _store.delete(SecretKeys.lockoutFailures);
    await _store.delete(SecretKeys.lockoutCount);
    await _store.delete(SecretKeys.lockoutUntil);
    await _store.delete(SecretKeys.lastTest);
    await _store.delete(SecretKeys.tripleTapEnabled);
  }
}

class Contact {
  const Contact({required this.name, required this.phone});

  final String name;

  /// E.164, for example +6591234567.
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: json['name'] as String,
        phone: json['phone'] as String,
      );
}
