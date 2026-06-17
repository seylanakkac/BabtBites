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

int _seed(String key, int min, int max) {
  final h = key.hashCode.abs();
  return min + (h % (max - min + 1));
}

/// Real cross-user aggregate stats per recipe, loaded from Firestore
/// (`/recipeStats/{id}` → { views, ratingSum, ratingCount, likeCount }).
/// When a recipe has no real data yet, the UI falls back to the stable seed so
/// it doesn't look empty. SocialSync keeps this in sync with the cloud.
final Map<String, Map<String, num>> globalRecipeStats = {};

num? _stat(String id, String key) => globalRecipeStats[id]?[key];

/// Display view count: real cloud views (if any) else stable seed, + this
/// device's own opens this session.
int recipeViewCount(String id) {
  final v = _stat(id, 'views');
  final base = v != null ? v.toInt() : _seed("v_$id", 60, 1400);
  return base + (globalRecipeViews[id] ?? 0);
}

/// Total likes: real cloud like count (if present) else stable seed.
int recipeLikeCount(String id) {
  final l = _stat(id, 'likeCount');
  return l != null ? l.toInt() : _seed("l_$id", 8, 180);
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

/// Average star rating for a recipe = stable community base blended with this
/// device's own vote (if any). Range ~3.8..4.9 before the user votes.
double recipeRatingAverage(String id) {
  final count = (_stat(id, 'ratingCount'))?.toInt() ?? 0;
  if (count > 0) {
    final sum = (_stat(id, 'ratingSum'))?.toDouble() ?? 0;
    return sum / count;
  }
  // No real ratings yet → stable seed so cards aren't empty.
  return _seed("ra_$id", 38, 49) / 10.0;
}

/// Number of ratings shown for a recipe (real count, else stable seed).
int recipeRatingCount(String id) {
  final count = (_stat(id, 'ratingCount'))?.toInt() ?? 0;
  return count > 0 ? count : _seed("rc_$id", 5, 90);
}

/// The star value (1..5) this device gave a recipe, or 0 if not rated.
double myRecipeRating(String id) => globalRecipeMyRating[id] ?? 0;

void setRecipeRating(String id, double value) {
  globalRecipeMyRating[id] = value.clamp(1, 5).toDouble();
}

// ---- User-submitted recipes (admin approval queue) ----

List<Map<String, dynamic>> pendingRecipes() => globalPendingRecipes;

int pendingRecipeCount() => globalPendingRecipes.length;
