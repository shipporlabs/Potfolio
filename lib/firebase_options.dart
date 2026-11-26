// Replace this file by running `flutterfire configure` in the project folder.
// It generates real options for Android, iOS and web from your Firebase project.
//
// Until you do, `isConfigured` is false and the app runs in demo mode:
// sign-in is local to the device and pots are stored on the device.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const bool isConfigured = false;

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run `flutterfire configure`.',
    );
  }
}
