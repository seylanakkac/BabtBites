import 'package:flutter/material.dart';
import '../data/admin_store.dart';
import '../data/food_database.dart';
import '../data/tracking_store.dart';
import '../services/storage_service.dart';
import '../widgets/image_helpers.dart';
import 'articles_screen.dart';
import 'food_detail_screen.dart';
import 'recipe_detail_screen.dart';

// Shared globals used across screens.
final Map<String, int> globalCartQuantities = {};

// Weekly meal plan: dateKey(yyyy-MM-dd) -> mealSlot -> list of food/recipe names.
final Map<String, Map<String, List<String>>> globalWeeklyPlan = {};

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);
const _danger = Color(0xFFFF4D6A);

const List<String> _mealSlots = [
  "Kahvaltı",
  "Öğle Yemeği",
  "Akşam Yemeği",
  "1. Ara Öğün",
  "2. Ara Öğün",
  "3. Ara Öğün",
];

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialBabies;
  const HomeScreen({super.key, this.initialBabies});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late List<Map<String, dynamic>> _babies;
  Map<String, dynamic>? _activeBaby;
  Map<String, String>? _parent;

  final _searchController = TextEditingController();
  String _searchQuery = "";
  final _recipeSearchController = TextEditingController();
  String _recipeSearchQuery = "";
  String _selectedCategory = "Tümü";
  String _selectedRecipeAge = "Tümü";
  int _explorerSubTab = 0;
  bool _onlyTriedRecipes = false;
  final Set<String> _pantry = {};
  final Set<String> _favoriteRecipes = {};

  final _cartInputController = TextEditingController();

  DateTime _focusedDate = DateTime.now();
  late String _selectedDay;
  late Map<String, Map<String, List<String>>> _weeklyPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _formatDateKey(DateTime.now());

    Map<String, dynamic> defaultBaby() => {
          "name": "Asya",
          "gender": "Kız",
          "dob": "12.10.2025",
          "avatar": "👧",
          "weight": 8.4,
          "height": 68.0,
        };

    final provided = widget.initialBabies;
    final source = (provided != null && provided.isNotEmpty)
        ? provided
        : (StorageService.instance.loadBabies() ?? [defaultBaby()]);
    _babies = List<Map<String, dynamic>>.from(source);
    if (_babies.isEmpty) _babies.add(defaultBaby());

    _ensureBabyIds();
    _activeBaby = _babies.first;
    StorageService.instance.saveBabies(_babies);
    _parent = StorageService.instance.loadParent();

    _migrateLegacyFoodStates();
    _syncGlobalFlagsToActiveBaby();

    // Seed configured default supplements for the first baby on first run.
    if (globalBabyMeds.isEmpty) {
      final firstId = _babies.first["babyId"] as String;
      final base = DateTime.now().millisecondsSinceEpoch;
      final seeds = defaultSupplements;
      for (var i = 0; i < seeds.length; i++) {
        final s = Map<String, dynamic>.from(seeds[i]);
        s["id"] = "m_${base}_$i";
        s.putIfAbsent("type", () => "takviye");
        s.putIfAbsent("active", () => true);
        medsFor(firstId).add(s);
      }
    }

    _weeklyPlan = globalWeeklyPlan;
  }

  @override
  void dispose() {
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _recipeSearchController.dispose();
    _cartInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _persist();
    }
  }

  void _persist() => StorageService.instance.saveAll(_babies);

  String get _activeBabyId => (_activeBaby?["babyId"] as String?) ?? "";

  void _ensureBabyIds() {
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < _babies.length; i++) {
      final id = _babies[i]["babyId"];
      if (id == null || (id is String && id.isEmpty)) {
        _babies[i]["babyId"] = "b_${base}_$i";
      }
    }
  }

  void _migrateLegacyFoodStates() {
    if (globalBabyFoodStates.isNotEmpty) return;
    final firstId = _babies.first["babyId"] as String;
    for (final food in globalFoodsDatabase) {
      if (food.tried || food.isFavorite) {
        final st = ensureFoodState(firstId, food.name);
        st["tried"] = food.tried;
        st["favorite"] = food.isFavorite;
      }
    }
  }

  void _syncGlobalFlagsToActiveBaby() {
    final id = _activeBabyId;
    for (final food in globalFoodsDatabase) {
      final st = readFoodState(id, food.name);
      food.tried = st?["tried"] == true;
      food.isFavorite = st?["favorite"] == true;
    }
  }

  void _setActiveBaby(Map<String, dynamic> baby) {
    setState(() {
      _activeBaby = baby;
      _syncGlobalFlagsToActiveBaby();
    });
    _persist();
  }

  // ---------- date / age helpers ----------
  String _formatDateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String _todayKey() => _formatDateKey(DateTime.now());

  DateTime? _parseDob(String? dob) {
    if (dob == null || !dob.contains(".")) return null;
    final p = dob.split(".");
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  int _ageMonths(String? dob) {
    final d = _parseDob(dob);
    if (d == null) return 0;
    return (DateTime.now().difference(d).inDays / 30.4).floor();
  }

  String _calculateAge(String? dob) {
    final d = _parseDob(dob);
    if (d == null) return "Yaş bilinmiyor";
    final diff = DateTime.now().difference(d).inDays;
    final months = (diff / 30.4).floor();
    if (months < 1) {
      final w = (diff / 7).floor();
      return w < 1 ? "$diff Günlük" : "$w Haftalık";
    }
    return "$months Aylık";
  }

  String _formatIsoTr(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    const months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    final m = int.tryParse(p[1]) ?? 1;
    return "${int.parse(p[2])} ${months[(m - 1).clamp(0, 11)]} ${p[0]}";
  }

  List<Map<String, String>> _getWeeklyDays() {
    final monday = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
    const dayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      return {"dayName": dayNames[i], "dayNum": "${date.day}", "key": _formatDateKey(date)};
    });
  }

  Map<String, double> _calculateBabyTargets() {
    if (_activeBaby == null) {
      return {"Energy": 640.0, "Protein": 9.6, "Fat": 24.0, "Iron": 11.0, "Carb": 95.0};
    }
    final weight = (_activeBaby!["weight"] is num)
        ? (_activeBaby!["weight"] as num).toDouble()
        : double.tryParse(_activeBaby!["weight"]?.toString() ?? "") ?? 8.0;
    final months = _ageMonths(_activeBaby!["dob"]?.toString());
    final prefix = months < 12 ? "infant" : "toddler";
    final energy = weight * ntv("${prefix}EnergyPerKg");
    final protein = weight * ntv("${prefix}ProteinPerKg");
    final fat = weight * ntv("${prefix}FatPerKg");
    final iron = ntv("${prefix}Iron");
    return {
      "Energy": energy.clamp(ntv("energyMin"), ntv("energyMax")),
      "Protein": protein.clamp(ntv("proteinMin"), ntv("proteinMax")),
      "Fat": fat.clamp(ntv("fatMin"), ntv("fatMax")),
      "Iron": iron,
      "Carb": months < 12 ? 95.0 : 130.0,
    };
  }

  Map<String, double> _calculatePlannedNutrition() {
    final result = {"Energy": 0.0, "Protein": 0.0, "Fat": 0.0, "Iron": 0.0, "Carb": 0.0};
    final day = _weeklyPlan[_selectedDay];
    if (day == null) return result;
    void add(Map<String, double> n) {
      result["Energy"] = result["Energy"]! + (n["Enerji"] ?? 0);
      result["Protein"] = result["Protein"]! + (n["Protein"] ?? 0);
      result["Fat"] = result["Fat"]! + (n["Yağ"] ?? 0);
      result["Iron"] = result["Iron"]! + (n["Demir"] ?? 0);
      result["Carb"] = result["Carb"]! + (n["Karbonhidrat"] ?? 0);
    }

    for (final items in day.values) {
      for (final name in items) {
        final food = globalFoodsDatabase.where((f) => f.name == name).toList();
        if (food.isNotEmpty) {
          add(nutritionForFood(food.first));
        } else {
          final recipe = globalRecipesDatabase.where((r) => r.name == name).toList();
          if (recipe.isNotEmpty) add(nutritionForRecipe(recipe.first));
        }
      }
    }
    return result;
  }

  Widget _getRecipeImage(Recipe recipe) {
    final name = recipe.name.toLowerCase();
    String path = "assets/images/puree_plate.png";
    if (name.contains("omlet")) {
      path = "assets/images/omelet_plate.png";
    } else if (name.contains("somon") || name.contains("balık") || name.contains("mezgit") || name.contains("levrek")) {
      path = "assets/images/salmon_plate.png";
    } else if (name.contains("lapa") || name.contains("muhallebi") || name.contains("yulaf")) {
      path = "assets/images/porridge_plate.png";
    }
    final asset = Image.asset(path, fit: BoxFit.cover);
    return isPhotoUrl(recipe.imageUrl)
        ? photoOrFallback(recipe.imageUrl, fallback: asset, fit: BoxFit.cover)
        : asset;
  }

  void _onChildChanged() {
    setState(() {});
    _persist();
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 1:
        body = _buildFoodsAndRecipesTab();
        break;
      case 2:
        body = _buildCalendarTab();
        break;
      case 3:
        body = _buildCartTab();
        break;
      case 4:
        body = _buildProfileTab();
        break;
      default:
        body = _buildHomeTab();
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _primary,
        unselectedItemColor: _light,
        selectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Ana Sayfa"),
          const BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), activeIcon: Icon(Icons.restaurant), label: "Gıdalar"),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: "Takvim"),
          BottomNavigationBarItem(
            icon: _cartIcon(false),
            activeIcon: _cartIcon(true),
            label: "Sepet",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  Widget _cartIcon(bool active) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (globalCartList.isNotEmpty)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: _danger, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text("${globalCartList.length}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text));

  // ====================== HOME TAB (Keşfet) ======================
  String _categoryEmoji(String cat) {
    switch (cat) {
      case "Sebze":
        return "🥦";
      case "Meyve":
        return "🍎";
      case "Tahıl":
        return "🌾";
      case "Et":
        return "🍗";
      case "Balık":
        return "🐟";
      case "Süt Ürünleri":
      case "Süt":
        return "🥛";
      case "Baklagil":
        return "🫘";
      case "Yumurta":
        return "🥚";
      default:
        return "🍽️";
    }
  }

  Widget _buildHomeTab() {
    final filteredFoods = globalFoodsDatabase.where((food) {
      final matchesSearch = food.name.toLowerCase().contains(_searchQuery);
      final matchesCat = _selectedCategory == "Tümü" || food.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
    final gridFoods = _searchQuery.isEmpty ? filteredFoods.take(6).toList() : filteredFoods;
    final todaysRecipes = globalRecipesDatabase.take(6).toList();
    final babyName = _activeBaby?["name"]?.toString() ?? "Bebeğin";

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // Header: logo + baby chip
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                "BabyBites",
                style: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.bold, color: _primary.withOpacity(0.35)),
              ),
            ),
            _babyChip(),
          ],
        ),
        const SizedBox(height: 20),
        // Search bar
        Container(
          decoration: BoxDecoration(color: const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: _text),
            decoration: const InputDecoration(
              hintText: "Gıda veya tarif ara...",
              hintStyle: TextStyle(color: _light, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: _light),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Gıdaları Keşfet header
        Row(
          children: [
            const Expanded(child: Text("Gıdaları Keşfet", style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: _text))),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: Text("Tümünü Gör", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _primary.withOpacity(0.55))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Category chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ["Tümü", ...foodCategories].map((cat) {
              final sel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(color: sel ? _primary : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        cat == "Tümü"
                            ? Icon(Icons.check, size: 16, color: sel ? Colors.white : _light)
                            : Text(_categoryEmoji(cat), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(cat, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: sel ? Colors.white : _text)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Food grid
        gridFoods.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text("Bu kategoride gıda yok.", textAlign: TextAlign.center, style: TextStyle(color: _light)))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.68, crossAxisSpacing: 14, mainAxisSpacing: 14),
                itemCount: gridFoods.length,
                itemBuilder: (context, index) => _homeFoodCard(gridFoods[index]),
              ),
        const SizedBox(height: 28),
        // Günün Tarifleri header
        Row(
          children: [
            const Expanded(child: Text("Günün Tarifleri", style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: _text))),
            GestureDetector(
              onTap: () => setState(() { _currentIndex = 1; _explorerSubTab = 1; }),
              child: Text("Daha Fazla", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _primary.withOpacity(0.55))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: todaysRecipes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _homeRecipeCard(todaysRecipes[index]),
          ),
        ),
        const SizedBox(height: 28),
        // Beslenme Rehberi
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArticlesScreen())),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF2BB673).withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2BB673).withOpacity(0.25))),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Color(0xFF2BB673), shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Beslenme Rehberi", style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
                      SizedBox(height: 4),
                      Text("Ek gıdaya geçiş, alerji, BLW ve uzman yazıları.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF2BB673)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Haftalık Menü banner
        GestureDetector(
          onTap: _openWeeklyMenu,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _primary.withOpacity(0.65), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Haftalık Menü Hazır!", style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("$babyName için bu haftanın besleyici planına göz at.", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _homeFoodCard(Food food) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FoodDetailScreen(food: food, babyId: _activeBabyId, onStateChanged: _onChildChanged),
      )),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            if (food.tried)
              const Positioned(top: 10, right: 10, child: Icon(Icons.check_circle, color: _green, size: 20)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isPhotoUrl(food.imageUrl)
                      ? ClipOval(child: SizedBox(width: 48, height: 48, child: photoOrFallback(food.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)))
                      : Text(food.emoji, style: const TextStyle(fontSize: 38, height: 1.1)),
                  const SizedBox(height: 10),
                  Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text("${food.startingMonth}+ Ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _text)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeRecipeCard(Recipe recipe) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe, onStateChanged: _onChildChanged),
      )),
      child: Container(
        width: 230,
        decoration: BoxDecoration(color: const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(width: double.infinity, height: 150, child: _getRecipeImage(recipe)),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: _primary),
                        const SizedBox(width: 4),
                        Text(recipe.prepTime, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Text("${recipe.startingMonth}+ Ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                      ),
                      const SizedBox(width: 8),
                      Text("• ${recipe.kcal.toInt()} kcal", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== WEEKLY MENU PAGE (banner'dan açılır) ======================
  void _openWeeklyMenu() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final weekDays = _getWeeklyDays();
          final monday = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
          final sunday = monday.add(const Duration(days: 6));
          const monthsTr = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
          final rangeText = "${monday.day} – ${sunday.day} ${monthsTr[sunday.month - 1]}";
          final targets = _calculateBabyTargets();
          final planned = _calculatePlannedNutrition();
          void refresh() => setLocal(() {});
          return Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: _bg,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(ctx)),
              title: const Text("Haftalık Menü", style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
              centerTitle: true,
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left, color: _primary, size: 22), onPressed: () => setLocal(() => _focusedDate = _focusedDate.subtract(const Duration(days: 7)))),
                        Text(rangeText, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                        IconButton(icon: const Icon(Icons.chevron_right, color: _primary, size: 22), onPressed: () => setLocal(() => _focusedDate = _focusedDate.add(const Duration(days: 7)))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: Row(
                    children: weekDays.map((d) {
                      final sel = d["key"] == _selectedDay;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setLocal(() => _selectedDay = d["key"]!),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: sel ? _primary : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6).withOpacity(0.6))),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(d["dayName"]!, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: sel ? Colors.white70 : _light)),
                                const SizedBox(height: 2),
                                Text(d["dayNum"]!, style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: sel ? Colors.white : _text)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                ..._mealSlots.expand((slot) {
                  final items = _weeklyPlan[_selectedDay]?[slot] ?? [];
                  return [
                    if (items.isEmpty) _emptyMealCard(slot, onChanged: refresh) else ...items.map((name) => _mealCard(slot, name, onChanged: refresh)),
                    const SizedBox(height: 12),
                  ];
                }),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.07), borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(child: Text("Günlük Besin Özeti", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _danger))),
                          Icon(Icons.auto_graph, color: _danger, size: 20),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _nutrientBar("Protein", planned["Protein"]!, targets["Protein"]!, _danger),
                      const SizedBox(height: 12),
                      _nutrientBar("Demir", planned["Iron"]!, targets["Iron"]!, _primary),
                      const SizedBox(height: 12),
                      _nutrientBar("Kalori", planned["Energy"]!, targets["Energy"]!, _green),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addWeekIngredientsToCart,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text("Haftalık Malzemeleri Sepete Ekle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    }));
  }

  Widget _babyChip() {
    final name = _activeBaby?["name"]?.toString() ?? "";
    return GestureDetector(
      onTap: _showBabyPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 14, backgroundColor: _primary, child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: _light),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  void _showBabyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text("Bebek Seç", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 8),
            ..._babies.map((b) {
              final active = _activeBaby == b;
              return ListTile(
                leading: Text(b["avatar"] ?? "👶", style: const TextStyle(fontSize: 26)),
                title: Text(b["name"] ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: _text)),
                trailing: active ? const Icon(Icons.check_circle, color: _green) : null,
                onTap: () { _setActiveBaby(b); Navigator.pop(ctx); },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _emptyMealCard(String slot, {VoidCallback? onChanged}) {
    return GestureDetector(
      onTap: () => _showAddMealItemDialog(slot, onChanged: onChanged),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6), width: 1.4)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: _primary, size: 20),
            const SizedBox(width: 8),
            Text("$slot Ekle", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _light, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _mealCard(String slot, String name, {VoidCallback? onChanged}) {
    final recipeMatch = globalRecipesDatabase.where((r) => r.name == name).toList();
    final foodMatch = globalFoodsDatabase.where((f) => f.name == name).toList();
    final isRecipe = recipeMatch.isNotEmpty;
    final prep = isRecipe ? recipeMatch.first.prepTime : "";
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: isRecipe
                  ? _getRecipeImage(recipeMatch.first)
                  : (foodMatch.isNotEmpty && isPhotoUrl(foodMatch.first.imageUrl)
                      ? photoOrFallback(foodMatch.first.imageUrl, fallback: const SizedBox())
                      : Container(color: _bg, child: Center(child: Text(foodMatch.isNotEmpty ? foodMatch.first.emoji : "🍽️", style: const TextStyle(fontSize: 26))))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.toUpperCase(), style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                if (prep.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.access_time, size: 13, color: _light), const SizedBox(width: 4), Text(prep, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))]),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _light),
            onSelected: (v) {
              if (v == "open" && isRecipe) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipeMatch.first, onStateChanged: _onChildChanged)));
              } else if (v == "remove") {
                _weeklyPlan[_selectedDay]?[slot]?.remove(name);
                _persist();
                setState(() {});
                onChanged?.call();
              }
            },
            itemBuilder: (_) => [
              if (isRecipe) const PopupMenuItem(value: "open", child: Text("Tarifi Aç")),
              const PopupMenuItem(value: "remove", child: Text("Kaldır")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutrientBar(String label, double current, double target, Color color) {
    final pct = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white, valueColor: AlwaysStoppedAnimation(color)),
        ),
      ],
    );
  }

  void _addWeekIngredientsToCart() {
    final week = _getWeeklyDays().map((d) => d["key"]!).toSet();
    int added = 0;
    for (final dayKey in week) {
      final day = _weeklyPlan[dayKey];
      if (day == null) continue;
      for (final items in day.values) {
        for (final name in items) {
          final recipe = globalRecipesDatabase.where((r) => r.name == name).toList();
          final ings = recipe.isNotEmpty ? recipe.first.ingredients : [name];
          for (final ing in ings) {
            if (!globalCartList.contains(ing)) {
              globalCartList.add(ing);
              globalCartQuantities[ing] = 1;
              added++;
            }
          }
        }
      }
    }
    _persist();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added > 0 ? "$added malzeme sepete eklendi." : "Eklenecek yeni malzeme yok.")));
  }

  // ---------- food/recipe card styling helpers ----------
  /// A soft pastel tint based on the food's natural colour (by name / category).
  Color _foodTint(Food f) {
    final n = f.name.toLowerCase();
    bool has(List<String> k) => k.any((s) => n.contains(s));
    if (has(["brokoli", "ıspanak", "bezelye", "enginar", "kabak", "salatalık", "yeşil", "avokado", "brüksel", "pırasa", "marul", "dereotu", "maydanoz", "fasulye", "semizotu", "lahana"])) return const Color(0xFFE8F5E9);
    if (has(["havuç", "balkabağı", "tatlı patates", "kayısı", "şeftali", "mango", "portakal", "mandalina", "kavun"])) return const Color(0xFFFFEFE0);
    if (has(["muz", "mısır", "ananas", "armut", "limon"])) return const Color(0xFFFFF8E1);
    if (has(["balık", "somon", "levrek", "mezgit", "hamsi", "uskumru", "ton", "yengeç"])) return const Color(0xFFE3F2FD);
    if (has(["elma", "çilek", "domates", "kiraz", "vişne", "nar", "karpuz", "frenk", "ahududu", "pancar", "böğürtlen"])) return const Color(0xFFFFEBEE);
    if (has(["tavuk", "köfte", "hindi", "dana", "kuzu", "ciğer", "kırmızı et", "biftek"])) return const Color(0xFFFCE4EC);
    if (has(["yumurta", "yoğurt", "peynir", "süt", "kaymak", "kefir"])) return const Color(0xFFFFF8E7);
    if (has(["yulaf", "pirinç", "bulgur", "ekmek", "makarna", "un", "tahıl", "kinoa", "mercimek", "nohut", "fasulyesi", "irmik"])) return const Color(0xFFF3E8FB);
    switch (f.category) {
      case "Sebze":
        return const Color(0xFFE8F5E9);
      case "Meyve":
        return const Color(0xFFFFEBEE);
      case "Tahıl":
        return const Color(0xFFF3E8FB);
      case "Et":
      case "Balık":
        return const Color(0xFFFCE4EC);
    }
    return const Color(0xFFF3F3F5);
  }

  /// A short serving-style hint derived from the food's presentation styles.
  String _servingHint(Food f) {
    final t = f.presentationStyles.values.join(" ").toLowerCase();
    final tags = <String>[];
    void add(String label, List<String> keys) {
      if (tags.length < 2 && !tags.contains(label) && keys.any((k) => t.contains(k))) tags.add(label);
    }

    add("Püre", ["püre"]);
    add("Ezilmiş", ["ez"]);
    add("Haşlanmış", ["haşla"]);
    add("Parmak", ["parmak"]);
    add("İnce Kıyılmış", ["kıyı", "kıyma", "doğra"]);
    add("Rende", ["rende"]);
    add("Lapa", ["lapa"]);
    add("Küçük Parça", ["parça", "küp"]);
    add("Dilim", ["dilim"]);
    if (tags.isEmpty) return f.category;
    return tags.take(2).join("/");
  }

  Widget _agePill(int month) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF1E9E5C), borderRadius: BorderRadius.circular(10)),
        child: Text("$month+", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _explorerFoodCard(Food food) {
    final allergen = food.allergyRisk != "Düşük";
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FoodDetailScreen(food: food, babyId: _activeBabyId, onStateChanged: _onChildChanged),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _foodTint(food), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (food.tried) const Positioned(top: 0, right: 0, child: Icon(Icons.check_circle, color: _green, size: 18)),
                  Center(
                    child: isPhotoUrl(food.imageUrl)
                        ? ClipOval(child: SizedBox(width: 52, height: 52, child: photoOrFallback(food.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)))
                        : Text(food.emoji, style: const TextStyle(fontSize: 46)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                      const SizedBox(height: 2),
                      Text(_servingHint(food), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF8E8E9F))),
                      if (allergen) ...[
                        const SizedBox(height: 3),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFE8A23D)),
                            SizedBox(width: 3),
                            Text("Alerjen", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE8A23D))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _agePill(food.startingMonth),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _recipeTint(Recipe r) {
    for (final ing in r.ingredients) {
      final m = globalFoodsDatabase.where((f) => f.name.toLowerCase() == ing.toLowerCase()).toList();
      if (m.isNotEmpty) return _foodTint(m.first);
    }
    return const Color(0xFFFFF0E6);
  }

  void _addRecipeToCart(Recipe r) {
    int added = 0;
    setState(() {
      for (final ing in r.ingredients) {
        if (!globalCartList.contains(ing)) {
          globalCartList.add(ing);
          globalCartQuantities[ing] = 1;
          added++;
        }
      }
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added > 0 ? "$added malzeme sepete eklendi." : "Malzemeler zaten sepette."), duration: const Duration(seconds: 1)));
  }

  Widget _recipeListItem(Recipe recipe) {
    final desc = recipe.steps.isNotEmpty ? recipe.steps.first : recipe.allergyWarning;
    final fav = _favoriteRecipes.contains(recipe.id);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipe: recipe, onStateChanged: _onChildChanged),
        )),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: _recipeTint(recipe), borderRadius: BorderRadius.circular(16)),
                child: _getRecipeImage(recipe),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _danger.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                          child: Text("${recipe.startingMonth}+ Ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _danger)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF7A5CFF).withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                          child: Text(recipe.prepTime, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7A5CFF))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(recipe.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                    const SizedBox(height: 4),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF8E8E9F), height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _addRecipeToCart(recipe),
                    child: const Icon(Icons.add_shopping_cart, color: _primary, size: 20),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => setState(() => fav ? _favoriteRecipes.remove(recipe.id) : _favoriteRecipes.add(recipe.id)),
                    child: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? _danger : _light, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== FOODS & RECIPES TAB ======================
  Widget _buildFoodsAndRecipesTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(child: Text("Gıda Dene", style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: _text))),
            ],
          ),
        ),
        // Sub-tab switcher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
            child: Row(
              children: [
                _subTab("Gıdalar", 0),
                _subTab("Tarifler", 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _explorerSubTab == 0 ? _buildFoodsExplorer() : _buildRecipesExplorer()),
      ],
    );
  }

  Widget _subTab(String label, int index) {
    final selected = _explorerSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _explorerSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? _primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: selected ? Colors.white : _light))),
        ),
      ),
    );
  }

  Widget _buildFoodsExplorer() {
    final filteredFoods = globalFoodsDatabase.where((food) {
      final matchesSearch = food.name.toLowerCase().contains(_searchQuery);
      final matchesCat = _selectedCategory == "Tümü" || food.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildSearchBar()),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: ["Tümü", ...foodCategories].map((cat) {
                final sel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: sel ? _primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6).withOpacity(0.8))),
                      child: Center(child: Text(cat, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : _text))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.82, crossAxisSpacing: 14, mainAxisSpacing: 14),
            itemCount: filteredFoods.length,
            itemBuilder: (context, index) => _explorerFoodCard(filteredFoods[index]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
        decoration: const InputDecoration(
          hintText: "Gıda ara...",
          hintStyle: TextStyle(color: _light, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: _light),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRecipesExplorer() {
    final triedNames = triedFoodNames(_activeBabyId);
    final filteredRecipes = globalRecipesDatabase.where((recipe) {
      final matchesSearch = recipe.name.toLowerCase().contains(_recipeSearchQuery);
      if (_onlyTriedRecipes && !recipe.ingredients.any((ing) => triedNames.contains(ing))) return false;
      if (_pantry.isNotEmpty && !recipe.ingredients.any((ing) => _pantry.contains(ing))) return false;
      if (_selectedRecipeAge == "Tümü") return matchesSearch;
      int maxAge = 6;
      if (_selectedRecipeAge == "8+ Ay") {
        maxAge = 8;
      } else if (_selectedRecipeAge == "9+ Ay") {
        maxAge = 9;
      } else if (_selectedRecipeAge == "12+ Ay") {
        maxAge = 12;
      }
      return matchesSearch && recipe.startingMonth <= maxAge;
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
        children: [
          const SizedBox(height: 4),
          _buildPantryCard(filteredRecipes.length),
          const SizedBox(height: 10),
          // Tried-foods toggle (right under the pantry feature)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 18, color: _green),
                  const SizedBox(width: 10),
                  const Expanded(child: Text("Sadece denediğim gıdaları içerenler", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
                  Switch(value: _onlyTriedRecipes, activeColor: _green, onChanged: (v) => setState(() => _onlyTriedRecipes = v)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
              child: TextField(
                controller: _recipeSearchController,
                onChanged: (v) => setState(() => _recipeSearchQuery = v.trim().toLowerCase()),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                decoration: const InputDecoration(
                  hintText: "Tarif ara...",
                  hintStyle: TextStyle(color: _light, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: _light),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: ["Tümü", "6+ Ay", "8+ Ay", "9+ Ay", "12+ Ay"].map((age) {
                final sel = _selectedRecipeAge == age;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRecipeAge = age),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: sel ? _primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6).withOpacity(0.8))),
                      child: Center(child: Text(age, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : _text))),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
          ),
        ),
        if (filteredRecipes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(32, 40, 32, 40), child: Text("Aradığınız kriterlere uygun tarif bulunamadı.", textAlign: TextAlign.center, style: TextStyle(color: _light))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _recipeListItem(filteredRecipes[index]),
                childCount: filteredRecipes.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildPantryCard(int matchCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _primary.withOpacity(0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text("Evdeki malzemelerle tarif bul 🧺", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
                if (_pantry.isNotEmpty)
                  GestureDetector(onTap: () => setState(() => _pantry.clear()), child: const Text("Temizle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _primary))),
              ],
            ),
            const SizedBox(height: 4),
            const Text("Evindeki malzemeleri seç, yapabileceğin tarifleri görelim.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._pantry.map((name) {
                  final matches = globalFoodsDatabase.where((f) => f.name == name).toList();
                  final emoji = matches.isNotEmpty ? matches.first.emoji : "🥕";
                  final photo = matches.isNotEmpty ? matches.first.imageUrl : "";
                  return Container(
                    padding: const EdgeInsets.only(left: 8, right: 6, top: 5, bottom: 5),
                    decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isPhotoUrl(photo) ? ClipOval(child: SizedBox(width: 20, height: 20, child: photoOrFallback(photo, fallback: const SizedBox(), fit: BoxFit.cover))) : Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
                        const SizedBox(width: 4),
                        GestureDetector(onTap: () => setState(() => _pantry.remove(name)), child: const Icon(Icons.close, size: 14, color: _light)),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _showPantryPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, size: 16, color: Colors.white), SizedBox(width: 4), Text("Malzeme Ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))]),
                  ),
                ),
              ],
            ),
            if (_pantry.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Bu malzemelerle $matchCount tarif bulundu", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _green)),
            ],
          ],
        ),
      ),
    );
  }

  void _showPantryPicker() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = searchCtrl.text.trim().toLowerCase();
          final foods = globalFoodsDatabase.where((f) => f.name.toLowerCase().contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: 480,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text("Malzeme Ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheet(() {}),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                      decoration: InputDecoration(
                        hintText: "Malzeme ara...",
                        prefixIcon: const Icon(Icons.search, color: _light),
                        filled: true,
                        fillColor: _bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: foods.length,
                      itemBuilder: (ctx, i) {
                        final f = foods[i];
                        final selected = _pantry.contains(f.name);
                        return ListTile(
                          leading: isPhotoUrl(f.imageUrl) ? ClipOval(child: SizedBox(width: 34, height: 34, child: photoOrFallback(f.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover))) : Text(f.emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(f.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
                          trailing: Icon(selected ? Icons.check_circle : Icons.add_circle_outline, color: selected ? _green : _light),
                          onTap: () {
                            setSheet(() => selected ? _pantry.remove(f.name) : _pantry.add(f.name));
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text("Tarifleri Göster (${_pantry.length} malzeme)", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => searchCtrl.dispose());
  }

  // ====================== CALENDAR TAB ======================
  DateTime _selectedDate() {
    final p = _selectedDay.split('-');
    if (p.length != 3) return DateTime.now();
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  void _shiftSelectedDay(int days) {
    final nd = _selectedDate().add(Duration(days: days));
    setState(() {
      _selectedDay = _formatDateKey(nd);
      _focusedDate = nd;
    });
  }

  Widget _buildCalendarTab() {
    final weekDays = _getWeeklyDays();
    final sel = _selectedDate();
    const monthsTr = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    final dateLabel = "${sel.day} ${monthsTr[sel.month - 1]} ${sel.year}";
    final targets = _calculateBabyTargets();
    final planned = _calculatePlannedNutrition();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Row(
          children: [
            Text("Takvim 📅", style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: _text)),
          ],
        ),
        const SizedBox(height: 16),
        // Date header with arrows
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: _primary, size: 26), onPressed: () => _shiftSelectedDay(-1)),
            Expanded(child: Center(child: Text(dateLabel, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)))),
            IconButton(icon: const Icon(Icons.chevron_right, color: _primary, size: 26), onPressed: () => _shiftSelectedDay(1)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: Row(
            children: weekDays.map((d) {
              final selDay = d["key"] == _selectedDay;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = d["key"]!),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: selDay ? _primary : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selDay ? Colors.transparent : const Color(0xFFE2E2E6).withOpacity(0.6))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(d["dayName"]!, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: selDay ? Colors.white70 : _light)),
                        const SizedBox(height: 2),
                        Text(d["dayNum"]!, style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: selDay ? Colors.white : _text)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        // Nutrition rings
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7))),
          child: Row(
            children: [
              _nutrientRing("Enerji", planned["Energy"]!, targets["Energy"]!, _primary),
              _nutrientRing("Protein", planned["Protein"]!, targets["Protein"]!, _danger),
              _nutrientRing("Yağ", planned["Fat"]!, targets["Fat"]!, _green),
              _nutrientRing("Karbonhidrat", planned["Carb"]!, targets["Carb"]!, const Color(0xFF3B9EDB)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...(() {
          final dayReminders = remindersForDay(_activeBabyId, _selectedDay);
          if (dayReminders.isEmpty) return <Widget>[];
          return <Widget>[
            _sectionTitle("Hatırlatmalar 🔔"),
            const SizedBox(height: 10),
            ...dayReminders.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _primary.withOpacity(0.2))),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat, color: _primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r["title"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text))),
                      TextButton(onPressed: () { setState(() => r["done"] = true); _persist(); }, child: const Text("Tamam", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _primary))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ];
        }()),
        // Öğün Planı
        _sectionTitle("Öğün Planı 🍽️"),
        const SizedBox(height: 12),
        ..._mealSlots.map(_planMealCard),
        const SizedBox(height: 8),
        _buildDailyTrackingSection(),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _nutrientRing(String label, double current, double target, Color color) {
    final pct = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(value: pct, strokeWidth: 5, backgroundColor: const Color(0xFFECECF0), valueColor: AlwaysStoppedAnimation(color)),
                ),
                Text("${(pct * 100).round()}%", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
        ],
      ),
    );
  }

  Widget _planMealCard(String slot) {
    final items = _weeklyPlan[_selectedDay]?[slot] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(slot, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text))),
              GestureDetector(
                onTap: () => _showAddMealItemDialog(slot),
                child: const Icon(Icons.add_circle_outline, color: _primary, size: 28),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((name) => Container(
                    padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD8D8DE))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () { _weeklyPlan[_selectedDay]?[slot]?.remove(name); _persist(); setState(() {}); },
                          child: const Icon(Icons.close, size: 16, color: _danger),
                        ),
                      ],
                    ),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddMealItemDialog(String slot, {VoidCallback? onChanged}) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = searchCtrl.text.trim().toLowerCase();
          final foods = globalFoodsDatabase.where((f) => f.name.toLowerCase().contains(q)).map((f) => {"name": f.name, "emoji": f.emoji, "img": f.imageUrl}).toList();
          final recipes = globalRecipesDatabase.where((r) => r.name.toLowerCase().contains(q)).map((r) => {"name": r.name, "emoji": "🍲", "img": ""}).toList();
          final all = [...foods, ...recipes];
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: 460,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Text("$slot — ekle", style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheet(() {}),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                      decoration: InputDecoration(hintText: "Gıda veya tarif ara...", prefixIcon: const Icon(Icons.search, color: _light), filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: all.length,
                      itemBuilder: (ctx, i) {
                        final item = all[i];
                        return ListTile(
                          leading: isPhotoUrl(item["img"]) ? ClipOval(child: SizedBox(width: 34, height: 34, child: photoOrFallback(item["img"], fallback: const SizedBox(), fit: BoxFit.cover))) : Text(item["emoji"]!, style: const TextStyle(fontSize: 22)),
                          title: Text(item["name"]!, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
                          trailing: const Icon(Icons.add_circle_outline, color: _primary),
                          onTap: () {
                            _weeklyPlan.putIfAbsent(_selectedDay, () => {for (final s in _mealSlots) s: <String>[]});
                            _weeklyPlan[_selectedDay]!.putIfAbsent(slot, () => <String>[]);
                            if (!_weeklyPlan[_selectedDay]![slot]!.contains(item["name"])) {
                              _weeklyPlan[_selectedDay]![slot]!.add(item["name"]!);
                            }
                            _persist();
                            setState(() {});
                            onChanged?.call();
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => searchCtrl.dispose());
  }

  // ---------- daily tracking (diaper / supplements / meds) ----------
  Widget _buildDailyTrackingSection() {
    final id = _activeBabyId;
    final log = dailyLog(id, _selectedDay);
    final meds = medsFor(id);
    final supplements = meds.where((m) => m["type"] == "takviye" && m["active"] == true).toList();
    final medications = meds.where((m) => m["type"] == "ilac" && m["active"] == true).toList();
    final taken = log["taken"] as Map;

    final cisList = log["cisList"] as List;
    final kakaList = log["kakaList"] as List;
    final suCount = log["su"] as int;
    const cisColor = Color(0xFF2980B9);
    const kakaColor = Color(0xFF8B5E3C);
    const suColor = _green;
    const cisOptions = [("koyu", "Koyu", Color(0xFF8C6D1F)), ("orta", "Orta", Color(0xFFCE9A1E)), ("açık", "Açık", Color(0xFFE3C04B))];
    const kakaOptions = ["Sulu", "Yumuşak", "Normal", "Katı"];

    Widget circleBtn(IconData icon, VoidCallback onTap, Color color) => GestureDetector(
          onTap: onTap,
          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.4))), child: Icon(icon, size: 16, color: color)),
        );

    Widget pickChip(String label, bool selected, Color color, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 6, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: selected ? color : color.withOpacity(0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? color : Colors.transparent)),
            child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : color)),
          ),
        );

    Widget entryRows(List entries, List<Widget> Function(Map) chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 5), child: SizedBox(width: 26, child: Text("${e.key + 1}.", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)))),
                    Expanded(child: Wrap(children: chips(e.value as Map))),
                  ],
                ),
              )).toList(),
        );

    Widget trackerCard({required String emoji, required String label, required Color color, required int count, required VoidCallback onMinus, required VoidCallback onPlus, String countSuffix = "", Widget? details}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.30))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text))),
                circleBtn(Icons.remove, onMinus, color),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("$count$countSuffix", style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: color))),
                circleBtn(Icons.add, onPlus, color),
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: color.withOpacity(0.15)),
              const SizedBox(height: 10),
              details,
            ],
          ],
        ),
      );
    }

    Widget medTile(Map<String, dynamic> m) {
      final mid = m["id"] as String;
      final isTaken = taken[mid] == true;
      final isMed = m["type"] == "ilac";
      final subtitle = [m["dose"], m["schedule"]].where((x) => x != null && x.toString().isNotEmpty).join(" • ");
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
        child: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: (isMed ? _danger : _primary).withOpacity(0.12), shape: BoxShape.circle), child: Icon(isMed ? Icons.medication_outlined : Icons.wb_sunny_outlined, color: isMed ? _danger : _primary, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m["name"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                  if (subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))],
                ],
              ),
            ),
            Checkbox(value: isTaken, activeColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), onChanged: (v) { setState(() => taken[mid] = v ?? false); _persist(); }),
          ],
        ),
      );
    }

    Widget emptyHint(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))), child: Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Bez Takibi 🧷"),
        const SizedBox(height: 10),
        trackerCard(
          emoji: "💧", label: "Çiş Takibi", color: cisColor, count: cisList.length,
          onMinus: () { if (cisList.isNotEmpty) { setState(() => cisList.removeLast()); _persist(); } },
          onPlus: () { setState(() => cisList.add({"color": "orta"})); _persist(); },
          details: cisList.isEmpty ? null : entryRows(cisList, (entry) => cisOptions.map((o) => pickChip(o.$2, entry["color"] == o.$1, o.$3, () { setState(() => entry["color"] = o.$1); _persist(); })).toList()),
        ),
        trackerCard(
          emoji: "💩", label: "Kaka Takibi", color: kakaColor, count: kakaList.length,
          onMinus: () { if (kakaList.isNotEmpty) { setState(() => kakaList.removeLast()); _persist(); } },
          onPlus: () { setState(() => kakaList.add({"consistency": "Normal"})); _persist(); },
          details: kakaList.isEmpty ? null : entryRows(kakaList, (entry) => kakaOptions.map((c) => pickChip(c, entry["consistency"] == c, kakaColor, () { setState(() => entry["consistency"] = c); _persist(); })).toList()),
        ),
        trackerCard(
          emoji: "🥤", label: "Su Takibi", color: suColor, count: suCount, countSuffix: " bardak",
          onMinus: () { if (suCount > 0) { setState(() => log["su"] = suCount - 1); _persist(); } },
          onPlus: () { setState(() => log["su"] = suCount + 1); _persist(); },
        ),
        const SizedBox(height: 18),
        _sectionTitle("Takviyeler ☀️"),
        const SizedBox(height: 10),
        if (supplements.isEmpty) emptyHint("Henüz takviye yok. 'Yönet' ile ekleyin.") else ...supplements.map(medTile),
        const SizedBox(height: 18),
        _sectionTitle("İlaçlar 💊"),
        const SizedBox(height: 10),
        if (medications.isEmpty) emptyHint("Henüz ilaç yok. 'Yönet' ile ekleyin.") else ...medications.map(medTile),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showManageMedsDialog,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text("Takviye / İlaç Yönet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  void _showManageMedsDialog() {
    final id = _activeBabyId;
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) {
          final meds = medsFor(id);
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Takviye / İlaç Yönetimi", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meds.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Henüz kayıt yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)))
                  else Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: meds.map((m) {
                          final isMed = m["type"] == "ilac";
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(isMed ? Icons.medication_outlined : Icons.wb_sunny_outlined, size: 18, color: isMed ? _danger : _primary),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m["name"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text)), Text(isMed ? "İlaç" : "Takviye", style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: _light))])),
                                IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: _primary), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), onPressed: () => _showAddEditMedDialog(existing: m, onDone: () => setD(() {}))),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: _danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), onPressed: () { meds.remove(m); _persist(); setD(() {}); setState(() {}); }),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddEditMedDialog(existing: null, onDone: () => setD(() {})),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Yeni Ekle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("Kapat", style: TextStyle(fontFamily: 'Inter', color: _light)))],
          );
        },
      ),
    ).then((_) => setState(() {}));
  }

  void _showAddEditMedDialog({Map<String, dynamic>? existing, VoidCallback? onDone}) {
    final id = _activeBabyId;
    final names = supplementNameOptions;
    final units = doseUnitOptions;

    String type = existing?["type"]?.toString() ?? "takviye";
    final existingName = existing?["name"]?.toString();
    bool customName = existingName != null && existingName.isNotEmpty && !names.contains(existingName);
    String? selectedName = (existingName != null && names.contains(existingName)) ? existingName : null;
    final nameC = TextEditingController(text: customName ? existingName : "");
    final doseC = TextEditingController(text: existing?["doseAmount"]?.toString() ?? "");
    String unit = existing?["doseUnit"]?.toString() ?? (units.isNotEmpty ? units.first : "damla");
    if (units.isNotEmpty && !units.contains(unit)) unit = units.first;
    String frequency = existing?["frequency"]?.toString() ?? "Günlük";
    final times = <String>{...((existing?["times"] as List?)?.map((e) => e.toString()) ?? const ["Sabah"])};
    bool reminder = (existing?["reminder"] as bool?) ?? true;

    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) {
          Widget label(String t) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text))),
              );

          Widget choiceChip(String text, bool sel, VoidCallback onTap) => GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: sel ? _primary : _bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6))),
                  child: Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : _text)),
                ),
              );

          return AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(existing == null ? "Yeni Takviye Ekle" : "Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17, color: _text)),
            content: SizedBox(
              width: 260,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      choiceChip("Takviye", type == "takviye", () => setD(() => type = "takviye")),
                      choiceChip("İlaç", type == "ilac", () => setD(() => type = "ilac")),
                    ]),
                    // Name
                    label("Takviye / İlaç Adı"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: customName ? "__new__" : selectedName,
                          hint: const Text("Seçiniz...", style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _light)),
                          items: [
                            ...names.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)))),
                            const DropdownMenuItem(value: "__new__", child: Text("➕ Yeni ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _primary))),
                          ],
                          onChanged: (v) => setD(() {
                            if (v == "__new__") {
                              customName = true;
                              selectedName = null;
                            } else {
                              customName = false;
                              selectedName = v;
                            }
                          }),
                        ),
                      ),
                    ),
                    if (customName) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameC,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                        decoration: InputDecoration(hintText: "Yeni ad girin", hintStyle: const TextStyle(color: _light, fontSize: 14), isDense: true, filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      ),
                    ],
                    // Dose amount + unit
                    label("Doz Miktarı"),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: doseC,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                          decoration: InputDecoration(hintText: "0", hintStyle: const TextStyle(color: _light, fontSize: 14), isDense: true, filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: units.contains(unit) ? unit : null,
                              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)))).toList(),
                              onChanged: (v) => setD(() => unit = v ?? unit),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    // Frequency
                    label("Sıklık"),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final f in const ["Günlük", "Haftalık", "Aylık"]) choiceChip(f, frequency == f, () => setD(() => frequency = f)),
                    ]),
                    // Time of day (multi)
                    label("Veriliş Zamanı"),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in const ["Sabah", "Öğle", "Akşam"]) choiceChip(t, times.contains(t), () => setD(() => times.contains(t) ? times.remove(t) : times.add(t))),
                    ]),
                    const SizedBox(height: 18),
                    // Reminder
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.notifications_active_outlined, size: 20, color: _primary),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("Hatırlatıcı", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text))),
                        Switch(value: reminder, activeColor: _primary, onChanged: (v) => setD(() => reminder = v)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
              ElevatedButton(
                onPressed: () {
                  final finalName = customName ? nameC.text.trim() : (selectedName ?? "");
                  if (finalName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir ad seçin veya girin.")));
                    return;
                  }
                  final amount = doseC.text.trim();
                  final doseStr = amount.isNotEmpty ? "$amount $unit" : "";
                  final scheduleStr = [frequency, if (times.isNotEmpty) times.join("/")].join(" · ");
                  final data = <String, dynamic>{
                    "name": finalName,
                    "type": type,
                    "doseAmount": amount,
                    "doseUnit": unit,
                    "frequency": frequency,
                    "times": times.toList(),
                    "reminder": reminder,
                    "dose": doseStr,
                    "schedule": scheduleStr,
                    "active": true,
                  };
                  if (existing != null) {
                    existing.addAll(data);
                  } else {
                    data["id"] = "m_${DateTime.now().millisecondsSinceEpoch}";
                    medsFor(id).add(data);
                  }
                  _persist();
                  Navigator.pop(dctx);
                  onDone?.call();
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).then((_) { nameC.dispose(); doseC.dispose(); });
  }

  // ====================== CART TAB ======================
  Widget _buildCartTab() {
    return Column(
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(24, 16, 24, 8), child: Align(alignment: Alignment.centerLeft, child: Text("Alışveriş Sepeti 🛒", style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: _text)))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: _cartInputController,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
            decoration: InputDecoration(hintText: "Yeni ürün ekle...", prefixIcon: const Icon(Icons.add, color: _light), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E2E6)))),
            onSubmitted: (val) {
              final t = val.trim();
              if (t.isNotEmpty && !globalCartList.contains(t)) {
                globalCartList.add(t);
                globalCartQuantities[t] = 1;
                _cartInputController.clear();
                setState(() {});
                _persist();
              }
            },
          ),
        ),
        Expanded(
          child: globalCartList.isEmpty
              ? const Center(child: Text("Sepetiniz boş.", style: TextStyle(fontFamily: 'Inter', color: _light)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: globalCartList.length,
                  itemBuilder: (context, index) {
                    final item = globalCartList[index];
                    final foodMatch = globalFoodsDatabase.where((f) => f.name == item).toList();
                    final emoji = foodMatch.isNotEmpty ? foodMatch.first.emoji : "🛒";
                    final qty = globalCartQuantities[item] ?? 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(item, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text))),
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: _primary, size: 20), onPressed: () { setState(() { if (qty > 1) { globalCartQuantities[item] = qty - 1; } else { globalCartList.remove(item); globalCartQuantities.remove(item); } }); _persist(); }),
                          Text("$qty", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                          IconButton(icon: const Icon(Icons.add_circle_outline, color: _primary, size: 20), onPressed: () { setState(() => globalCartQuantities[item] = qty + 1); _persist(); }),
                          IconButton(icon: const Icon(Icons.delete_outline, color: _danger, size: 20), onPressed: () { setState(() { globalCartList.remove(item); globalCartQuantities.remove(item); }); _persist(); }),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (globalCartList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () { setState(() { globalCartList.clear(); globalCartQuantities.clear(); }); _persist(); },
                style: OutlinedButton.styleFrom(foregroundColor: _danger, side: const BorderSide(color: _danger), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text("Tümünü Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  // ====================== PROFILE TAB ======================
  Widget _buildProfileTab() {
    final targets = _calculateBabyTargets();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text("Profil ve Ayarlar 👤", style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 4),
        const Text("Ebeveyn, bebek profilleri ve gelişim takibi.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        // Parent card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle), child: const Center(child: Icon(Icons.person, color: _primary, size: 24))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((_parent?["name"]?.isNotEmpty ?? false) ? _parent!["name"]! : "Ebeveyn", style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                    const SizedBox(height: 2),
                    Text((_parent?["relationship"]?.isNotEmpty ?? false) ? _parent!["relationship"]! : "Bilgileri eklemek için dokunun", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(tooltip: "Düzenle", icon: const Icon(Icons.edit_outlined, color: _primary, size: 20), onPressed: _showEditParentDialog),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Active baby banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primary.withOpacity(0.08), Colors.orange.withOpacity(0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Text(_activeBaby?["avatar"] ?? "👶", style: const TextStyle(fontSize: 32)))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeBaby?["name"] ?? "Bilinmeyen", style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
                    const SizedBox(height: 4),
                    Text("${_activeBaby?["gender"]} • ${_calculateAge(_activeBaby?["dob"]?.toString())}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Boy: ${_activeBaby?["height"]} cm • Kilo: ${_activeBaby?["weight"]} kg", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildBabyJourneyCard(),
        const SizedBox(height: 24),
        _buildRemindersCard(),
        const SizedBox(height: 24),
        // Targets
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Günlük Makro Hedefleri 📊", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
              const SizedBox(height: 12),
              _targetRow("Enerji", "${targets["Energy"]!.toInt()} kcal", _primary),
              const Divider(height: 16),
              _targetRow("Karbonhidrat", "${targets["Carb"]!.toStringAsFixed(0)} g", const Color(0xFF3B9EDB)),
              const Divider(height: 16),
              _targetRow("Protein", "${targets["Protein"]!.toStringAsFixed(1)} g", _danger),
              const Divider(height: 16),
              _targetRow("Sağlıklı Yağ", "${targets["Fat"]!.toStringAsFixed(1)} g", _green),
              const Divider(height: 16),
              _targetRow("Demir", "${targets["Iron"]!.toStringAsFixed(1)} mg", const Color(0xFF7A5CFF)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Tüm Bebekleriniz", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 10),
        ..._babies.map((baby) {
          final isActive = _activeBaby == baby;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isActive ? _primary : const Color(0xFFE2E2E6).withOpacity(0.6), width: isActive ? 1.5 : 1.0)),
            child: ListTile(
              onTap: () => _setActiveBaby(baby),
              leading: Text(baby["avatar"] ?? "👶", style: const TextStyle(fontSize: 24)),
              title: Text(baby["name"] ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
              subtitle: Text("${baby["gender"]} • ${baby["dob"]} • ${baby["weight"]} kg • ${baby["height"]} cm", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light, fontWeight: FontWeight.w500)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive) const Icon(Icons.check_circle, color: _green, size: 20) else const Icon(Icons.circle_outlined, color: _light, size: 20),
                  IconButton(tooltip: "Düzenle", icon: const Icon(Icons.edit_outlined, color: _primary, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () => _showEditBabyDialog(baby)),
                  IconButton(tooltip: "Sil", icon: const Icon(Icons.delete_outline, color: _danger, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () => _deleteBaby(baby)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddBabyDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Yeni Bebek Ekle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  Widget _targetRow(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      );

  Widget _buildBabyJourneyCard() {
    final id = _activeBabyId;
    final tried = triedCount(id);
    final reactions = reactionCount(id);
    final months = _ageMonths(_activeBaby?["dob"]?.toString());
    final states = globalBabyFoodStates[id] ?? {};
    final recent = states.entries.where((e) => (e.value as Map)["triedDate"] != null).toList()
      ..sort((a, b) => ((b.value as Map)["triedDate"] as String).compareTo((a.value as Map)["triedDate"] as String));
    final recentTop = recent.take(4).toList();

    Widget stat(String value, String label, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
            child: Column(children: [Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light, fontWeight: FontWeight.w500))]),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Gelişim Yolculuğu 🚀", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 12),
        Row(children: [stat("$tried", "Denenen Gıda", _green), stat("$reactions", "Reaksiyon", _danger), stat("$months", "Aylık", _primary)]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _currentIndex = 1),
            icon: const Icon(Icons.restaurant_menu, size: 18),
            label: const Text("Gıda Dene", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        if (recentTop.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text("Son Tadımlar", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 10),
          ...recentTop.map((e) {
            final name = e.key;
            final stm = e.value as Map;
            final isReaction = stm["status"] == "reaksiyon";
            final matches = globalFoodsDatabase.where((f) => f.name == name).toList();
            final emoji = matches.isNotEmpty ? matches.first.emoji : "🍽️";
            final photo = matches.isNotEmpty ? matches.first.imageUrl : "";
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
              child: Row(
                children: [
                  isPhotoUrl(photo) ? ClipOval(child: SizedBox(width: 30, height: 30, child: photoOrFallback(photo, fallback: const SizedBox(), fit: BoxFit.cover))) : Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                        const SizedBox(height: 2),
                        Text(_formatIsoTr(stm["triedDate"] as String), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: (isReaction ? _danger : _green).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(isReaction ? "Reaksiyon" : "Sorunsuz", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: isReaction ? _danger : _green)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRemindersCard() {
    final upcoming = upcomingReminders(_activeBabyId, _todayKey());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Yaklaşan Hatırlatmalar 🔔", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))), child: const Text("Yaklaşan hatırlatma yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)))
        else
          ...upcoming.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _primary.withOpacity(0.2))),
                child: Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: _primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.event_repeat, color: _primary, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r["title"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                          const SizedBox(height: 2),
                          Text("Tekrar deneme: ${_formatIsoTr(r["date"].toString())}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // ---------- parent / baby dialogs ----------
  void _showEditParentDialog() {
    const roles = ["Anne", "Baba", "Bakıcı", "Diğer"];
    final nameC = TextEditingController(text: _parent?["name"] ?? "");
    String rel = _parent?["relationship"] ?? "Anne";
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Ebeveyn Bilgileri", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameC, decoration: InputDecoration(labelText: "Adınız", labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light), isDense: true, filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
              const SizedBox(height: 14),
              const Text("Bebeğin nesi oluyorsunuz?", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _light)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: roles.map((role) {
                final sel = rel == role;
                return GestureDetector(
                  onTap: () => setD(() => rel = role),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.12) : _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? _primary : Colors.transparent, width: 1.5)), child: Text(role, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: sel ? _primary : _light))),
                );
              }).toList()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () {
                final name = nameC.text.trim();
                setState(() => _parent = {"name": name, "relationship": rel});
                StorageService.instance.saveParent(name, rel);
                Navigator.pop(dctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) => nameC.dispose());
  }

  void _deleteBaby(Map<String, dynamic> baby) {
    if (_babies.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("En az bir bebek profili bulunmalıdır.")));
      return;
    }
    final name = baby["name"]?.toString() ?? "Bebek";
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Bebeği Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
        content: Text("$name profilini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5A5A6A), height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("Vazgeç", style: TextStyle(fontFamily: 'Inter', color: _light))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dctx);
              final wasActive = _activeBaby == baby;
              setState(() {
                _babies.remove(baby);
                if (wasActive) {
                  _activeBaby = _babies.first;
                  _syncGlobalFlagsToActiveBaby();
                }
              });
              _persist();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name silindi.")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditBabyDialog(Map<String, dynamic> baby) {
    _babyDialog(baby: baby);
  }

  void _showAddBabyDialog() {
    _babyDialog(baby: null);
  }

  void _babyDialog({Map<String, dynamic>? baby}) {
    final nameC = TextEditingController(text: baby?["name"]?.toString() ?? "");
    final weightC = TextEditingController(text: baby?["weight"]?.toString() ?? "");
    final heightC = TextEditingController(text: baby?["height"]?.toString() ?? "");
    String gender = baby?["gender"]?.toString() ?? "Kız";
    String avatar = baby?["avatar"]?.toString() ?? "👶";
    DateTime? dob = _parseDob(baby?["dob"]?.toString());

    InputDecoration dec(String l) => InputDecoration(labelText: l, labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) {
          Widget genderChip(String value, IconData icon) {
            final sel = gender == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => setD(() => gender = value),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.12) : _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _primary : Colors.transparent, width: 1.5)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: sel ? _primary : _light), const SizedBox(width: 6), Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: sel ? _primary : _light))]),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(baby == null ? "Yeni Bebek" : "Bebek Bilgilerini Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameC, decoration: dec("İsim"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
                  const SizedBox(height: 12),
                  Row(children: [genderChip("Kız", Icons.female), genderChip("Erkek", Icons.male)]),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: dctx, initialDate: dob ?? DateTime.now().subtract(const Duration(days: 180)), firstDate: DateTime(2020), lastDate: DateTime.now(), locale: const Locale('tr', 'TR'));
                      if (picked != null) setD(() => dob = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: _light), const SizedBox(width: 8), Text(dob != null ? "${dob!.day.toString().padLeft(2, '0')}.${dob!.month.toString().padLeft(2, '0')}.${dob!.year}" : "Doğum tarihi seç", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text))]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: TextField(controller: weightC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec("Kilo (kg)"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text))), const SizedBox(width: 10), Expanded(child: TextField(controller: heightC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec("Boy (cm)"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)))]),
                  const SizedBox(height: 16),
                  const Text("Avatar", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _light)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: avatarOptions.map((emoji) {
                    final sel = avatar == emoji;
                    return GestureDetector(onTap: () => setD(() => avatar = emoji), child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: sel ? _primary.withOpacity(0.12) : _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? _primary : Colors.transparent, width: 1.5)), child: Text(emoji, style: const TextStyle(fontSize: 20))));
                  }).toList()),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
              ElevatedButton(
                onPressed: () {
                  final name = nameC.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(dctx).showSnackBar(const SnackBar(content: Text("Lütfen bir isim girin.")));
                    return;
                  }
                  final weight = double.tryParse(weightC.text.trim().replaceAll(',', '.')) ?? (baby?["weight"] as num?)?.toDouble() ?? 8.0;
                  final height = double.tryParse(heightC.text.trim().replaceAll(',', '.')) ?? (baby?["height"] as num?)?.toDouble() ?? 68.0;
                  final dobF = dob != null ? "${dob!.day.toString().padLeft(2, '0')}.${dob!.month.toString().padLeft(2, '0')}.${dob!.year}" : (baby?["dob"]?.toString() ?? "");
                  if (baby != null) {
                    setState(() {
                      baby["name"] = name;
                      baby["gender"] = gender;
                      baby["dob"] = dobF;
                      baby["avatar"] = avatar;
                      baby["weight"] = weight;
                      baby["height"] = height;
                    });
                  } else {
                    final newBaby = {"babyId": "b_${DateTime.now().millisecondsSinceEpoch}_new", "name": name, "gender": gender, "dob": dobF, "avatar": avatar, "weight": weight, "height": height};
                    setState(() {
                      _babies.add(newBaby);
                      _activeBaby = newBaby;
                      _syncGlobalFlagsToActiveBaby();
                    });
                  }
                  _persist();
                  Navigator.pop(dctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name kaydedildi!")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    ).then((_) { nameC.dispose(); weightC.dispose(); heightC.dispose(); });
  }
}
