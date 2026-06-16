// Firebase yapılandırması (şimdilik yalnızca Web).
//
// Bu değerler GİZLİ DEĞİLDİR — her web Firebase uygulamasının istemci kodunda
// açıkça bulunur; güvenlik, Firestore/Storage kuralları ve Authentication ile
// sağlanır. Android/iOS yapılandırması ileride gerçek paket adıyla eklenecek.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Bu platform için Firebase yapılandırması henüz eklenmedi. '
      'Şimdilik yalnızca Web yapılandırıldı; Android/iOS sonra eklenecek.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkUu3gjb3bA6nmVhiXoen8Iz0m19RADUo',
    appId: '1:951840473715:web:7a4930eab8cfe7089fa006',
    messagingSenderId: '951840473715',
    projectId: 'babybites-prod-8afe0',
    authDomain: 'babybites-prod-8afe0.firebaseapp.com',
    storageBucket: 'babybites-prod-8afe0.firebasestorage.app',
    measurementId: 'G-TK00D3LFH1',
  );
}
