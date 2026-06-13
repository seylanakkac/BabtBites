import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/admin_store.dart';
import '../data/extras_store.dart';
import '../data/food_database.dart';
import '../data/recipe_social_store.dart';
import '../data/tracking_store.dart';
import '../screens/articles_screen.dart';
import '../screens/home_screen.dart';
import '../screens/recipe_detail_screen.dart';

/// Session flag: true when the admin account is logged in.
bool globalIsAdmin = false;

/// Reactive mirror of [globalIsAdmin] so the app frame can rebuild when the
/// admin logs in/out at runtime (the MaterialApp.builder doesn't re-run on
/// navigation). Always change admin state via [setAdminMode].
final ValueNotifier<bool> adminModeNotifier = ValueNotifier<bool>(false);

void setAdminMode(bool value) {
  globalIsAdmin = value;
  adminModeNotifier.value = value;
}

/// Centralised persistence layer for BabyBites.
///
/// The app keeps its mutable user data in a handful of top-level globals
/// (`globalWeeklyPlan`, `globalCartList`, `globalCartQuantities`, and the
/// `tried` / `isFavorite` flags on `globalFoodsDatabase`). This service is the
/// single place that reads/writes those globals to disk so the data survives an
/// app restart. All disk access is wrapped in try/catch — a storage failure or
/// corrupt payload must never crash the app, it just falls back to defaults.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _kBabies = 'babies';
  static const String _kWeeklyPlan = 'weekly_plan';
  static const String _kCartList = 'cart_list';
  static const String _kCartQty = 'cart_quantities';
  static const String _kCartChecked = 'cart_checked';
  static const String _kFavoriteRecipes = 'favorite_recipes';
  static const String _kRecipeViews = 'recipe_views';
  static const String _kRecipeComments = 'recipe_comments';
  static const String _kRecipeTriedPhotos = 'recipe_tried_photos';
  static const String _kRecipeTried = 'recipe_tried';
  static const String _kGrowth = 'growth_records';
  static const String _kMilestones = 'milestones_done';
  static const String _kPremium = 'is_premium';
  static const String _kTrialStart = 'trial_start';
  static const String _kTried = 'tried_foods';
  static const String _kFavorites = 'favorite_foods';
  static const String _kSupplements = 'supplements_plan';
  static const String _kParent = 'parent_identity';
  static const String _kBabyFoodStates = 'baby_food_states';
  static const String _kReminders = 'reminders';
  static const String _kBabyMeds = 'baby_meds';
  static const String _kDailyLogs = 'daily_logs';
  static const String _kCustomFoods = 'custom_foods';
  static const String _kCustomRecipes = 'custom_recipes';
  static const String _kCustomArticles = 'custom_articles';
  static const String _kFoodOverrides = 'food_overrides';
  static const String _kDeletedFoods = 'deleted_foods';
  static const String _kRecipeOverrides = 'recipe_overrides';
  static const String _kDeletedRecipes = 'deleted_recipes';
  static const String _kArticleOverrides = 'article_overrides';
  static const String _kDeletedArticles = 'deleted_articles';
  static const String _kAdminConfig = 'admin_config';
  static const String _kIsAdmin = 'is_admin';

  SharedPreferences? _prefs;
  bool get isReady => _prefs != null;

  /// Must be awaited once during app startup, before [loadInto].
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('StorageService.init failed: $e');
      _prefs = null;
    }
  }

  /// Returns the persisted baby list, or `null` when nothing has been saved yet
  /// (so callers can fall back to onboarding data / defaults).
  List<Map<String, dynamic>>? loadBabies() {
    final raw = _prefs?.getString(_kBabies);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('StorageService.loadBabies failed: $e');
      return null;
    }
  }

  /// Restores the persisted cart, weekly plan and food flags into the in-memory
  /// globals. Safe to call when nothing is stored yet — globals keep their
  /// seeded defaults in that case.
  void loadInto() {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      // Restore the admin session so a page reload stays in the admin area.
      setAdminMode(prefs.getBool(_kIsAdmin) ?? false);
      final weeklyRaw = prefs.getString(_kWeeklyPlan);
      if (weeklyRaw != null) {
        final decoded = jsonDecode(weeklyRaw) as Map<String, dynamic>;
        globalWeeklyPlan.clear();
        decoded.forEach((day, meals) {
          final mealMap = <String, List<String>>{};
          (meals as Map<String, dynamic>).forEach((slot, items) {
            mealMap[slot] =
                (items as List<dynamic>).map((e) => e.toString()).toList();
          });
          globalWeeklyPlan[day] = mealMap;
        });
      }

      final cartRaw = prefs.getString(_kCartList);
      if (cartRaw != null) {
        globalCartList
          ..clear()
          ..addAll((jsonDecode(cartRaw) as List<dynamic>)
              .map((e) => e.toString()));
      }

      final qtyRaw = prefs.getString(_kCartQty);
      if (qtyRaw != null) {
        globalCartQuantities.clear();
        (jsonDecode(qtyRaw) as Map<String, dynamic>).forEach((key, value) {
          globalCartQuantities[key] = (value as num).toInt();
        });
      }

      final checkedRaw = prefs.getStringList(_kCartChecked);
      if (checkedRaw != null) {
        globalCartChecked
          ..clear()
          ..addAll(checkedRaw);
      }

      final favRecipesRaw = prefs.getStringList(_kFavoriteRecipes);
      if (favRecipesRaw != null) {
        globalFavoriteRecipes
          ..clear()
          ..addAll(favRecipesRaw);
      }

      final viewsRaw = prefs.getString(_kRecipeViews);
      if (viewsRaw != null) {
        globalRecipeViews.clear();
        (jsonDecode(viewsRaw) as Map<String, dynamic>).forEach((k, v) => globalRecipeViews[k] = (v as num).toInt());
      }
      final commentsRaw = prefs.getString(_kRecipeComments);
      if (commentsRaw != null) {
        globalRecipeComments.clear();
        (jsonDecode(commentsRaw) as Map<String, dynamic>).forEach((k, v) {
          globalRecipeComments[k] = (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
      final triedPhotosRaw = prefs.getString(_kRecipeTriedPhotos);
      if (triedPhotosRaw != null) {
        globalRecipeTriedPhotos.clear();
        (jsonDecode(triedPhotosRaw) as Map<String, dynamic>).forEach((k, v) {
          globalRecipeTriedPhotos[k] = (v as List).map((e) => e.toString()).toList();
        });
      }
      final recipeTriedRaw = prefs.getStringList(_kRecipeTried);
      if (recipeTriedRaw != null) {
        globalRecipeTried
          ..clear()
          ..addAll(recipeTriedRaw);
      }

      final growthRaw = prefs.getString(_kGrowth);
      if (growthRaw != null) {
        globalGrowthRecords.clear();
        (jsonDecode(growthRaw) as Map<String, dynamic>).forEach((k, v) {
          globalGrowthRecords[k] = (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
      final milestonesRaw = prefs.getString(_kMilestones);
      if (milestonesRaw != null) {
        globalMilestonesDone.clear();
        (jsonDecode(milestonesRaw) as Map<String, dynamic>).forEach((k, v) {
          globalMilestonesDone[k] = (v as List).map((e) => e.toString()).toSet();
        });
      }
      globalIsPremium = prefs.getBool(_kPremium) ?? false;
      globalTrialStart = prefs.getString(_kTrialStart);

      final tried = prefs.getStringList(_kTried)?.toSet();
      final favorites = prefs.getStringList(_kFavorites)?.toSet();
      if (tried != null || favorites != null) {
        for (final food in globalFoodsDatabase) {
          if (tried != null) food.tried = tried.contains(food.name);
          if (favorites != null) {
            food.isFavorite = favorites.contains(food.name);
          }
        }
      }

      // Per-baby food states.
      final fsRaw = prefs.getString(_kBabyFoodStates);
      if (fsRaw != null) {
        globalBabyFoodStates.clear();
        (jsonDecode(fsRaw) as Map<String, dynamic>).forEach((babyId, foods) {
          final m = <String, dynamic>{};
          (foods as Map<String, dynamic>).forEach((foodName, st) {
            m[foodName] = Map<String, dynamic>.from(st as Map);
          });
          globalBabyFoodStates[babyId] = m;
        });
      }

      // Per-baby reminders.
      final remRaw = prefs.getString(_kReminders);
      if (remRaw != null) {
        globalReminders.clear();
        (jsonDecode(remRaw) as Map<String, dynamic>).forEach((babyId, list) {
          globalReminders[babyId] = (list as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }

      // Per-baby supplement/medication definitions.
      final medsRaw = prefs.getString(_kBabyMeds);
      if (medsRaw != null) {
        globalBabyMeds.clear();
        (jsonDecode(medsRaw) as Map<String, dynamic>).forEach((babyId, list) {
          globalBabyMeds[babyId] = (list as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }

      // Per-baby daily logs (diaper counts + taken toggles).
      final logsRaw = prefs.getString(_kDailyLogs);
      if (logsRaw != null) {
        globalDailyLogs.clear();
        (jsonDecode(logsRaw) as Map<String, dynamic>).forEach((babyId, days) {
          final m = <String, dynamic>{};
          (days as Map<String, dynamic>).forEach((dateKey, log) {
            m[dateKey] = Map<String, dynamic>.from(log as Map);
          });
          globalDailyLogs[babyId] = m;
        });
      }

      // Admin-added custom content → merge into the global databases.
      final cf = prefs.getString(_kCustomFoods);
      if (cf != null) {
        final list = (jsonDecode(cf) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        globalCustomFoods
          ..clear()
          ..addAll(list);
        for (final j in list) {
          if (!globalFoodsDatabase.any((f) => f.name == j["name"])) {
            globalFoodsDatabase.add(Food.fromJson(j));
          }
        }
      }
      final cr = prefs.getString(_kCustomRecipes);
      if (cr != null) {
        final list = (jsonDecode(cr) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        globalCustomRecipes
          ..clear()
          ..addAll(list);
        for (final j in list) {
          if (!globalRecipesDatabase.any((r) => r.id == j["id"] || r.name == j["name"])) {
            globalRecipesDatabase.add(Recipe.fromJson(j));
          }
        }
      }
      final ca = prefs.getString(_kCustomArticles);
      if (ca != null) {
        final list = (jsonDecode(ca) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        globalCustomArticles
          ..clear()
          ..addAll(list.map(Article.fromJson));
      }

      // Admin CMS layer: config + built-in overrides/deletions (after custom merge).
      _applyAdminLayer(prefs);
    } catch (e) {
      debugPrint('StorageService.loadInto failed: $e');
    }
  }

  /// Applies the admin config and built-in content overrides/deletions to the
  /// in-memory databases. Runs at the end of [loadInto].
  void _applyAdminLayer(SharedPreferences prefs) {
    final cfg = prefs.getString(_kAdminConfig);
    if (cfg != null) {
      globalAdminConfig
        ..clear()
        ..addAll(jsonDecode(cfg) as Map<String, dynamic>);
    }

    final fo = prefs.getString(_kFoodOverrides);
    if (fo != null) {
      globalFoodOverrides.clear();
      (jsonDecode(fo) as Map<String, dynamic>).forEach((name, j) {
        final json = Map<String, dynamic>.from(j as Map);
        globalFoodOverrides[name] = json;
        final idx = globalFoodsDatabase.indexWhere((f) => f.name == name);
        if (idx >= 0) globalFoodsDatabase[idx] = Food.fromJson(json);
      });
    }
    final df = prefs.getStringList(_kDeletedFoods);
    if (df != null) {
      globalDeletedFoods
        ..clear()
        ..addAll(df);
      globalFoodsDatabase.removeWhere((f) => globalDeletedFoods.contains(f.name));
    }

    final ro = prefs.getString(_kRecipeOverrides);
    if (ro != null) {
      globalRecipeOverrides.clear();
      (jsonDecode(ro) as Map<String, dynamic>).forEach((rid, j) {
        final json = Map<String, dynamic>.from(j as Map);
        globalRecipeOverrides[rid] = json;
        final idx = globalRecipesDatabase.indexWhere((r) => r.id == rid);
        if (idx >= 0) globalRecipesDatabase[idx] = Recipe.fromJson(json);
      });
    }
    final dr = prefs.getStringList(_kDeletedRecipes);
    if (dr != null) {
      globalDeletedRecipes
        ..clear()
        ..addAll(dr);
      globalRecipesDatabase.removeWhere((r) => globalDeletedRecipes.contains(r.id));
    }

    final ao = prefs.getString(_kArticleOverrides);
    if (ao != null) {
      globalArticleOverrides.clear();
      (jsonDecode(ao) as Map<String, dynamic>).forEach((aid, j) {
        globalArticleOverrides[aid] = Map<String, dynamic>.from(j as Map);
      });
    }
    final da = prefs.getStringList(_kDeletedArticles);
    if (da != null) {
      globalDeletedArticles
        ..clear()
        ..addAll(da);
    }
  }

  /// Persists admin overrides/deletions and the app config. Call after the
  /// admin edits/deletes built-in content or changes config.
  Future<void> saveAdminContent() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kFoodOverrides, jsonEncode(globalFoodOverrides));
      await prefs.setStringList(_kDeletedFoods, globalDeletedFoods.toList());
      await prefs.setString(_kRecipeOverrides, jsonEncode(globalRecipeOverrides));
      await prefs.setStringList(_kDeletedRecipes, globalDeletedRecipes.toList());
      await prefs.setString(_kArticleOverrides, jsonEncode(globalArticleOverrides));
      await prefs.setStringList(_kDeletedArticles, globalDeletedArticles.toList());
      await prefs.setString(_kAdminConfig, jsonEncode(globalAdminConfig));
    } catch (e) {
      debugPrint('StorageService.saveAdminContent failed: $e');
    }
  }

  /// Persists recipe social data (views/comments/tried). Call after the admin
  /// approves/rejects a comment.
  Future<void> saveRecipeSocial() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kRecipeViews, jsonEncode(globalRecipeViews));
      await prefs.setString(_kRecipeComments, jsonEncode(globalRecipeComments));
      await prefs.setString(_kRecipeTriedPhotos, jsonEncode(globalRecipeTriedPhotos));
      await prefs.setStringList(_kRecipeTried, globalRecipeTried.toList());
    } catch (e) {
      debugPrint('StorageService.saveRecipeSocial failed: $e');
    }
  }

  /// Persists admin-added custom foods/recipes/articles. Call after the admin
  /// adds content.
  Future<void> saveCustomContent() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kCustomFoods, jsonEncode(globalCustomFoods));
      await prefs.setString(_kCustomRecipes, jsonEncode(globalCustomRecipes));
      await prefs.setString(
        _kCustomArticles,
        jsonEncode(globalCustomArticles.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('StorageService.saveCustomContent failed: $e');
    }
  }

  /// Returns the persisted supplements/medications plan keyed by date, or
  /// `null` when nothing has been saved yet.
  Map<String, List<Map<String, dynamic>>>? loadSupplements() {
    final raw = _prefs?.getString(_kSupplements);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((day, list) => MapEntry(
            day,
            (list as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          ));
    } catch (e) {
      debugPrint('StorageService.loadSupplements failed: $e');
      return null;
    }
  }

  /// Persists the supplements/medications plan.
  Future<void> saveSupplements(
      Map<String, List<Map<String, dynamic>>> plan) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kSupplements, jsonEncode(plan));
    } catch (e) {
      debugPrint('StorageService.saveSupplements failed: $e');
    }
  }

  /// Returns the persisted parent identity {name, relationship}, or null.
  Map<String, String>? loadParent() {
    final raw = _prefs?.getString(_kParent);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('StorageService.loadParent failed: $e');
      return null;
    }
  }

  /// Persists the admin session flag (survives page reload).
  Future<void> saveIsAdmin(bool value) async {
    try {
      await _prefs?.setBool(_kIsAdmin, value);
    } catch (e) {
      debugPrint('StorageService.saveIsAdmin failed: $e');
    }
  }

  /// Persists the parent identity (name + relationship to the baby).
  Future<void> saveParent(String name, String relationship) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _kParent,
        jsonEncode({'name': name, 'relationship': relationship}),
      );
    } catch (e) {
      debugPrint('StorageService.saveParent failed: $e');
    }
  }

  /// Persists only the baby list. Call after add/edit/remove of a baby.
  Future<void> saveBabies(List<Map<String, dynamic>> babies) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kBabies, jsonEncode(babies));
    } catch (e) {
      debugPrint('StorageService.saveBabies failed: $e');
    }
  }

  /// Persists the entire user state. Cheap enough to call on every meaningful
  /// change and whenever the app is backgrounded.
  Future<void> saveAll(List<Map<String, dynamic>> babies) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kBabies, jsonEncode(babies));
      await prefs.setString(_kWeeklyPlan, jsonEncode(globalWeeklyPlan));
      await prefs.setString(_kCartList, jsonEncode(globalCartList));
      await prefs.setString(_kCartQty, jsonEncode(globalCartQuantities));
      await prefs.setStringList(_kCartChecked, globalCartChecked.toList());
      await prefs.setStringList(_kFavoriteRecipes, globalFavoriteRecipes.toList());
      await prefs.setString(_kRecipeViews, jsonEncode(globalRecipeViews));
      await prefs.setString(_kRecipeComments, jsonEncode(globalRecipeComments));
      await prefs.setString(_kRecipeTriedPhotos, jsonEncode(globalRecipeTriedPhotos));
      await prefs.setStringList(_kRecipeTried, globalRecipeTried.toList());
      await prefs.setStringList(
        _kTried,
        globalFoodsDatabase.where((f) => f.tried).map((f) => f.name).toList(),
      );
      await prefs.setStringList(
        _kFavorites,
        globalFoodsDatabase
            .where((f) => f.isFavorite)
            .map((f) => f.name)
            .toList(),
      );
      await prefs.setString(_kBabyFoodStates, jsonEncode(globalBabyFoodStates));
      await prefs.setString(_kReminders, jsonEncode(globalReminders));
      await prefs.setString(_kBabyMeds, jsonEncode(globalBabyMeds));
      await prefs.setString(_kDailyLogs, jsonEncode(globalDailyLogs));
      await prefs.setString(_kGrowth, jsonEncode(globalGrowthRecords));
      await prefs.setString(_kMilestones, jsonEncode(globalMilestonesDone.map((k, v) => MapEntry(k, v.toList()))));
      await prefs.setBool(_kPremium, globalIsPremium);
      if (globalTrialStart != null) await prefs.setString(_kTrialStart, globalTrialStart!);
    } catch (e) {
      debugPrint('StorageService.saveAll failed: $e');
    }
  }
}
