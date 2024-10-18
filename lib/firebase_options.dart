// firebase_options.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported on this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCq_q3WKFIr6kzvzFpG_DhPzqFvNBaXaCU',
    authDomain: 'authentika-3b0c3.firebaseapp.com',
    projectId: 'authentika-3b0c3',
    storageBucket: 'authentika-3b0c3.appspot.com',
    messagingSenderId: '858196400464',
    appId: '1:858196400464:web:0c6354c9324abb616c7455',
    measurementId: 'G-E19GF64CYY',
  );
}
