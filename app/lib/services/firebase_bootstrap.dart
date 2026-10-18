import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/constants.dart';
import '../firebase_options.dart';
import 'secure_store.dart';

/// Firebase starts lazily: the calculator path never touches it (SPEC 8.6).
class FirebaseBootstrap {
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
  static bool _initialized = false;

  /// Returns the anonymous auth UID, signing in on first use.
  static Future<String> ensureOwnerUid(SetupStore store) async {
    if (!_initialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (useEmulator) {
        const host = FirebaseNames.emulatorHost;
        // Ports match the emulators block in firebase.json.
        await FirebaseAuth.instance.useAuthEmulator(host, 9298);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
        FirebaseStorage.instance.useStorageEmulator(host, 9299);
      }
      _initialized = true;
    }
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      await store.writeUid(current.uid);
      return current.uid;
    }
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final uid = credential.user!.uid;
    await store.writeUid(uid);
    return uid;
  }
}
