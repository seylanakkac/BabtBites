import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/food_database.dart';
import '../data/recipe_social_store.dart';
import '../services/storage_service.dart';
import '../services/social_sync.dart';
import 'user_profile_screen.dart';
import 'premium_screen.dart';
import '../widgets/ad_banner.dart';
import '../widgets/disclaimer.dart';
import '../widgets/sponsored_badge.dart';
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

  final _commentController = TextEditingController();
  String _commentPhoto = "";
  bool _cookMode = false;

  void _toggleCookMode() {
    setState(() => _cookMode = !_cookMode);
    if (_cookMode) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_cookMode ? "Pişirme modu açık — ekran kapanmayacak 👨‍🍳" : "Pişirme modu kapatıldı."),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Interactive 5-star rating + community average. Tapping a star records this
  /// device's vote (persisted immediately) and updates the shown average.
  Widget _buildRatingRow(Recipe recipe) {
    const star = Color(0xFFFFB300);
    const textColor = Color(0xFF2D2D3A);
    const lightTextColor = Color(0xFFA8A8B3);
    final my = myRecipeRating(recipe.id).round();
    final avg = recipeRatingAverage(recipe.id);
    final count = recipeRatingCount(recipe.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: star.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: star.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          for (int i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () async {
                if (myRecipeRating(recipe.id) == i.toDouble()) return; // same vote → no change
                setState(() => setRecipeRating(recipe.id, i.toDouble()));
                StorageService.instance.saveRecipeSocial();
                widget.onStateChanged?.call();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Puanın: $i ★ — teşekkürler!"),
                  duration: const Duration(seconds: 1),
                ));
                // Update the cloud aggregate, then refresh the shown average.
                await SocialSync.instance.rate(recipe.id, i.toDouble());
                if (mounted) setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(i <= my ? Icons.star_rounded : Icons.star_outline_rounded, size: 28, color: star),
              ),
            ),
          const Spacer(),
          const Icon(Icons.star_rounded, size: 18, color: star),
          const SizedBox(width: 3),
          Text(avg.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(width: 4),
          Text("($count)", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: lightTextColor)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Count a view for this recipe (local + real cross-user).
    addRecipeView(widget.recipe.id);
    SocialSync.instance.addView(widget.recipe.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onStateChanged?.call());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _commentController.dispose();
    // Always release the wakelock when leaving the recipe.
    WakelockPlus.disable();
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
                      tooltip: _cookMode ? "Pişirme modu açık" : "Tarifi yapıyorum (ekran açık kalsın)",
                      icon: CircleAvatar(
                        backgroundColor: _cookMode ? primaryColor : Colors.white,
                        child: Icon(
                          _cookMode ? Icons.lightbulb : Icons.lightbulb_outline,
                          color: _cookMode ? Colors.white : textColor,
                          size: 20,
                        ),
                      ),
                      onPressed: _toggleCookMode,
                    ),
                  ),
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
                        SocialSync.instance.setLike(recipe.id, globalFavoriteRecipes.contains(recipe.id));
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
                        
                        // Author (tappable -> public profile)
                        Row(
                          children: [
                            const Text(
                              "Hazırlayan: ",
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: lightTextColor, fontWeight: FontWeight.w500),
                            ),
                            Flexible(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => UserProfileScreen(author: recipe.author)),
                                ),
                                child: Text(
                                  "@${recipe.author}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                    decorationColor: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              " • ${recipe.startingMonth}+ Ay",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: lightTextColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Views + likes + share
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, size: 16, color: lightTextColor),
                            const SizedBox(width: 4),
                            Text("${recipeViewCount(recipe.id)}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: lightTextColor)),
                            const SizedBox(width: 14),
                            Icon(Icons.favorite, size: 16, color: const Color(0xFFFF4D6A).withOpacity(0.9)),
                            const SizedBox(width: 4),
                            Text("${recipeLikeBase(recipe.id) + (globalFavoriteRecipes.contains(recipe.id) ? 1 : 0)}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: lightTextColor)),
                            const Spacer(),
                            _shareBtn(FontAwesomeIcons.instagram, const Color(0xFFE1306C), () => _shareRecipe("instagram")),
                            const SizedBox(width: 8),
                            _shareBtn(FontAwesomeIcons.facebookF, const Color(0xFF1877F2), () => _shareRecipe("facebook")),
                            const SizedBox(width: 8),
                            _shareBtn(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), () => _shareRecipe("whatsapp")),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recipe.sponsored) ...[
                          Align(alignment: Alignment.centerLeft, child: SponsoredBadge(label: recipe.sponsorLabel)),
                          const SizedBox(height: 12),
                        ],
                        // Star rating (1..5) — taps record this user's vote.
                        _buildRatingRow(recipe),
                        const SizedBox(height: 14),
                        // Like + I-tried buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (globalFavoriteRecipes.contains(recipe.id)) {
                                      globalFavoriteRecipes.remove(recipe.id);
                                    } else {
                                      globalFavoriteRecipes.add(recipe.id);
                                    }
                                  });
                                  SocialSync.instance.setLike(recipe.id, globalFavoriteRecipes.contains(recipe.id));
                                  widget.onStateChanged?.call();
                                },
                                icon: Icon(globalFavoriteRecipes.contains(recipe.id) ? Icons.favorite : Icons.favorite_border, size: 18, color: const Color(0xFFFF4D6A)),
                                label: Text(globalFavoriteRecipes.contains(recipe.id) ? "Beğenildi" : "Beğen", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFFFF4D6A))),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFFF4D6A)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (globalRecipeTried.contains(recipe.id)) {
                                      globalRecipeTried.remove(recipe.id);
                                    } else {
                                      globalRecipeTried.add(recipe.id);
                                    }
                                  });
                                  widget.onStateChanged?.call();
                                },
                                icon: Icon(globalRecipeTried.contains(recipe.id) ? Icons.check_circle : Icons.restaurant_menu, size: 18, color: globalRecipeTried.contains(recipe.id) ? const Color(0xFF10B981) : primaryColor),
                                label: Text(globalRecipeTried.contains(recipe.id) ? "Denedim ✓" : "Denedim", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: globalRecipeTried.contains(recipe.id) ? const Color(0xFF10B981) : primaryColor)),
                                style: OutlinedButton.styleFrom(side: BorderSide(color: (globalRecipeTried.contains(recipe.id) ? const Color(0xFF10B981) : primaryColor).withOpacity(0.6)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addTriedPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: lightTextColor),
                            label: const Text("Deneme fotoğrafı ekle (isteğe bağlı)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: lightTextColor)),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                        ),
                        if (triedPhotosFor(recipe.id).isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text("Kullanıcı Denemeleri 📸", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: triedPhotosFor(recipe.id).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(width: 80, height: 80, child: photoOrFallback(triedPhotosFor(recipe.id)[i], fallback: const SizedBox(), fit: BoxFit.cover)),
                              ),
                            ),
                          ),
                        ],
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
                        const SizedBox(height: 24),
                        AdBanner(
                          onUpgrade: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PremiumScreen(onChanged: () {})),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildCommentsSection(recipe),
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

  Widget _shareBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
      );

  Future<void> _shareRecipe(String platform) async {
    final r = widget.recipe;
    final text = "BabyBites'ta \"${r.name}\" tarifi 🍲 (${r.startingMonth}+ ay). Hazırlayan: ${r.author}";
    final enc = Uri.encodeComponent(text);
    Uri? uri;
    if (platform == "whatsapp") {
      uri = Uri.parse("https://wa.me/?text=$enc");
    } else if (platform == "facebook") {
      uri = Uri.parse("https://www.facebook.com/sharer/sharer.php?u=https://babybites.app&quote=$enc");
    } else {
      // Instagram has no web share intent — copy text and open Instagram.
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif metni kopyalandı — Instagram'da paylaşabilirsiniz."), duration: Duration(seconds: 2)));
      uri = Uri.parse("https://www.instagram.com");
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _addTriedPhoto() async {
    final uri = await pickPhotoDataUri();
    if (uri == null) return;
    setState(() {
      triedPhotosFor(widget.recipe.id).add(uri);
      globalRecipeTried.add(widget.recipe.id);
    });
    widget.onStateChanged?.call();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fotoğrafınız eklendi, teşekkürler! 📷"), duration: Duration(seconds: 2)));
  }

  Widget _buildCommentsSection(Recipe recipe) {
    const textColor = Color(0xFF2D2D3A);
    const lightTextColor = Color(0xFFA8A8B3);
    const primaryColor = Color(0xFFFF7A45);
    final comments = commentsFor(recipe.id);
    // Public list: approved comments + the user's own pending ones.
    final visible = comments.where((c) => c["approved"] == true || c["name"] == "Siz").toList();

    String fmtDate(String iso) {
      final p = iso.split('-');
      if (p.length != 3) return iso;
      const months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
      final m = int.tryParse(p[1]) ?? 1;
      return "${int.parse(p[2])} ${months[(m - 1).clamp(0, 11)]}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Yorumlar (${approvedCommentsFor(recipe.id).length})", style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 12),
        // Add comment row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                final uri = await pickPhotoDataUri();
                if (uri != null) setState(() => _commentPhoto = uri);
              },
              child: Container(
                width: 44,
                height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: const Color(0xFFF3F3F5), borderRadius: BorderRadius.circular(12)),
                child: isPhotoUrl(_commentPhoto) ? photoOrFallback(_commentPhoto, fallback: const SizedBox(), fit: BoxFit.cover) : const Icon(Icons.add_a_photo_outlined, color: lightTextColor, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: textColor),
                decoration: InputDecoration(hintText: "Yorum yaz...", hintStyle: const TextStyle(color: lightTextColor, fontSize: 13), filled: true, fillColor: const Color(0xFFF3F3F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final t = _commentController.text.trim();
                if (t.isEmpty && !isPhotoUrl(_commentPhoto)) return;
                final now = DateTime.now();
                comments.insert(0, {
                  "name": "Siz",
                  "text": t,
                  "photo": _commentPhoto,
                  "date": "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
                  "approved": false,
                });
                _commentController.clear();
                setState(() => _commentPhoto = "");
                widget.onStateChanged?.call();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorumun alındı. Yönetici onayından sonra yayınlanacak."), duration: Duration(seconds: 2)));
              },
              child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Henüz yorum yok. İlk yorumu sen yaz!", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: lightTextColor)))
        else
          ...visible.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 14, backgroundColor: Color(0xFFFFE3D6), child: Icon(Icons.person, size: 16, color: primaryColor)),
                        const SizedBox(width: 8),
                        Text(c["name"]?.toString() ?? "Kullanıcı", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                        if (c["approved"] != true) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                            child: const Text("Onay bekliyor", style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB8860B))),
                          ),
                        ],
                        const Spacer(),
                        Text(fmtDate(c["date"]?.toString() ?? ""), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: lightTextColor)),
                      ],
                    ),
                    if ((c["text"]?.toString() ?? "").isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(c["text"].toString(), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: textColor, height: 1.4)),
                    ],
                    if (isPhotoUrl(c["photo"])) ...[
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 140, width: double.infinity, child: photoOrFallback(c["photo"], fallback: const SizedBox(), fit: BoxFit.cover))),
                    ],
                  ],
                ),
              )),
      ],
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
