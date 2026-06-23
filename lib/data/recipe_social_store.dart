// Per-recipe social data (views, likes, comments, user "tried" photos).
//
// For now this is stored LOCALLY on the device and persisted by StorageService.
// View/like counts use a stable per-recipe base seed so cards look populated;
// the device's own interactions are added on top. When Firebase is added these
// become real cross-user counts (the UI stays the same).

/// recipeId -> number of times opened on THIS device.
final Map<String, int> globalRecipeViews = {};

/// recipeId -> list of comments. Comment shape:
/// { "name": String, "text": String, "date": "yyyy-MM-dd", "photo": base64|"",
///   "approved": bool }  // new comments wait for admin approval.
final Map<String, List<Map<String, dynamic>>> globalRecipeComments = {};

/// recipeId -> list of base64 photos uploaded by the user ("Denedim").
final Map<String, List<String>> globalRecipeTriedPhotos = {};

/// Recipe ids the user marked as "Denedim" (tried). Photo is optional.
final Set<String> globalRecipeTried = {};

/// recipeId -> star rating (1..5) this device gave. With Firebase this becomes
/// one rating per user under the recipe.
final Map<String, double> globalRecipeMyRating = {};

/// User-submitted recipes awaiting admin approval. Each item is a Recipe JSON
/// plus { "submittedBy": username, "date": "yyyy-MM-dd" }. NOT added to
/// globalRecipesDatabase until an admin approves it (so it stays unpublished).
final List<Map<String, dynamic>> globalPendingRecipes = [];

/// Real cross-user aggregate stats per recipe, loaded from Firestore
/// (`/recipeStats/{id}` → { views, ratingSum, ratingCount, likeCount }).
/// YALNIZCA gerçek kullanıcı verisi gösterilir (sahte/seed taban kaldırıldı);
/// veri yoksa 0 döner. SocialSync bunu bulutla senkron tutar.
final Map<String, Map<String, num>> globalRecipeStats = {};

num? _stat(String id, String key) => globalRecipeStats[id]?[key];

/// Görüntülenme: gerçek bulut görüntülenmesi + bu cihazın bu oturumdaki açışları.
int recipeViewCount(String id) {
  final v = _stat(id, 'views');
  final base = v != null ? v.toInt() : 0;
  return base + (globalRecipeViews[id] ?? 0);
}

/// Toplam beğeni: yalnızca gerçek bulut beğeni sayısı.
int recipeLikeCount(String id) {
  final l = _stat(id, 'likeCount');
  return l != null ? l.toInt() : 0;
}

/// Deprecated alias kept for older call sites.
int recipeLikeBase(String id) => recipeLikeCount(id);

void addRecipeView(String id) {
  globalRecipeViews[id] = (globalRecipeViews[id] ?? 0) + 1;
}

List<Map<String, dynamic>> commentsFor(String id) =>
    globalRecipeComments.putIfAbsent(id, () => []);

/// Only admin-approved comments (shown publicly inside the recipe).
List<Map<String, dynamic>> approvedCommentsFor(String id) =>
    commentsFor(id).where((c) => c["approved"] == true).toList();

List<String> triedPhotosFor(String id) =>
    globalRecipeTriedPhotos.putIfAbsent(id, () => []);

/// All comments awaiting approval across recipes, for the admin moderation
/// screen. Returns {recipeId, comment} pairs.
List<Map<String, dynamic>> pendingComments() {
  final out = <Map<String, dynamic>>[];
  globalRecipeComments.forEach((rid, list) {
    for (final c in list) {
      if (c["approved"] != true) out.add({"recipeId": rid, "comment": c});
    }
  });
  return out;
}

int pendingCommentCount() => pendingComments().length;

// ---- Star ratings (1..5) ----

/// Gerçek ortalama puan; henüz puan yoksa 0 (seed yok).
double recipeRatingAverage(String id) {
  final count = (_stat(id, 'ratingCount'))?.toInt() ?? 0;
  if (count > 0) {
    final sum = (_stat(id, 'ratingSum'))?.toDouble() ?? 0;
    return sum / count;
  }
  return 0;
}

/// Gerçek puan sayısı; yoksa 0 (seed yok).
int recipeRatingCount(String id) => (_stat(id, 'ratingCount'))?.toInt() ?? 0;

/// Kartlarda gösterilecek puan etiketi: gerçek puan varsa "4.6", yoksa "Yeni".
String recipeRatingLabel(String id) =>
    recipeRatingCount(id) > 0 ? recipeRatingAverage(id).toStringAsFixed(1) : "Yeni";

/// The star value (1..5) this device gave a recipe, or 0 if not rated.
double myRecipeRating(String id) => globalRecipeMyRating[id] ?? 0;

void setRecipeRating(String id, double value) {
  globalRecipeMyRating[id] = value.clamp(1, 5).toDouble();
}

// ---- User-submitted recipes (admin approval queue) ----

List<Map<String, dynamic>> pendingRecipes() => globalPendingRecipes;

int pendingRecipeCount() => globalPendingRecipes.length;
