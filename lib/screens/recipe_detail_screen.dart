import 'package:flutter/material.dart';
import '../data/food_database.dart';
import '../widgets/disclaimer.dart';
import '../widgets/image_helpers.dart';
import '../widgets/nutrition_card.dart';
import 'home_screen.dart';

// Global shopping cart list
final List<String> globalCartList = [];

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onStateChanged;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.onStateChanged,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _ingredientsKey = GlobalKey();
  final GlobalKey _stepsKey = GlobalKey();
  final GlobalKey _nutritionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _getRecipeImage(Recipe recipe) {
    final name = recipe.name.toLowerCase();
    String path = "assets/images/puree_plate.png";
    if (name.contains("omlet") || name.contains("omleti")) {
      path = "assets/images/omelet_plate.png";
    } else if (name.contains("somon") || name.contains("balık") || name.contains("mezgit") || name.contains("levrek")) {
      path = "assets/images/salmon_plate.png";
    } else if (name.contains("lapa") || name.contains("lapası") || name.contains("muhallebi") || name.contains("yulaf")) {
      path = "assets/images/porridge_plate.png";
    }
    final asset = Image.asset(path, fit: BoxFit.cover);
    return isPhotoUrl(recipe.imageUrl)
        ? photoOrFallback(recipe.imageUrl, fallback: asset, fit: BoxFit.cover)
        : asset;
  }

  void _toggleCartIngredient(String ingredient) {
    setState(() {
      if (globalCartList.contains(ingredient)) {
        globalCartList.remove(ingredient);
        globalCartQuantities.remove(ingredient);
      } else {
        globalCartList.add(ingredient);
        globalCartQuantities[ingredient] = 1;
      }
    });
    widget.onStateChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          globalCartList.contains(ingredient)
              ? "$ingredient alışveriş listesine eklendi."
              : "$ingredient alışveriş listesinden çıkarıldı.",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addAllToCart() {
    setState(() {
      for (var ing in widget.recipe.ingredients) {
        if (!globalCartList.contains(ing)) {
          globalCartList.add(ing);
          globalCartQuantities[ing] = 1;
        }
      }
    });
    widget.onStateChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tüm malzemeler alışveriş listesine eklendi."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final n = nutritionForRecipe(recipe);
    const primaryColor = Color(0xFFFF7A45); // Vibrant Apricot/Coral
    const textColor = Color(0xFF2D2D3A); // Vibrant dark grey
    const lightTextColor = Color(0xFFA8A8B3);
    const borderGreyColor = Color(0xFFE2E2E6);
    const alertBgColor = Color(0xFFFFF0F2); // Soft pink
    const alertTextColor = Color(0xFFFF4D6A);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium Recipe Image Header
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: primaryColor,
                elevation: 0,
                leading: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          globalFavoriteRecipes.contains(recipe.id) ? Icons.favorite : Icons.favorite_border,
                          color: globalFavoriteRecipes.contains(recipe.id) ? const Color(0xFFFF4D6A) : textColor,
                          size: 20,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (globalFavoriteRecipes.contains(recipe.id)) {
                            globalFavoriteRecipes.remove(recipe.id);
                          } else {
                            globalFavoriteRecipes.add(recipe.id);
                          }
                        });
                        widget.onStateChanged?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _getRecipeImage(recipe),
                      // Gradient overlay for text legibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                      // Text overlay
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                recipe.prepTime,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recipe detail body
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and dynamic Prep Time badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                recipe.name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0E6), // Light peach
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_filled, size: 14, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipe.prepTime,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Author
                        const Text(
                          "Hazırlayan: Uzman Dyt. Selin • 6+ Ay",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: lightTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stats Row (kcal, protein, iron, carbs)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatBadge(value: "${n["Enerji"]!.toInt()} kcal", label: "Kalori", color: textColor),
                            _buildStatBadge(value: "${n["Protein"]!.toStringAsFixed(1)}g", label: "Protein", color: textColor),
                            _buildStatBadge(value: "${n["Demir"]!.toStringAsFixed(1)}mg", label: "Demir", color: textColor),
                            _buildStatBadge(value: "${n["Karbonhidrat"]!.toStringAsFixed(0)}g", label: "Karbon", color: textColor),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Tab Bar for scrolling navigation
                        TabBar(
                          controller: _tabController,
                          labelColor: primaryColor,
                          unselectedLabelColor: lightTextColor,
                          indicatorColor: primaryColor,
                          indicatorWeight: 3.0,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          onTap: (index) {
                            GlobalKey? targetKey;
                            if (index == 0) {
                              targetKey = _ingredientsKey;
                            } else if (index == 1) {
                              targetKey = _stepsKey;
                            } else if (index == 2) {
                              targetKey = _nutritionKey;
                            }
                            if (targetKey != null && targetKey.currentContext != null) {
                              Scrollable.ensureVisible(
                                targetKey.currentContext!,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          tabs: const [
                            Tab(text: "Malzemeler"),
                            Tab(text: "Yapılışı"),
                            Tab(text: "Besin Değerleri"),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- MALZEMELER SECTION ---
                        Row(
                          key: _ingredientsKey,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "1 Porsiyon için",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E9F),
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: TextButton.icon(
                                onPressed: _addAllToCart,
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text(
                                  "Tümünü Sepete Ekle",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: recipe.ingredients.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final ingredient = entry.value;
                            final amount = recipe.ingredientAmounts[idx];

                            final foodInfo = globalFoodsDatabase.firstWhere(
                              (f) => f.name.toLowerCase() == ingredient.toLowerCase(),
                              orElse: () => Food(
                                name: ingredient,
                                emoji: "🍎",
                                category: "Diğer",
                                startingMonth: 6,
                                allergyRisk: "Düşük",
                                presentationStyles: {},
                                nutritionValues: {},
                              ),
                            );

                            final inCart = globalCartList.contains(ingredient);

                            Color emojiBgColor;
                            switch (foodInfo.category) {
                                case 'Sebze':
                                  emojiBgColor = const Color(0xFFE8F8F0);
                                  break;
                                case 'Meyve':
                                  emojiBgColor = const Color(0xFFFFF0E6);
                                  break;
                                case 'Tahıl':
                                  emojiBgColor = const Color(0xFFFFFBE6);
                                  break;
                                case 'Et':
                                case 'Balık':
                                  emojiBgColor = const Color(0xFFFFF0F2);
                                  break;
                                default:
                                  emojiBgColor = const Color(0xFFF5F5F7);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderGreyColor.withOpacity(0.8)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: emojiBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(foodInfo.emoji, style: const TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ingredient,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          amount,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: Color(0xFF8E8E9F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => _toggleCartIngredient(ingredient),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: inCart ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFFF7A45).withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          inCart ? Icons.shopping_cart : Icons.add_shopping_cart,
                                          color: inCart ? const Color(0xFF10B981) : const Color(0xFFFF7A45),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Divider(color: Color(0xFFE2E2E6)),
                        ),

                        // --- YAPILIŞI SECTION ---
                        Row(
                          key: _stepsKey,
                          children: const [
                            Text(
                              "Hazırlanışı",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: recipe.steps.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final step = entry.value;

                            String? timeRef;
                            final regex = RegExp(r'(\d+)\s*(dakika|dk)', caseSensitive: false);
                            final match = regex.firstMatch(step);
                            if (match != null) {
                              timeRef = "${match.group(1)} Dakika";
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: primaryColor,
                                    child: Text(
                                      "${idx + 1}",
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.9),
                                            height: 1.4,
                                          ),
                                        ),
                                        if (timeRef != null) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFFF4D6A)),
                                              const SizedBox(width: 4),
                                              Text(
                                                timeRef,
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFFF4D6A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Divider(color: Color(0xFFE2E2E6)),
                        ),

                        // --- BESİN DEĞERLERİ SECTION ---
                        Row(
                          key: _nutritionKey,
                          children: const [
                            Text(
                              "Besin Değerleri",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        NutritionDetailCard(
                          energyKcal: n["Enerji"]!,
                          carb: n["Karbonhidrat"]!,
                          protein: n["Protein"]!,
                          fat: n["Yağ"]!,
                          portionLabel: "1 Porsiyon",
                          tableRows: nutrientRowsFromMap(n),
                        ),
                        const SizedBox(height: 14),
                        const MedicalDisclaimer(),
                        const SizedBox(height: 24),

                        // Alerji Uyarısı Panel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: alertBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: alertTextColor.withOpacity(0.12)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: alertTextColor, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Alerji Uyarısı",
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: alertTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      recipe.allergyWarning,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: alertTextColor.withOpacity(0.85),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),

          // Bottom Fixed Plan Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              color: Colors.white,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () => _showPlanMealBottomSheet(context),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text(
                    "Öğün Olarak Planla",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatFullDateTurkish(DateTime date) {
    final List<String> monthNames = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    final List<String> dayNames = [
      "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"
    ];
    return "${date.day} ${monthNames[date.month - 1]} ${date.year}, ${dayNames[date.weekday - 1]}";
  }

  String _formatDateTurkish(String dateKey) {
    try {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[2]);
        final month = int.parse(parts[1]);
        final List<String> monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
        return "$day ${monthNames[month - 1]}";
      }
    } catch (_) {}
    return dateKey;
  }

  void _showPlanMealBottomSheet(BuildContext context) {
    const primaryColor = Color(0xFFFF7A45);
    const textColor = Color(0xFF2D2D3A);
    const borderGreyColor = Color(0xFFE2E2E6);
    const lightTextColor = Color(0xFFA8A8B3);

    DateTime selectedDate = DateTime.now();
    String selectedMeal = "Kahvaltı";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final meals = [
              {"key": "Kahvaltı", "label": "🌅 Kahvaltı"},
              {"key": "Öğle Yemeği", "label": "☀️ Öğle Yemeği"},
              {"key": "Akşam Yemeği", "label": "🌙 Akşam Yemeği"},
              {"key": "1. Ara Öğün", "label": "🍎 1. Ara Öğün"},
              {"key": "2. Ara Öğün", "label": "🍊 2. Ara Öğün"},
              {"key": "3. Ara Öğün", "label": "🥝 3. Ara Öğün"},
            ];

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Öğün Planına Ekle",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: textColor),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Tarih Seçin",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Interactive Date Selection Container
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: primaryColor,
                                  onPrimary: Colors.white,
                                  onSurface: textColor,
                                ),
                              ),
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  size: Size(
                                    MediaQuery.of(context).size.shortestSide,
                                    MediaQuery.of(context).size.longestSide,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGreyColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: primaryColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatFullDateTurkish(selectedDate),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Değiştirmek için dokunun",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: lightTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: lightTextColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Öğün Seçin",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meals.map((meal) {
                      final isSelected = selectedMeal == meal["key"];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ChoiceChip(
                          label: Text(meal["label"]!),
                          selected: isSelected,
                          selectedColor: primaryColor,
                          backgroundColor: Colors.white,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : textColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : borderGreyColor,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                selectedMeal = meal["key"]!;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: () {
                        final dateKey = _formatDateKey(selectedDate);
                        if (globalWeeklyPlan[dateKey] == null) {
                          globalWeeklyPlan[dateKey] = {
                            "Kahvaltı": [],
                            "Öğle Yemeği": [],
                            "Akşam Yemeği": [],
                            "1. Ara Öğün": [],
                            "2. Ara Öğün": [],
                            "3. Ara Öğün": [],
                          };
                        }
                        globalWeeklyPlan[dateKey]![selectedMeal]!.add(widget.recipe.name);
                        
                        Navigator.of(context).pop();
                        widget.onStateChanged?.call();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${widget.recipe.name}, ${_formatDateTurkish(dateKey)} günü $selectedMeal öğününe eklendi! 📅"),
                            duration: const Duration(seconds: 2),
                            backgroundColor: primaryColor,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Planı Kaydet",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatBadge({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E2E6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xFFA8A8B3),
            ),
          ),
        ],
      ),
    );
  }



}
