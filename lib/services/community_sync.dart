// Topluluk senkronu (Firestore). SocialSync deseninin aynısı.
//
//   /communityPosts/{id}                 → gönderi (approved:false → admin onayı)
//   /communityPosts/{id}/replies/{rid}   → yanıt (anında yayın)
//   /communityPosts/{id}/likes/{uid}     → beğeni (çift saymayı önler)
//   /communityPosts/{id}/reports/{uid}   → şikayet (çift saymayı önler)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/community_store.dart';

class CommunitySync {
  CommunitySync._();
  static final CommunitySync instance = CommunitySync._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('communityPosts');

  // ---- Gönderiler ----

  /// Yeni gönderiyi admin onayına gönderir (approved:false). Doc id döner.
  Future<String?> submitPost({
    required String title,
    required String body,
    required String category,
    required String authorName,
    String imageUrl = "",
    bool anonymous = false,
    List<String> pollOptions = const [],
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = await _posts.add({
        'title': title,
        'body': body,
        'category': category,
        'imageUrl': imageUrl,
        'authorUid': uid,
        'authorName': authorName,
        'anonymous': anonymous,
        'approved': false,
        'hidden': false,
        'pinned': false,
        'solved': false,
        'acceptedReplyId': '',
        'likeCount': 0,
        'replyCount': 0,
        'reportCount': 0,
        'createdMs': DateTime.now().millisecondsSinceEpoch,
        if (pollOptions.isNotEmpty) ...{
          'pollOptions': pollOptions,
          'pollVotes': List<int>.filled(pollOptions.length, 0),
          'pollVotedBy': <String, int>{},
        },
        'ts': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('CommunitySync.submitPost failed: $e');
      return null;
    }
  }

  /// Yayınlanmış (approved + gizli değil) gönderileri yükler → globalCommunityPosts.
  /// Tek eşitlik filtresi (composite index gerekmez); gizli/sıralama istemci tarafında.
  Future<void> loadPosts() async {
    try {
      final snap = await _posts.where('approved', isEqualTo: true).get();
      final visible = <CommunityPost>[];
      for (final d in snap.docs) {
        if (d.data()['hidden'] == true) continue; // gizlenenleri ele
        visible.add(CommunityPost.fromMap(d.id, d.data()));
      }
      visible.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdMs.compareTo(a.createdMs);
      });
      globalCommunityPosts
        ..clear()
        ..addAll(visible);
    } catch (e) {
      debugPrint('CommunitySync.loadPosts failed: $e');
    }
  }

  /// Admin: onay bekleyen gönderiler.
  Future<List<CommunityPost>> loadPendingPosts() async {
    try {
      final snap = await _posts.where('approved', isEqualTo: false).get();
      final list = snap.docs.map((d) => CommunityPost.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.createdMs.compareTo(a.createdMs));
      return list;
    } catch (e) {
      debugPrint('CommunitySync.loadPendingPosts failed: $e');
      return [];
    }
  }

  /// Admin: şikayet edilen yayınlanmış gönderiler (reportCount > 0).
  Future<List<CommunityPost>> loadReportedPosts() async {
    try {
      final snap = await _posts.where('reportCount', isGreaterThan: 0).get();
      final list = snap.docs.map((d) => CommunityPost.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.reportCount.compareTo(a.reportCount));
      return list;
    } catch (e) {
      debugPrint('CommunitySync.loadReportedPosts failed: $e');
      return [];
    }
  }

  Future<void> approvePost(String id) async {
    try {
      await _posts.doc(id).update({'approved': true});
    } catch (e) {
      debugPrint('CommunitySync.approvePost failed: $e');
    }
  }

  /// Admin: gönderi alanlarını günceller (incele/düzenle). [fields] yalnız
  /// değiştirilen alanları içerir (title/body/category/imageUrl/anonymous,
  /// istenirse approved).
  Future<void> updatePost(String id, Map<String, dynamic> fields) async {
    try {
      await _posts.doc(id).update(fields);
    } catch (e) {
      debugPrint('CommunitySync.updatePost failed: $e');
    }
  }

  Future<void> deletePost(String id) async {
    try {
      await _posts.doc(id).delete();
    } catch (e) {
      debugPrint('CommunitySync.deletePost failed: $e');
    }
  }

  Future<void> setHidden(String id, bool hidden) async {
    try {
      await _posts.doc(id).update({'hidden': hidden, if (!hidden) 'reportCount': 0});
    } catch (e) {
      debugPrint('CommunitySync.setHidden failed: $e');
    }
  }

  Future<void> setPinned(String id, bool pinned) async {
    try {
      await _posts.doc(id).update({'pinned': pinned});
    } catch (e) {
      debugPrint('CommunitySync.setPinned failed: $e');
    }
  }

  // ---- Yanıtlar ----

