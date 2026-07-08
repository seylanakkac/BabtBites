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
import '../data/user_profile_store.dart';
import '../data/extras_store.dart';

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
  /// The previous vote is read from the server inside the transaction (not
  /// passed in), so changing/repeating a vote never double-counts. The local
  /// cache is set to the authoritative values the transaction computed.
  Future<void> rate(String id, double value) async {
    final uid = _uid;
    if (uid == null) return;
    final statsRef = _stats.doc(id);
    final myRef = statsRef.collection('ratings').doc(uid);
    try {
      final result = await _db.runTransaction<Map<String, num>>((tx) async {
        final mySnap = await tx.get(myRef);
        final statsSnap = await tx.get(statsRef);
        final prev = (mySnap.data()?['value'] as num?)?.toDouble();
        final curSum = (statsSnap.data()?['ratingSum'] as num?)?.toDouble() ?? 0;
        final curCount = (statsSnap.data()?['ratingCount'] as num?)?.toInt() ?? 0;
        final newSum = curSum - (prev ?? 0) + value;
        final newCount = curCount + (prev == null ? 1 : 0);
        tx.set(statsRef, {'ratingSum': newSum, 'ratingCount': newCount}, SetOptions(merge: true));
        tx.set(myRef, {'value': value});
        return {'ratingSum': newSum, 'ratingCount': newCount};
      });
      final s = globalRecipeStats.putIfAbsent(id, () => {});
      s['ratingSum'] = result['ratingSum']!;
      s['ratingCount'] = result['ratingCount']!;
    } catch (e) {
      debugPrint('SocialSync.rate failed: $e');
    }
  }

  /// Adds/removes this user's like and updates the aggregate like count.
  /// Only changes the count when the like state actually flips on the server
  /// (so liking twice / out-of-sync state can't double-count).
  Future<void> setLike(String id, bool liked) async {
    final uid = _uid;
    if (uid == null) return;
    final statsRef = _stats.doc(id);
    final myRef = statsRef.collection('likes').doc(uid);
    try {
      final delta = await _db.runTransaction<int>((tx) async {
        final already = (await tx.get(myRef)).exists;
        if (liked && !already) {
          tx.set(statsRef, {'likeCount': FieldValue.increment(1)}, SetOptions(merge: true));
          tx.set(myRef, {'ts': FieldValue.serverTimestamp()});
          return 1;
        } else if (!liked && already) {
          tx.set(statsRef, {'likeCount': FieldValue.increment(-1)}, SetOptions(merge: true));
          tx.delete(myRef);
          return -1;
        }
        return 0;
      });
      if (delta != 0) _bumpLocal(id, 'likeCount', delta);
    } catch (e) {
      debugPrint('SocialSync.setLike failed: $e');
    }
  }

  // ---- Comments (cross-user, admin-moderated) ----
  CollectionReference<Map<String, dynamic>> get _comments => _db.collection('recipeComments');

  /// Loads a recipe's comments into the local cache [globalRecipeComments].
  /// (Single-field query — no composite index needed; filtered client-side.)
  Future<void> loadComments(String recipeId) async {
    try {
      final snap = await _comments.where('recipeId', isEqualTo: recipeId).get();
      final list = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
      globalRecipeComments[recipeId] = list;
    } catch (e) {
      debugPrint('SocialSync.loadComments failed: $e');
    }
  }

  /// Submits a comment (awaits admin approval). Returns the created doc id.
  Future<String?> submitComment(String recipeId, {required String name, required String text, String photo = ''}) async {
    final uid = _uid;
    if (uid == null) return null;
    final data = <String, dynamic>{
      'recipeId': recipeId,
      'uid': uid,
      'name': name,
      'text': text,
      'photo': photo,
      'approved': false,
      'date': _today(),
      'ts': FieldValue.serverTimestamp(),
    };
    try {
      final ref = await _comments.add(data);
      final local = Map<String, dynamic>.from(data)
        ..remove('ts')
        ..['id'] = ref.id;
      globalRecipeComments.putIfAbsent(recipeId, () => []).insert(0, local);
      return ref.id;
    } catch (e) {
      debugPrint('SocialSync.submitComment failed: $e');
      return null;
    }
  }

  /// All comments awaiting approval (admin moderation). Each item carries its id.
  Future<List<Map<String, dynamic>>> loadPendingComments() async {
    try {
      final snap = await _comments.where('approved', isEqualTo: false).get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
    } catch (e) {
      debugPrint('SocialSync.loadPendingComments failed: $e');
      return [];
    }
  }

  Future<void> approveComment(String id) async {
    try {
      await _comments.doc(id).update({'approved': true});
    } catch (e) {
      debugPrint('SocialSync.approveComment failed: $e');
    }
  }

  /// Kullanıcı bir yorumu şikayet eder → admin moderasyonuna işaretlenir.
  Future<void> reportComment(String id) async {
    try {
      await _comments.doc(id).update({'reported': true});
    } catch (e) {
      debugPrint('SocialSync.reportComment failed: $e');
    }
  }

  /// Şikayeti temizle (yorum yayında kalsın).
  Future<void> clearCommentReport(String id) async {
    try {
      await _comments.doc(id).update({'reported': false});
    } catch (e) {
      debugPrint('SocialSync.clearCommentReport failed: $e');
    }
  }

  /// Şikayet edilmiş yorumlar (admin). Her biri 'id' taşır.
  Future<List<Map<String, dynamic>>> loadReportedComments() async {
    try {
      final snap = await _comments.where('reported', isEqualTo: true).get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        return m;
      }).toList();
    } catch (e) {
      debugPrint('SocialSync.loadReportedComments failed: $e');
      return [];
    }
  }

  Future<void> rejectComment(String id) async {
    try {
      await _comments.doc(id).delete();
    } catch (e) {
      debugPrint('SocialSync.rejectComment failed: $e');
    }
  }

  String _today() {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }

  // ---- User-submitted recipes (admin approval → catalog) ----
  CollectionReference<Map<String, dynamic>> get _pending => _db.collection('pendingRecipes');

  /// Submits a user recipe for admin approval. [data] is the recipe JSON.
  Future<String?> submitRecipe(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = await _pending.add({
        ...data,
        'uid': uid,
        'approved': false,
        'ts': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('SocialSync.submitRecipe failed: $e');
      return null;
    }
  }

  /// All recipes awaiting approval (admin). Each item carries its Firestore id
  /// under '_docId'.
  Future<List<Map<String, dynamic>>> loadPendingRecipes() async {
    try {
      final snap = await _pending.where('approved', isEqualTo: false).get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['_docId'] = d.id;
        return m;
      }).toList();
    } catch (e) {
      debugPrint('SocialSync.loadPendingRecipes failed: $e');
      return [];
    }
  }

  Future<void> deletePendingRecipe(String docId) async {
    try {
      await _pending.doc(docId).delete();
    } catch (e) {
      debugPrint('SocialSync.deletePendingRecipe failed: $e');
    }
  }

  // ---- Expert verification (uzman doğrulama) ----
  CollectionReference<Map<String, dynamic>> get _experts => _db.collection('experts');
  CollectionReference<Map<String, dynamic>> get _expertReqs => _db.collection('expertRequests');

  /// Onaylı uzmanları yükler → globalExperts[username] = type.
  Future<void> loadExperts() async {
    try {
      final snap = await _experts.get();
      globalExperts.clear();
      for (final d in snap.docs) {
        final m = d.data();
        final u = (m['username']?.toString() ?? '').toLowerCase().trim();
        final t = m['type']?.toString() ?? '';
        if (u.isNotEmpty && t.isNotEmpty) globalExperts[u] = t;
      }
    } catch (e) {
      debugPrint('SocialSync.loadExperts failed: $e');
    }
  }

  /// Kullanıcı uzman etiketi talep eder (admin onayına gider).
  Future<String?> submitExpertRequest({required String username, required String type, required String university, required String diploma}) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = await _expertReqs.add({
        'uid': uid,
        'username': username,
        'type': type,
        'university': university,
        'diploma': diploma,
        'approved': false,
        'ts': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('SocialSync.submitExpertRequest failed: $e');
      return null;
    }
  }

  /// Onay bekleyen uzman talepleri (admin). Her birinde '_docId'.
  Future<List<Map<String, dynamic>>> loadPendingExpertRequests() async {
    try {
      final snap = await _expertReqs.where('approved', isEqualTo: false).get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['_docId'] = d.id;
        return m;
      }).toList();
    } catch (e) {
      debugPrint('SocialSync.loadPendingExpertRequests failed: $e');
      return [];
    }
  }

  /// Talebi onaylar: /experts/{uid} yazar, talebi siler, kullanıcıya bildirir.
  Future<void> approveExpertRequest(String docId, {required String uid, required String username, required String type}) async {
    try {
      await _experts.doc(uid).set({'uid': uid, 'username': username, 'type': type, 'ts': FieldValue.serverTimestamp()});
      await _expertReqs.doc(docId).delete();
      globalExperts[username.toLowerCase().trim()] = type;
      await sendNotification(uid, "Uzman etiketin onaylandı 🎓", "Artık '$type' uzman etiketine sahipsin. İçeriklerin uzman olarak görünecek.");
    } catch (e) {
      debugPrint('SocialSync.approveExpertRequest failed: $e');
    }
  }

  Future<void> rejectExpertRequest(String docId) async {
    try {
      await _expertReqs.doc(docId).delete();
    } catch (e) {
      debugPrint('SocialSync.rejectExpertRequest failed: $e');
    }
  }

  // ---- Public profiles ----
  CollectionReference<Map<String, dynamic>> get _profiles => _db.collection('profiles');

  /// Kayıtlı public profil sayısı (admin istatistiği — kullanıcı sayısına
  /// yaklaşık proxy). Hata/izin yoksa null döner.
  Future<int?> profileCount() async {
    try {
      final snap = await _profiles.count().get();
      return snap.count;
    } catch (e) {
      debugPrint('SocialSync.profileCount failed: $e');
      return null;
    }
  }

  /// Tüm public profilleri getirir (admin listesi için; en çok [limit]).
  Future<List<Map<String, dynamic>>> loadAllProfiles({int limit = 300}) async {
    try {
      final snap = await _profiles.limit(limit).get();
      return snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
    } catch (e) {
      debugPrint('SocialSync.loadAllProfiles failed: $e');
      return [];
    }
  }

  /// Saves the current user's public profile at /profiles/{uid}.
  Future<void> saveProfile(Map<String, dynamic> json) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _profiles.doc(uid).set({...json, 'uid': uid});
    } catch (e) {
      debugPrint('SocialSync.saveProfile failed: $e');
    }
  }

  /// Takip edilen @kullanıcı adlarını buluta yansıtır (/profiles/{uid}.following).
  Future<void> setFollowing(List<String> usernames) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _profiles.doc(uid).set({'following': usernames, 'uid': uid}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SocialSync.setFollowing failed: $e');
    }
  }

  // ---- In-app notifications ----
  CollectionReference<Map<String, dynamic>> get _notifs => _db.collection('notifications');

  /// Sends an in-app notification to [toUid] (admin action).
  Future<void> sendNotification(String toUid, String title, String body, {String type = 'info'}) async {
    if (toUid.isEmpty) return;
    try {
      await _notifs.add({
        'toUid': toUid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'date': _today(),
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SocialSync.sendNotification failed: $e');
    }
  }

  /// Loads the current user's notifications (newest first) into [globalNotifications].
  Future<void> loadNotifications() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _notifs.where('toUid', isEqualTo: uid).get();
      final list = snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] = d.id;
        m['_ms'] = (d.data()['ts'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return m;
      }).toList();
      list.sort((a, b) => (b['_ms'] as int).compareTo(a['_ms'] as int));
      globalNotifications
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('SocialSync.loadNotifications failed: $e');
    }
  }

  /// Marks all of the user's unread notifications as read (locally + cloud).
  Future<void> markAllNotificationsRead() async {
    for (final n in globalNotifications.where((n) => n['read'] != true).toList()) {
      n['read'] = true;
      final id = n['id']?.toString();
      if (id != null) {
        try {
          await _notifs.doc(id).update({'read': true});
        } catch (_) {}
      }
    }
  }

  /// Loads a public profile by its @username; caches it in globalKnownProfiles.
  Future<Map<String, dynamic>?> loadProfileByUsername(String username) async {
    final u = username.trim();
    if (u.isEmpty) return null;
    try {
      final snap = await _profiles.where('username', isEqualTo: u).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final m = Map<String, dynamic>.from(snap.docs.first.data());
      globalKnownProfiles[u] = m;
      return m;
    } catch (e) {
      debugPrint('SocialSync.loadProfileByUsername failed: $e');
      return null;
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
