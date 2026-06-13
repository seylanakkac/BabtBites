// Per-recipe social data (views, likes, comments, user "tried" photos).
//
// For now this is stored LOCALLY on the device and persisted by StorageService.
// View/like counts use a stable per-recipe base seed so cards look populated;
// the device's own interactions are added on top. When Firebase is added these
// become real cross-user counts (the UI stays the same).

/// recipeId -> number of times opened on THIS device.
final Map<String, int> globalRecipeViews = {};

/// recipeId -> list of comments. Comment shape:
/// { "name": String, "text": String, "date": "yyyy-MM-dd", "photo": base64|"" }
final Map<String, List<Map<String, dynamic>>> globalRecipeComments = {};

/// recipeId -> list of base64 photos uploaded by the user ("Denedim").
final Map<String, List<String>> globalRecipeTriedPhotos = {};

int _seed(String key, int min, int max) {
  final h = key.hashCode.abs();
  return min + (h % (max - min + 1));
}

/// Display view count = stable community base + this device's views.
int recipeViewCount(String id) => _seed("v_$id", 60, 1400) + (globalRecipeViews[id] ?? 0);

/// Stable community "like" base for a recipe (the user's own like is added in UI).
int recipeLikeBase(String id) => _seed("l_$id", 8, 180);

void addRecipeView(String id) {
  globalRecipeViews[id] = (globalRecipeViews[id] ?? 0) + 1;
}

List<Map<String, dynamic>> commentsFor(String id) =>
    globalRecipeComments.putIfAbsent(id, () => []);

List<String> triedPhotosFor(String id) =>
    globalRecipeTriedPhotos.putIfAbsent(id, () => []);
