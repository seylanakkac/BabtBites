// Topluluk (Topluluk/forum) veri modeli + yerel önbellek.
//
// Firebase yapısı (CommunitySync):
//   /communityPosts/{postId}                  → gönderi (admin onaylı yayınlanır)
//   /communityPosts/{postId}/replies/{id}     → yanıtlar (anında yayın)
//   /communityPosts/{postId}/likes/{uid}      → beğeni (çift saymayı önler)
//
// Gönderiler ÖNCE admin onayından geçer (approved:false → onay kuyruğu).
// Yayınlandıktan sonra kullanıcılar şikayet edebilir, admin gizleyebilir/silebilir.

import 'admin_store.dart';

const List<String> kDefaultCommunityCategories = [
  "Ek Gıdaya Geçiş",
  "Beslenme & Tarifler",
  "Uyku Düzeni",
  "Alerji & Sağlık",
  "Diş & Gelişim",
  "Emzirme & Mama",
  "Tuvalet Eğitimi",
  "Anne Psikolojisi",
  "Alışveriş Önerileri",
  "Babalar",
  "Genel Sohbet",
];

/// Topluluk kategorileri (admin düzenleyebilir; yoksa varsayılanlar).
List<String> get communityCategoryOptions =>
    (globalAdminConfig["communityCategories"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultCommunityCategories);

class CommunityPost {
  final String id;
  final String title;
  final String body;
  final String category;
  final String imageUrl;
  final String authorUid;
  final String authorName; // @kullanıcı adı (anonymous true ise gösterilmez)
  final bool anonymous;
  final bool pinned;
  final bool solved;
  final String acceptedReplyId;
  final int likeCount;
  final int replyCount;
  final int reportCount;
  final int createdMs;
  // Anket (opsiyonel): pollOptions boşsa anket yok.
  final List<String> pollOptions;
  final List<int> pollVotes; // pollOptions ile aynı uzunlukta
  final Map<String, int> pollVotedBy; // uid -> seçilen seçenek indexi

  const CommunityPost({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.imageUrl = "",
    required this.authorUid,
    required this.authorName,
    this.anonymous = false,
    this.pinned = false,
    this.solved = false,
    this.acceptedReplyId = "",
    this.likeCount = 0,
    this.replyCount = 0,
    this.reportCount = 0,
    this.createdMs = 0,
    this.pollOptions = const [],
    this.pollVotes = const [],
    this.pollVotedBy = const {},
  });

  bool get hasPoll => pollOptions.isNotEmpty;
  String get displayName => anonymous ? "Anonim" : authorName;
  int get pollTotal => pollVotes.fold(0, (a, b) => a + b);

  factory CommunityPost.fromMap(String id, Map<String, dynamic> m) {
    final opts = (m["pollOptions"] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final votes = (m["pollVotes"] as List?)?.map((e) => (e as num?)?.toInt() ?? 0).toList() ?? const <int>[];
    final votedByRaw = (m["pollVotedBy"] as Map?) ?? const {};
    return CommunityPost(
      id: id,
      title: m["title"]?.toString() ?? "",
      body: m["body"]?.toString() ?? "",
      category: m["category"]?.toString() ?? "Genel Sohbet",
      imageUrl: m["imageUrl"]?.toString() ?? "",
      authorUid: m["authorUid"]?.toString() ?? "",
      authorName: m["authorName"]?.toString() ?? "",
      anonymous: m["anonymous"] == true,
      pinned: m["pinned"] == true,
      solved: m["solved"] == true,
      acceptedReplyId: m["acceptedReplyId"]?.toString() ?? "",
      likeCount: (m["likeCount"] as num?)?.toInt() ?? 0,
      replyCount: (m["replyCount"] as num?)?.toInt() ?? 0,
      reportCount: (m["reportCount"] as num?)?.toInt() ?? 0,
      createdMs: (m["createdMs"] as num?)?.toInt() ?? 0,
      pollOptions: opts,
      pollVotes: votes.length == opts.length ? votes : List<int>.filled(opts.length, 0),
      pollVotedBy: {for (final e in votedByRaw.entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0},
    );
  }
}

class CommunityReply {
  final String id;
  final String postId;
  final String body;
  final String authorUid;
  final String authorName;
  final bool anonymous;
  final bool accepted; // soran kişinin işaretlediği "en iyi yanıt"
  final int likeCount;
  final int createdMs;

  const CommunityReply({
    required this.id,
    required this.postId,
    required this.body,
    required this.authorUid,
    required this.authorName,
    this.anonymous = false,
    this.accepted = false,
    this.likeCount = 0,
    this.createdMs = 0,
  });

  String get displayName => anonymous ? "Anonim" : authorName;

  factory CommunityReply.fromMap(String postId, String id, Map<String, dynamic> m) => CommunityReply(
        id: id,
        postId: postId,
        body: m["body"]?.toString() ?? "",
        authorUid: m["authorUid"]?.toString() ?? "",
        authorName: m["authorName"]?.toString() ?? "",
        anonymous: m["anonymous"] == true,
        accepted: m["accepted"] == true,
        likeCount: (m["likeCount"] as num?)?.toInt() ?? 0,
        createdMs: (m["createdMs"] as num?)?.toInt() ?? 0,
      );
}

/// "3 sa önce" gibi göreli zaman (createdMs).
String communityTimeAgo(int ms) {
  if (ms <= 0) return "";
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return "az önce";
  if (d.inMinutes < 60) return "${d.inMinutes} dk önce";
  if (d.inHours < 24) return "${d.inHours} sa önce";
  if (d.inDays < 7) return "${d.inDays} gün önce";
  return "${(d.inDays / 7).floor()} hf önce";
}

// ---- Yerel önbellek ----
final List<CommunityPost> globalCommunityPosts = []; // yayınlanmış (approved) gönderiler
final Map<String, List<CommunityReply>> globalCommunityReplies = {}; // postId -> yanıtlar
final Set<String> globalMyCommunityLikes = {}; // bu cihazın beğendiği post id'leri (oturum içi)
