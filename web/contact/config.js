// Deployment configuration for Firebase project nightjar-8d561, taken from the
// google-services.json at the repository root. That key belongs to the Android
// app registration, so register a Web app in the Firebase console and replace
// apiKey and appId with the web values before deploying the page. Everything
// else (project, bucket, sender, auth domain) stays the same.
export const config = {
  apiKey: 'AIzaSyCc9fbZ3W8P1K2TGYzJvXXy9etR5qrZ7VA',
  authDomain: 'nightjar-8d561.firebaseapp.com',
  projectId: 'nightjar-8d561',
  storageBucket: 'nightjar-8d561.firebasestorage.app',
  messagingSenderId: '364661250190',
  appId: '1:364661250190:android:6d882abbf57185f4cd91df',

  // The single call action on the page (SPEC 20.4, decision D-13).
  emergencyNumber: '112',

  // Local development against the emulators (SPEC 30.3).
  useEmulator: false,
  emulatorHost: '127.0.0.1',
};
