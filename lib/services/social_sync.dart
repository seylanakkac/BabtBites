// Social sync (Faz 3b): cross-user aggregate stats for recipes — real average
// star rating, like count and view count — stored in Firestore `/recipeStats`.
//
//   /recipeStats/{recipeId}            → { views, ratingSum, ratingCount, likeCount }
//   /recipeStats/{recipeId}/ratings/{uid} → { value }   (so a user can change their vote)
//   /recipeStats/{recipeId}/likes/{uid}   → { ts }      (so likes aren't double-counted)
//
// Aggregates are kept up to date client-side via transactions (MVP — trusts the
// signed-in client). Display reads the cached [globalRecipeStats]; when a recipe
// has no real data yet the UI falls back to a stable seed so it isn't empty.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/recipe_social_store.dart';

class SocialSync {
  SocialSync._();
  static final SocialSync instance = SocialSync._();

  final Set<String> _viewedThisSession = {};

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _stats => _db.collection('recipeStats');

  /// Everyone: load all recipe aggregate stats into the local cache (public read).
  Future<void> loadStats() async {
    try {
      final snap = await _stats.get();
      globalRecipeStats.clear();
      for (final doc in snap.docs) {
        final m = <String, num>{};
        doc.data().forEach((k, v) {
          if (v is num) m[k] = v;
        });
        globalRecipeStats[doc.id] = m;
      }
    } catch (e) {
      debugPrint('SocialSync.loadStats failed: $e');
    }
  }

  void _bumpLocal(String id, String key, num delta) {
    final s = globalRecipeStats.putIfAbsent(id, () => {});
    s[key] = (s[key] ?? 0) + delta;
  }

  /// Records this user's star rating (1..5) and updates the aggregate average.
  Future<void> rate(String id, double value, {double? previous}) async {
    final uid = _uid;
    if (uid == null) return;
    final statsRef = _stats.doc(id);
    final myRef = statsRef.collection('ratings').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final mySnap = await tx.get(myRef);
        final statsSnap = await tx.get(statsRef);
        final prev = (mySnap.data()?['value'] as num?)?.toDouble();
        final curSum = (statsSnap.data()?['ratingSum'] as num?)?.toDouble() ?? 0;
        final curCount = (statsSnap.data()?['ratingCount'] as num?)?.toInt() ?? 0;
        tx.set(statsRef, {
          'ratingSum': curSum - (prev ?? 0) + value,
          'ratingCount': curCount + (prev == null ? 1 : 0),
        }, SetOptions(merge: true));
        tx.set(myRef, {'value': value});
      });
      _bumpLocal(id, 'ratingSum', value - (previous ?? 0));
      if (previous == null) _bumpLocal(id, 'ratingCount', 1);
    } catch (e) {
      debugPrint('SocialSync.rate failed: $e');
    }
  }

  /// Adds/removes this user's like and updates the aggregate like count.
  Future<void> setLike(String id, bool liked) async {
    final uid = _uid;
    if (uid == null) return;
    final statsRef = _stats.doc(id);
    final myRef = statsRef.collection('likes').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final already = (await tx.get(myRef)).exists;
        if (liked && !already) {
          tx.set(statsRef, {'likeCount': FieldValue.increment(1)}, SetOptions(merge: true));
          tx.set(myRef, {'ts': FieldValue.serverTimestamp()});
        } else if (!liked && already) {
          tx.set(statsRef, {'likeCount': FieldValue.increment(-1)}, SetOptions(merge: true));
          tx.delete(myRef);
        }
      });
      _bumpLocal(id, 'likeCount', liked ? 1 : -1);
    } catch (e) {
      debugPrint('SocialSync.setLike failed: $e');
    }
  }

  /// Counts a view once per recipe per app session.
  Future<void> addView(String id) async {
    if (_viewedThisSession.contains(id)) return;
    _viewedThisSession.add(id);
    _bumpLocal(id, 'views', 1);
    try {
      await _stats.doc(id).set({'views': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SocialSync.addView failed: $e');
    }
  }
}
