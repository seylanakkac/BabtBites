// Central catalog sync (Faz 3): the admin-managed content (custom foods/
// recipes/articles, built-in overrides/deletions, and app config) is shared
// with EVERY user via Firestore `/catalog/*`.
//
//  - pull():  everyone, on startup. Brings the shared catalog into prefs BEFORE
//             StorageService.loadInto() applies it — so it merges in a single
//             clean pass (no double-merge).
//  - push():  ADMIN only. Writes the current catalog up after an admin edit.
//
// Content is split across a few docs to stay under Firestore's 1 MiB/doc limit.
// (Base64 images make custom content heavy; those move to Storage in Faz 4.)
// Security: /catalog read = everyone, write = admin email (see firestore.rules).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

class CatalogSync {
  CatalogSync._();
  static final CatalogSync instance = CatalogSync._();

  CollectionReference<Map<String, dynamic>> get _catalog =>
      FirebaseFirestore.instance.collection('catalog');

  /// Which prefs keys live in which catalog document.
  static const Map<String, List<String>> _docKeys = {
    'config': [
      'admin_config',
      'deleted_foods', 'deleted_recipes', 'deleted_articles',
      'food_overrides', 'recipe_overrides', 'article_overrides',
    ],
    'customFoods': ['custom_foods'],
    'customRecipes': ['custom_recipes'],
    'customArticles': ['custom_articles'],
  };

  /// Everyone: pulls the shared catalog into prefs. Call BEFORE loadInto().
  Future<void> pull() async {
    try {
      final merged = <String, dynamic>{};
      for (final docId in _docKeys.keys) {
        final snap = await _catalog.doc(docId).get();
        final data = snap.data();
        if (data != null) merged.addAll(data);
      }
      if (merged.isNotEmpty) {
        await StorageService.instance.importCatalog(merged);
      }
    } catch (e) {
      debugPrint('CatalogSync.pull failed: $e');
    }
  }

  /// Admin only: pushes the current catalog up to /catalog/* (full overwrite so
  /// deletions propagate). No-op for non-admins. Returns null on success or a
  /// short error string on failure (so the admin UI can surface it).
  Future<String?> push() async {
    if (!globalIsAdmin) return "Yetki yok (admin değil)";
    try {
      final all = StorageService.instance.exportCatalog();
      for (final entry in _docKeys.entries) {
        final docData = <String, dynamic>{};
        for (final k in entry.value) {
          if (all.containsKey(k)) docData[k] = all[k];
        }
        await _catalog.doc(entry.key).set(docData).timeout(const Duration(seconds: 15));
      }
      return null;
    } catch (e) {
      debugPrint('CatalogSync.push failed: $e');
      return e.toString();
    }
  }
}
