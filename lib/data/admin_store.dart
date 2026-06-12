// Admin CMS layer: override/deletion stores for built-in content, plus an
// editable app-config (categories, avatars, default supplements, nutrition
// targets). Persisted by StorageService; applied on startup via
// _applyAdminLayer(). All getters fall back to the built-in defaults below when
// the admin hasn't customised anything.

import 'food_database.dart';
import '../screens/articles_screen.dart';

// ---- Built-in defaults (fallbacks) ----
const List<String> kDefaultFoodCategories = ["Sebze", "Meyve", "Tahıl", "Et", "Balık", "Diğer"];
const List<String> kDefaultArticleCategories = ["Başlangıç", "Alerji", "BLW Yöntemi", "Besinler", "Rutinler"];
const List<String> kDefaultAvatars = [
  "👶", "👧", "👦", "👶🏻", "👶🏼", "👶🏽", "👶🏾", "👶🏿", "🦁", "🐯", "🐼", "🐨", "🐰", "🦊"
];
const List<Map<String, dynamic>> kDefaultSupplements = [
  {"name": "D Vitamini", "dose": "3 damla", "schedule": "Her gün", "type": "takviye", "active": true},
  {"name": "Demir Damlası", "dose": "1 ml", "schedule": "Her gün", "type": "takviye", "active": true},
];
// Selectable supplement/medication names + dose units for the add form.
const List<String> kDefaultSupplementNames = [
  "D Vitamini", "Demir Damlası", "K Vitamini", "Multivitamin", "Omega-3", "Probiyotik", "Çinko", "B12 Vitamini"
];
const List<String> kDefaultDoseUnits = ["damla", "ml", "puf", "mg", "tablet", "ölçek", "adet"];
// Flat map (key -> double) so the admin editor can show one field per value.
const Map<String, double> kDefaultNutritionTargets = {
  "infantEnergyPerKg": 80.0, "infantProteinPerKg": 1.2, "infantFatPerKg": 3.0, "infantIron": 11.0,
  "toddlerEnergyPerKg": 75.0, "toddlerProteinPerKg": 1.2, "toddlerFatPerKg": 2.5, "toddlerIron": 7.0,
  "energyMin": 300.0, "energyMax": 1500.0,
  "proteinMin": 5.0, "proteinMax": 50.0,
  "fatMin": 10.0, "fatMax": 100.0,
};

// ---- Override / deletion layer (built-in content) ----
final Map<String, Map<String, dynamic>> globalFoodOverrides = {}; // foodName -> json
final Set<String> globalDeletedFoods = {};
final Map<String, Map<String, dynamic>> globalRecipeOverrides = {}; // recipeId -> json
final Set<String> globalDeletedRecipes = {};
final Map<String, Map<String, dynamic>> globalArticleOverrides = {}; // articleId -> json
final Set<String> globalDeletedArticles = {};

// ---- Editable app config (empty until customised) ----
final Map<String, dynamic> globalAdminConfig = {};

// ---- Config accessors (fall back to defaults) ----
List<String> get foodCategories =>
    (globalAdminConfig["foodCategories"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultFoodCategories);

List<String> get articleCategories =>
    (globalAdminConfig["articleCategories"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultArticleCategories);

List<String> get avatarOptions =>
    (globalAdminConfig["avatars"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultAvatars);

List<Map<String, dynamic>> get defaultSupplements =>
    (globalAdminConfig["defaultSupplements"] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ??
    kDefaultSupplements.map((e) => Map<String, dynamic>.from(e)).toList();

List<String> get supplementNameOptions =>
    (globalAdminConfig["supplementNames"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultSupplementNames);

List<String> get doseUnitOptions =>
    (globalAdminConfig["doseUnits"] as List?)?.map((e) => e.toString()).toList() ??
    List<String>.from(kDefaultDoseUnits);

/// A single nutrition-target constant (config override or built-in default).
double ntv(String key) {
  final cfg = globalAdminConfig["nutritionTargets"];
  final v = (cfg is Map ? cfg[key] : null) ?? kDefaultNutritionTargets[key];
  return (v as num?)?.toDouble() ?? 0;
}

// ---- Content edit/delete helpers (used by the admin managers) ----
bool isCustomFood(String name) => globalCustomFoods.any((m) => m["name"] == name);
bool isCustomRecipe(String id) => globalCustomRecipes.any((m) => m["id"] == id);
bool isCustomArticle(String id) => globalCustomArticles.any((a) => a.id == id);

/// Adds or updates a food (built-in edits go to overrides, custom to the custom list).
void saveFoodEdit(Map<String, dynamic> json) {
  final name = json["name"];
  final idx = globalFoodsDatabase.indexWhere((f) => f.name == name);
  if (idx >= 0) {
    globalFoodsDatabase[idx] = Food.fromJson(json);
  } else {
    globalFoodsDatabase.add(Food.fromJson(json));
  }
  if (isCustomFood(name)) {
    final ci = globalCustomFoods.indexWhere((m) => m["name"] == name);
    if (ci >= 0) {
      globalCustomFoods[ci] = json;
    } else {
      globalCustomFoods.add(json);
    }
  } else {
    globalFoodOverrides[name] = json;
  }
}

void deleteFood(String name) {
  globalFoodsDatabase.removeWhere((f) => f.name == name);
  if (isCustomFood(name)) {
    globalCustomFoods.removeWhere((m) => m["name"] == name);
  } else {
    globalDeletedFoods.add(name);
  }
  globalFoodOverrides.remove(name);
}

void saveRecipeEdit(Map<String, dynamic> json) {
  final id = json["id"];
  final idx = globalRecipesDatabase.indexWhere((r) => r.id == id);
  if (idx >= 0) {
    globalRecipesDatabase[idx] = Recipe.fromJson(json);
  } else {
    globalRecipesDatabase.add(Recipe.fromJson(json));
  }
  if (isCustomRecipe(id)) {
    final ci = globalCustomRecipes.indexWhere((m) => m["id"] == id);
    if (ci >= 0) {
      globalCustomRecipes[ci] = json;
    } else {
      globalCustomRecipes.add(json);
    }
  } else {
    globalRecipeOverrides[id] = json;
  }
}

void deleteRecipe(String id) {
  globalRecipesDatabase.removeWhere((r) => r.id == id);
  if (isCustomRecipe(id)) {
    globalCustomRecipes.removeWhere((m) => m["id"] == id);
  } else {
    globalDeletedRecipes.add(id);
  }
  globalRecipeOverrides.remove(id);
}

void saveArticleEdit(Article article) {
  if (isCustomArticle(article.id)) {
    final ci = globalCustomArticles.indexWhere((a) => a.id == article.id);
    if (ci >= 0) {
      globalCustomArticles[ci] = article;
    } else {
      globalCustomArticles.add(article);
    }
  } else {
    globalArticleOverrides[article.id] = article.toJson();
  }
}

void deleteArticle(String id) {
  if (isCustomArticle(id)) {
    globalCustomArticles.removeWhere((a) => a.id == id);
  } else {
    globalDeletedArticles.add(id);
  }
  globalArticleOverrides.remove(id);
}