  Future<List<CommunityReply>> loadReplies(String postId) async {
    try {
      final snap = await _posts.doc(postId).collection('replies').get();
      final list = snap.docs.map((d) => CommunityReply.fromMap(postId, d.id, d.data())).toList();
      list.sort((a, b) => a.createdMs.compareTo(b.createdMs)); // eskiden yeniye
      globalCommunityReplies[postId] = list;
      return list;
    } catch (e) {
      debugPrint('CommunitySync.loadReplies failed: $e');
      return [];
    }
  }

  /// Yanıt ekler (anında yayın) + gönderinin replyCount'unu artırır.
  Future<String?> addReply(String postId, {required String body, required String authorName, bool anonymous = false}) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = await _posts.doc(postId).collection('replies').add({
        'body': body,
        'authorUid': uid,
        'authorName': authorName,
        'anonymous': anonymous,
        'accepted': false,
        'likeCount': 0,
        'createdMs': DateTime.now().millisecondsSinceEpoch,
        'ts': FieldValue.serverTimestamp(),
      });
      await _posts.doc(postId).update({'replyCount': FieldValue.increment(1)});
      return ref.id;
    } catch (e) {
      debugPrint('CommunitySync.addReply failed: $e');
      return null;
    }
  }

  Future<void> deleteReply(String postId, String replyId) async {
    try {
      await _posts.doc(postId).collection('replies').doc(replyId).delete();
      await _posts.doc(postId).update({'replyCount': FieldValue.increment(-1)});
    } catch (e) {
      debugPrint('CommunitySync.deleteReply failed: $e');
    }
  }

  // ---- Beğeni ----

  /// Gönderi beğenisini açar/kapatır (uid başına tek). Yeni likeCount döner (null=hata).
  Future<int?> toggleLike(String postId, bool liked) async {
    final uid = _uid;
    if (uid == null) return null;
    final postRef = _posts.doc(postId);
    final myRef = postRef.collection('likes').doc(uid);
    try {
      return await _db.runTransaction<int>((tx) async {
        final already = (await tx.get(myRef)).exists;
        final postSnap = await tx.get(postRef);
        var count = (postSnap.data()?['likeCount'] as num?)?.toInt() ?? 0;
        if (liked && !already) {
          count += 1;
          tx.set(postRef, {'likeCount': count}, SetOptions(merge: true));
          tx.set(myRef, {'ts': FieldValue.serverTimestamp()});
        } else if (!liked && already) {
          count = count > 0 ? count - 1 : 0;
          tx.set(postRef, {'likeCount': count}, SetOptions(merge: true));
          tx.delete(myRef);
        }
        return count;
      });
    } catch (e) {
      debugPrint('CommunitySync.toggleLike failed: $e');
      return null;
    }
  }

  // ---- Anket ----

  /// Ankete oy verir (uid başına tek). Güncel oy listesini döner (null=hata/zaten oy).
  Future<List<int>?> votePoll(String postId, int optionIndex) async {
    final uid = _uid;
    if (uid == null) return null;
    final postRef = _posts.doc(postId);
    try {
      return await _db.runTransaction<List<int>?>((tx) async {
        final snap = await tx.get(postRef);
        final data = snap.data() ?? {};
        final votedBy = Map<String, dynamic>.from(data['pollVotedBy'] as Map? ?? {});
        if (votedBy.containsKey(uid)) return null; // zaten oy verdi
        final votes = (data['pollVotes'] as List?)?.map((e) => (e as num?)?.toInt() ?? 0).toList() ?? <int>[];
        if (optionIndex < 0 || optionIndex >= votes.length) return null;
        votes[optionIndex] += 1;
        votedBy[uid] = optionIndex;
        tx.update(postRef, {'pollVotes': votes, 'pollVotedBy': votedBy});
        return votes;
      });
    } catch (e) {
      debugPrint('CommunitySync.votePoll failed: $e');
      return null;
    }
  }

  // ---- Çözüldü / en iyi yanıt ----

  /// Soran kişi (veya admin) en iyi yanıtı işaretler; gönderiyi 'çözüldü' yapar.
  Future<void> acceptReply(String postId, String replyId) async {
    try {
      // Önceki kabul edilen yanıtı temizle.
      final repls = await _posts.doc(postId).collection('replies').where('accepted', isEqualTo: true).get();
      for (final d in repls.docs) {
        await d.reference.update({'accepted': false});
      }
      await _posts.doc(postId).collection('replies').doc(replyId).update({'accepted': true});
      await _posts.doc(postId).update({'solved': true, 'acceptedReplyId': replyId});
    } catch (e) {
      debugPrint('CommunitySync.acceptReply failed: $e');
    }
  }

  // ---- Şikayet ----

  /// Gönderiyi şikayet eder (uid başına tek). Yeni reportCount döner.
  Future<void> reportPost(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final postRef = _posts.doc(postId);
    final myRef = postRef.collection('reports').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final already = (await tx.get(myRef)).exists;
        if (already) return;
        tx.set(postRef, {'reportCount': FieldValue.increment(1)}, SetOptions(merge: true));
        tx.set(myRef, {'ts': FieldValue.serverTimestamp()});
      });
    } catch (e) {
      debugPrint('CommunitySync.reportPost failed: $e');
    }
  }
}
