import 'package:firebase_core/firebase_core.dart';

abstract final class FirebaseBootstrap {
  static const enabled = bool.fromEnvironment('USE_FIREBASE');

  static Future<FirebaseApp> initialize() {
    return Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      ),
    );
  }
}
