import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return windows;
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
    apiKey: 'AIzaSyA3Sw2Y6k4CuPGBWeybqAQYg83exqPJsLw',
    appId: '1:785699425592:web:1428b66d1a78e1a9af85cd',
    messagingSenderId: '785699425592',
    projectId: 'deliverytrack-80524',
    authDomain: 'deliverytrack-80524.firebaseapp.com',
    storageBucket: 'deliverytrack-80524.firebasestorage.app',
    measurementId: 'G-8GE5GT2KDV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGMGmPhJTOU8AgqZYiJt9JPYdsnDng43w',
    appId: '1:785699425592:android:a3b0b29b980bc39caf85cd',
    messagingSenderId: '785699425592',
    projectId: 'deliverytrack-80524',
    storageBucket: 'deliverytrack-80524.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDIKdhDGRHwwR_y6uW95QNq9ZAKoTYONlc',
    appId: '1:785699425592:ios:d2e35ff4cb87bd09af85cd',
    messagingSenderId: '785699425592',
    projectId: 'deliverytrack-80524',
    storageBucket: 'deliverytrack-80524.firebasestorage.app',
    iosBundleId: 'com.example.dts',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDIKdhDGRHwwR_y6uW95QNq9ZAKoTYONlc',
    appId: '1:785699425592:ios:d2e35ff4cb87bd09af85cd',
    messagingSenderId: '785699425592',
    projectId: 'deliverytrack-80524',
    storageBucket: 'deliverytrack-80524.firebasestorage.app',
    iosBundleId: 'com.example.dts',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA3Sw2Y6k4CuPGBWeybqAQYg83exqPJsLw',
    appId: '1:785699425592:web:6693675f6b336f2daf85cd',
    messagingSenderId: '785699425592',
    projectId: 'deliverytrack-80524',
    authDomain: 'deliverytrack-80524.firebaseapp.com',
    storageBucket: 'deliverytrack-80524.firebasestorage.app',
    measurementId: 'G-L7Z1QQKGJG',
  );

}