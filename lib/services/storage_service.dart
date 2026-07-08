import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/admin_store.dart';
import '../data/extras_store.dart';
import '../data/food_database.dart';
import '../data/recipe_social_store.dart';
import '../data/tracking_store.dart';
import '../data/user_profile_store.dart';
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

/// Emails granted admin access (client-side gate). For production this should
/// be backed by a Firebase custom claim (admin:true) instead — see Faz 3.
const Set<String> kAdminEmails = {
  'admin@babybites.com',
  'seylanakkac@gmail.com',
};

/// True if [email] belongs to an admin account (case-insensitive).
bool isAdminEmail(String? email) =>
    email != null && kAdminEmails.contains(email.trim().toLowerCase());

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
  static const String _kCartUnits = 'cart_units';
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
  static const String _kRecipeRatings = 'recipe_ratings';
  static const String _kPendingRecipes = 'pending_recipes';
  static const String _kMyProfile = 'my_profile';
  static const String _kKnownProfiles = 'known_profiles';
  static const String _kMyFollowing = 'my_following';
  static const String _kBlockedUsers = 'blocked_users';
  static const String _kAdFreeUntil = 'ad_free_until';
  static const String _kPremiumUntil = 'premium_until';
  static const String _kFeatureUnlocks = 'feature_unlocks';
  static const String _kReportFiles = 'report_files';
  static const String _kUserFormulaNames = 'user_formula_names';

  // ---- Cloud sync (Faz 2): which prefs keys are this USER's private data ----
  // (Catalog/admin/social keys are intentionally excluded — those become the
  // shared /catalog in Faz 3.)
  static const List<String> _userStringKeys = [
    _kBabies, _kWeeklyPlan, _kCartList, _kCartQty, _kCartUnits, _kBabyFoodStates, _kReminders,
    _kBabyMeds, _kDailyLogs, _kGrowth, _kMilestones, _kTrialStart, _kParent,
    _kSupplements, _kMyProfile, _kMyFollowing, _kBlockedUsers, _kRecipeRatings, _kAdFreeUntil, _kFeatureUnlocks,
    _kReportFiles, _kPremiumUntil,
  ];
  static const List<String> _userStringListKeys = [
    _kCartChecked, _kFavoriteRecipes, _kRecipeTried, _kTried, _kFavorites,
    _kUserFormulaNames,
  ];
  static const List<String> _userBoolKeys = [_kPremium];

  /// Set by main() to CloudSync.instance.push — called (fire-and-forget) after
  /// any user-data save so the cloud copy stays current. Null until wired.
  static Future<void> Function()? cloudPush;
  void _triggerCloud() {
    final push = cloudPush;
    if (push != null) push();
  }

  // ---- Central catalog (Faz 3): admin-managed content shared with everyone.
  static const List<String> _catalogStringKeys = [
    _kCustomFoods, _kCustomRecipes, _kCustomArticles,
    _kFoodOverrides, _kRecipeOverrides, _kArticleOverrides, _kAdminConfig,
  ];
  static const List<String> _catalogStringListKeys = [
    _kDeletedFoods, _kDeletedRecipes, _kDeletedArticles,
  ];

  /// Set by main() to CatalogSync.instance.push — called after an admin edits
  /// catalog content so the shared /catalog stays current. Null until wired.
  static Future<void> Function()? catalogPush;
  void _triggerCatalog() {
    final push = catalogPush;
    if (push != null) push();
  }

  /// Snapshots the current catalog (admin content) from prefs into a map.
  Map<String, dynamic> exportCatalog() {
    final prefs = _prefs;
    final out = <String, dynamic>{};
    if (prefs == null) return out;
    for (final k in _catalogStringKeys) {
      final v = prefs.getString(k);
      if (v != null) out[k] = v;
    }
    for (final k in _catalogStringListKeys) {
      final v = prefs.getStringList(k);
      if (v != null) out[k] = v;
    }
    return out;
  }

  /// Writes a cloud catalog snapshot into prefs. Does NOT apply it — call this
  /// BEFORE [loadInto] so the catalog is merged cleanly in a single pass.
  Future<void> importCatalog(Map<String, dynamic> data) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      for (final entry in data.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v == null) continue;
        if (_catalogStringListKeys.contains(k) && v is List) {
          await prefs.setStringList(k, v.map((e) => e.toString()).toList());
        } else if (_catalogStringKeys.contains(k) && v is String) {
          await prefs.setString(k, v);
        }
      }
    } catch (e) {
      debugPrint('StorageService.importCatalog failed: $e');
    }
  }

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

      final cartUnitsRaw = prefs.getString(_kCartUnits);
      if (cartUnitsRaw != null) {
        globalCartUnits.clear();
        (jsonDecode(cartUnitsRaw) as Map<String, dynamic>).forEach((key, value) {
          globalCartUnits[key] = value.toString();
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
      final ratingsRaw = prefs.getString(_kRecipeRatings);
      if (ratingsRaw != null) {
        globalRecipeMyRating.clear();
        (jsonDecode(ratingsRaw) as Map<String, dynamic>)
            .forEach((k, v) => globalRecipeMyRating[k] = (v as num).toDouble());
      }
      final pendingRaw = prefs.getString(_kPendingRecipes);
      if (pendingRaw != null) {
        globalPendingRecipes
          ..clear()
          ..addAll((jsonDecode(pendingRaw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map)));
      }

      // User public profile + cache of known profiles (by username).
      final myProfRaw = prefs.getString(_kMyProfile);
      if (myProfRaw != null) {
        globalMyProfile =
            UserProfile.fromJson(jsonDecode(myProfRaw) as Map<String, dynamic>);
        if (globalMyProfile!.username.isNotEmpty) {
          globalKnownProfiles[globalMyProfile!.username] = globalMyProfile!.toJson();
        }
      }
      final knownRaw = prefs.getString(_kKnownProfiles);
      if (knownRaw != null) {
        (jsonDecode(knownRaw) as Map<String, dynamic>).forEach((k, v) {
          globalKnownProfiles[k] = Map<String, dynamic>.from(v as Map);
        });
      }
      final followRaw = prefs.getString(_kMyFollowing);
      if (followRaw != null) {
        globalMyFollowing
          ..clear()
          ..addAll((jsonDecode(followRaw) as List).map((e) => e.toString()));
      }
      final blockedRaw = prefs.getString(_kBlockedUsers);
      if (blockedRaw != null) {
        globalBlockedUsers
          ..clear()
          ..addAll((jsonDecode(blockedRaw) as List).map((e) => e.toString()));
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
      globalPremiumUntil = prefs.getString(_kPremiumUntil);
      refreshPremiumFromExpiry(); // süre dolduysa premium'u kapat
      globalAdFreeUntil = prefs.getString(_kAdFreeUntil);
      final featureUnlocksRaw = prefs.getString(_kFeatureUnlocks);
      if (featureUnlocksRaw != null) {
        globalFeatureUnlocks.clear();
        (jsonDecode(featureUnlocksRaw) as Map<String, dynamic>).forEach((k, v) {
          globalFeatureUnlocks[k] = v.toString();
        });
      }
      final reportFilesRaw = prefs.getString(_kReportFiles);
      if (reportFilesRaw != null) {
        globalReportFiles.clear();
        (jsonDecode(reportFilesRaw) as Map<String, dynamic>).forEach((babyId, list) {
          globalReportFiles[babyId] = (list as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }

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

      // Kullanıcının kendi formül mama adları (beslenme takibi açılır menüsü).
      final ufn = prefs.getStringList(_kUserFormulaNames);
      if (ufn != null) {
        globalUserFormulaNames
          ..clear()
          ..addAll(ufn);
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
    _triggerCatalog();
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
      await prefs.setString(_kRecipeRatings, jsonEncode(globalRecipeMyRating));
      await prefs.setString(_kPendingRecipes, jsonEncode(globalPendingRecipes));
    } catch (e) {
      debugPrint('StorageService.saveRecipeSocial failed: $e');
    }
  }

  /// Persists the current user's public profile + the known-profiles cache.
  Future<void> saveMyProfile() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      if (globalMyProfile != null) {
        await prefs.setString(_kMyProfile, jsonEncode(globalMyProfile!.toJson()));
        if (globalMyProfile!.username.isNotEmpty) {
          globalKnownProfiles[globalMyProfile!.username] = globalMyProfile!.toJson();
        }
      }
      await prefs.setString(_kKnownProfiles, jsonEncode(globalKnownProfiles));
      await prefs.setString(_kMyFollowing, jsonEncode(globalMyFollowing.toList()));
      await prefs.setString(_kBlockedUsers, jsonEncode(globalBlockedUsers.toList()));
    } catch (e) {
      debugPrint('StorageService.saveMyProfile failed: $e');
    }
    _triggerCloud();
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
    _triggerCatalog();
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
    _triggerCloud();
  }

  // ---- Cloud sync (Faz 2) export/import of this user's private data ----

  /// Snapshots the current user's private prefs into a Firestore-safe map
  /// (strings, string-lists and bools). Excludes catalog/admin/social keys.
  Map<String, dynamic> exportUserData() {
    final prefs = _prefs;
    final out = <String, dynamic>{};
    if (prefs == null) return out;
    for (final k in _userStringKeys) {
      final v = prefs.getString(k);
      if (v != null) out[k] = v;
    }
    for (final k in _userStringListKeys) {
      final v = prefs.getStringList(k);
      if (v != null) out[k] = v;
    }
    for (final k in _userBoolKeys) {
      if (prefs.containsKey(k)) out[k] = prefs.getBool(k);
    }
    return out;
  }

  /// Writes a cloud snapshot back into prefs, then repopulates the in-memory
  /// globals via [loadInto]. Used when a signed-in user's cloud data is pulled.
  Future<void> importUserData(Map<String, dynamic> data) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      for (final entry in data.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v == null) continue;
        if (_userStringListKeys.contains(k) && v is List) {
          await prefs.setStringList(k, v.map((e) => e.toString()).toList());
        } else if (_userBoolKeys.contains(k) && v is bool) {
          await prefs.setBool(k, v);
        } else if (v is String) {
          await prefs.setString(k, v);
        }
      }
      loadInto();
    } catch (e) {
      debugPrint('StorageService.importUserData failed: $e');
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
    _triggerCloud();
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
    _triggerCloud();
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
      await prefs.setString(_kCartUnits, jsonEncode(globalCartUnits));
      await prefs.setStringList(_kCartChecked, globalCartChecked.toList());
      await prefs.setStringList(_kFavoriteRecipes, globalFavoriteRecipes.toList());
      await prefs.setString(_kRecipeViews, jsonEncode(globalRecipeViews));
      await prefs.setString(_kRecipeComments, jsonEncode(globalRecipeComments));
      await prefs.setString(_kRecipeTriedPhotos, jsonEncode(globalRecipeTriedPhotos));
      await prefs.setStringList(_kRecipeTried, globalRecipeTried.toList());
      await prefs.setString(_kRecipeRatings, jsonEncode(globalRecipeMyRating));
      await prefs.setString(_kPendingRecipes, jsonEncode(globalPendingRecipes));
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
      await prefs.setStringList(_kUserFormulaNames, globalUserFormulaNames);
      await prefs.setString(_kGrowth, jsonEncode(globalGrowthRecords));
      await prefs.setString(_kMilestones, jsonEncode(globalMilestonesDone.map((k, v) => MapEntry(k, v.toList()))));
      await prefs.setBool(_kPremium, globalIsPremium);
      if (globalTrialStart != null) await prefs.setString(_kTrialStart, globalTrialStart!);
      if (globalPremiumUntil != null) {
        await prefs.setString(_kPremiumUntil, globalPremiumUntil!);
      } else {
        await prefs.remove(_kPremiumUntil);
      }
      if (globalAdFreeUntil != null) {
        await prefs.setString(_kAdFreeUntil, globalAdFreeUntil!);
      } else {
        await prefs.remove(_kAdFreeUntil);
      }
      await prefs.setString(_kFeatureUnlocks, jsonEncode(globalFeatureUnlocks));
    } catch (e) {
      debugPrint('StorageService.saveAll failed: $e');
    }
    _triggerCloud();
  }

  /// Persists just the premium/trial/ad-free flags (used by the BabyBites+ and
  /// rewarded-ad flows, which don't have the baby list handy). Syncs to cloud.
  Future<void> saveExtras() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setBool(_kPremium, globalIsPremium);
      if (globalTrialStart != null) {
        await prefs.setString(_kTrialStart, globalTrialStart!);
      } else {
        await prefs.remove(_kTrialStart);
      }
      if (globalPremiumUntil != null) {
        await prefs.setString(_kPremiumUntil, globalPremiumUntil!);
      } else {
        await prefs.remove(_kPremiumUntil);
      }
      if (globalAdFreeUntil != null) {
        await prefs.setString(_kAdFreeUntil, globalAdFreeUntil!);
      } else {
        await prefs.remove(_kAdFreeUntil);
      }
    } catch (e) {
      debugPrint('StorageService.saveExtras failed: $e');
    }
    _triggerCloud();
  }

  /// Persists uploaded report documents (e-Nabız PDFs etc.). Local-only for now
  /// (files are large; they move to Firebase Storage in Faz 4).
  Future<void> saveReportFiles() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kReportFiles, jsonEncode(globalReportFiles));
    } catch (e) {
      debugPrint('StorageService.saveReportFiles failed: $e');
    }
  }

  /// Clears this device's LOCAL copy of the user's private data (on sign-out)
  /// so a different account signing in on the same device can't inherit it.
  /// Cloud data is untouched — a returning user gets it back via [importUserData].
  Future<void> clearUserData() async {
    final prefs = _prefs;
    if (prefs != null) {
      try {
        for (final k in [..._userStringKeys, ..._userStringListKeys, ..._userBoolKeys]) {
          await prefs.remove(k);
        }
      } catch (e) {
        debugPrint('StorageService.clearUserData (prefs) failed: $e');
      }
    }
    // Reset in-memory globals so nothing leaks into the next session.
    globalWeeklyPlan.clear();
    globalCartList.clear();
    globalCartQuantities.clear();
    globalCartUnits.clear();
    globalCartChecked.clear();
    globalFavoriteRecipes.clear();
    globalRecipeTried.clear();
    globalRecipeMyRating.clear();
    globalGrowthRecords.clear();
    globalMilestonesDone.clear();
    globalIsPremium = false;
    globalTrialStart = null;
    globalPremiumUntil = null;
    globalAdFreeUntil = null;
    globalFeatureUnlocks.clear();
    for (final f in globalFoodsDatabase) {
      f.tried = false;
      f.isFavorite = false;
    }
    globalBabyFoodStates.clear();
    globalReminders.clear();
    globalBabyMeds.clear();
    globalDailyLogs.clear();
    globalUserFormulaNames.clear();
    globalMyProfile = null;
  }
}
