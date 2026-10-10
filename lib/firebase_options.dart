// lib/firebase_options.dart
// Config de Firebase para FleteGG
// Generado manualmente desde Firebase Console — 2026-10-09

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAiegf2mfIaQD4PHLYYcSHke9UG_VNvALA',
    appId: '1:1032693175523:web:d4665ac4e3889744f561d6',
    messagingSenderId: '1032693175523',
    projectId: 'fletegg',
    authDomain: 'fletegg.firebaseapp.com',
    storageBucket: 'fletegg.firebasestorage.app',
    measurementId: 'G-TP19G30FK7',
  );

  // Android — falta el SHA-1 del keystore (se agrega desde Firebase Console)
  // Por ahora usamos los mismos datos web; Flutter usa google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAiegf2mfIaQD4PHLYYcSHke9UG_VNvALA',
    appId: '1:1032693175523:web:d4665ac4e3889744f561d6',
    messagingSenderId: '1032693175523',
    projectId: 'fletegg',
    storageBucket: 'fletegg.firebasestorage.app',
  );

  // iOS — falta el Team ID de Apple Developer
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAiegf2mfIaQD4PHLYYcSHke9UG_VNvALA',
    appId: '1:1032693175523:web:d4665ac4e3889744f561d6',
    messagingSenderId: '1032693175523',
    projectId: 'fletegg',
    storageBucket: 'fletegg.firebasestorage.app',
    iosBundleId: 'cl.eggclaw.fletegg',
  );
}