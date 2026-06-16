// Cloud sync (Faz 2): mirrors the signed-in user's PRIVATE data to Firestore
// at /users/{uid}. Catalog/admin/social data is intentionally NOT synced here
// (that becomes the shared /catalog in Faz 3).
//
// Strategy (simple, robust for now):
//  - pull():  on sign-in, if the cloud doc exists → import it locally (cloud
//             wins); if it doesn't exist → seed the cloud from local (first-time
//             migration so existing on-device data isn't lost).
//  - push():  after any local user-data save, write the snapshot back (merge).
// All Firestore access is wrapped — a failure (e.g. offline, rules not yet
// published) never breaks the app; it keeps working from local storage.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _doc() {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// Called on sign-in / app-start with a session. Brings cloud data down, or
  /// seeds the cloud from local on first use.
  Future<void> pull() async {
    final doc = _doc();
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (snap.exists && data != null && data.isNotEmpty) {
        await StorageService.instance.importUserData(data);
      } else {
        await push(); // seed cloud from current local state
      }
    } catch (e) {
      debugPrint('CloudSync.pull failed: $e');
    }
  }

  /// Writes the current local user-data snapshot to the cloud (merge). Safe to
  /// call fire-and-forget after every save.
  Future<void> push() async {
    final doc = _doc();
    if (doc == null) return;
    try {
      final data = StorageService.instance.exportUserData();
      if (data.isEmpty) return;
      await doc.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CloudSync.push failed: $e');
    }
  }
}
