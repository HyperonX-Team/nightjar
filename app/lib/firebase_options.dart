import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase project `nightjar-8d561`, taken from the google-services.json the
/// owner added at the repository root.
///
/// That file registers the Android package `com.hyperonx.nightjar`, while this
/// app ships as `com.tally.calculator` (SPEC 22.1, decision D-04). The Dart
/// options below initialize Firebase for the project either way, and the API
/// key only rejects the app if the owner has added package restrictions in the
/// Firebase console. Register `com.tally.calculator` (and
/// `com.tally.calculator.dev` for emulator builds) to remove that risk.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'AIzaSyCc9fbZ3W8P1K2TGYzJvXXy9etR5qrZ7VA',
        appId: '1:364661250190:android:6d882abbf57185f4cd91df',
        messagingSenderId: '364661250190',
        projectId: 'nightjar-8d561',
        storageBucket: 'nightjar-8d561.firebasestorage.app',
      );
}
