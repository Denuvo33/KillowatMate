// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDBNgWnfuM-yEqlU0jI359PemEvndk5oM8',
    appId: '1:29182770510:web:c5bc154b81b248dfbc321f',
    messagingSenderId: '29182770510',
    projectId: 'test-realtime-app-ba4c7',
    authDomain: 'test-realtime-app-ba4c7.firebaseapp.com',
    databaseURL: 'https://test-realtime-app-ba4c7-default-rtdb.firebaseio.com',
    storageBucket: 'test-realtime-app-ba4c7.appspot.com',
    measurementId: 'G-RBN4Y1KVW4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCS-6v-JAuX_6OBZszz5ruGBOqe9IF3HkA',
    appId: '1:29182770510:android:937be7b8b1c12391bc321f',
    messagingSenderId: '29182770510',
    projectId: 'test-realtime-app-ba4c7',
    databaseURL: 'https://test-realtime-app-ba4c7-default-rtdb.firebaseio.com',
    storageBucket: 'test-realtime-app-ba4c7.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBqT6tZJ04J4oSg9DrmJExf8ERxitc-HgY',
    appId: '1:29182770510:ios:a9b15df087beb934bc321f',
    messagingSenderId: '29182770510',
    projectId: 'test-realtime-app-ba4c7',
    databaseURL: 'https://test-realtime-app-ba4c7-default-rtdb.firebaseio.com',
    storageBucket: 'test-realtime-app-ba4c7.appspot.com',
    iosBundleId: 'com.example.backgroundService',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBqT6tZJ04J4oSg9DrmJExf8ERxitc-HgY',
    appId: '1:29182770510:ios:e3d03862082b1878bc321f',
    messagingSenderId: '29182770510',
    projectId: 'test-realtime-app-ba4c7',
    databaseURL: 'https://test-realtime-app-ba4c7-default-rtdb.firebaseio.com',
    storageBucket: 'test-realtime-app-ba4c7.appspot.com',
    iosBundleId: 'com.example.backgroundService.RunnerTests',
  );
}
