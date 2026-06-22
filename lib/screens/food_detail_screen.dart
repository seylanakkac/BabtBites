import 'package:flutter/material.dart';
import '../data/food_database.dart';
import '../data/admin_store.dart';
import '../data/tracking_store.dart';
import '../widgets/ad_banner.dart';
import '../widgets/disclaimer.dart';
import '../widgets/image_helpers.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/web_shell.dart';
import 'premium_screen.dart';
import 'recipe_detail_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  final Food food;
  final String babyId;
  final VoidCallback? onStateChanged;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.babyId,
    this.onStateChanged,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _todayIso() {
    final n = DateTime.now();
    return "${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}";
  }

  String _formatTr(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    const months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    final m = int.tryParse(parts[1]) ?? 1;
    return "${int.parse(parts[2])} ${months[(m - 1).clamp(0, 11)]} ${parts[0]}";
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// Records a trial outcome (sorunsuz / reaksiyon / clear) for the active baby,
  /// and on a reaction optionally schedules a retry reminder.
  Future<void> _recordTrial() async {
    final food = widget.food;
    const primaryColor = Color(0xFFFF7A45);
    const textColor = Color(0xFF2D2D3A);
    final already = readFoodState(widget.babyId, food.name)?["tried"] == true;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget option(IconData icon, Color color, String title, String value) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(title,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            onTap: () => Navigator.pop(ctx, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text("${food.name} için sonuç",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              option(Icons.check_circle, const Color(0xFF10B981), "Sorunsuz denendi", "sorunsuz"),
              option(Icons.warning_amber_rounded, const Color(0xFFFF4D6A), "Reaksiyon oldu", "reaksiyon"),
              if (already) option(Icons.undo, primaryColor, "Denenmedi olarak işaretle", "clear"),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    final st = ensureFoodState(widget.babyId, food.name);

    if (choice == "clear") {
      setState(() {
        st["tried"] = false;
        st["status"] = null;
        st["triedDate"] = null;
        st["retryDate"] = null;
        food.tried = false;
      });
      removeRetryReminder(widget.babyId, food.name);
      widget.onStateChanged?.call();
      return;
    }

    if (choice == "sorunsuz") {
      setState(() {
        st["tried"] = true;
        st["status"] = "sorunsuz";
        st["triedDate"] = _todayIso();
        st["retryDate"] = null;
        food.tried = true;
      });
      removeRetryReminder(widget.babyId, food.name);
      widget.onStateChanged?.call();
      _toast("${food.name} sorunsuz olarak işaretlendi ✅");
      return;
    }

    // reaksiyon
    setState(() {
      st["tried"] = true;
      st["status"] = "reaksiyon";
      st["triedDate"] = _todayIso();
      food.tried = true;
    });

    // Ask which reaction(s) occurred + optional custom symptom + note.
    final details = await _askReactionDetails(food);
    if (!mounted) return;
    if (details != null) {
      setState(() {
        st["reactionSymptoms"] = details["symptoms"];
        st["reactionNote"] = details["note"];
      });
    }

    final retry = await _askRetry();
    if (!mounted) return;
    if (retry != null) {
      final iso =
          "${retry.year}-${retry.month.toString().padLeft(2, '0')}-${retry.day.toString().padLeft(2, '0')}";
      setState(() => st["retryDate"] = iso);
      upsertRetryReminder(widget.babyId, food.name, iso, DateTime.now().millisecondsSinceEpoch);
      _toast("Reaksiyon kaydedildi. ${_formatTr(iso)} için hatırlatma eklendi 🔔");
    } else {
      setState(() => st["retryDate"] = null);
      removeRetryReminder(widget.babyId, food.name);
      _toast("Reaksiyon kaydedildi.");
    }
    widget.onStateChanged?.call();
  }

  /// Asks whether to retry the food; returns the chosen date, or null.
  Future<DateTime?> _askRetry() async {
    final wantRetry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tekrar deneyecek misiniz?",
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D3A))),
        content: const Text(
          "Reaksiyon görülen gıdayı ileride tekrar denemek isterseniz, seçtiğiniz tarih için size hatırlatma ekleyelim.",
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5A5A6A), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hayır", style: TextStyle(fontFamily: 'Inter', color: Color(0xFFA8A8B3))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A45),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Evet, tarih seç", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (wantRetry != true || !mounted) return null;
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFFF7A45), onPrimary: Colors.white, onSurface: Color(0xFF2D2D3A)),
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(MediaQuery.of(context).size.shortestSide, MediaQuery.of(context).size.longestSide)),
          child: child!,
        ),
      ),
    );
  }

  /// Lets the parent pick which reaction(s) occurred (common symptoms + custom)
  /// and add a free-text note. Returns {"symptoms": List<String>, "note": String}.
  Future<Map<String, dynamic>?> _askReactionDetails(Food food) async {
    const primaryColor = Color(0xFFFF7A45);
    const textColor = Color(0xFF2D2D3A);
    const lightColor = Color(0xFFA8A8B3);
    const danger = Color(0xFFFF4D6A);
    const bg = Color(0xFFFAF9F6);

    const common = [
      "Ciltte kızarıklık/döküntü",
      "Kurdeşen (ürtiker)",
      "Ağız çevresinde kızarıklık/şişlik",
      "Kusma",
      "İshal",
      "Karın ağrısı/gaz/huzursuzluk",
      "Kabızlık",
      "Egzama alevlenmesi",
      "Burun akıntısı/hapşırma",
      "Gözlerde kızarıklık/sulanma",
      "Hırıltı/nefes darlığı",
    ];

    final existing = readFoodState(widget.babyId, food.name);
    final selected = <String>{...((existing?["reactionSymptoms"] as List?)?.map((e) => e.toString()) ?? const [])};
    final custom = <String>{};
    for (final s in [...selected]) {
      if (!common.contains(s)) custom.add(s);
    }
    final noteC = TextEditingController(text: existing?["reactionNote"]?.toString() ?? "");
    final customC = TextEditingController();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chip(String label) {
            final sel = selected.contains(label);
            return GestureDetector(
              onTap: () => setSheet(() => sel ? selected.remove(label) : selected.add(label)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: sel ? danger.withOpacity(0.12) : bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? danger : Colors.transparent, width: 1.4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.check, size: 14, color: danger)),
                    Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? danger : textColor)),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2)))),
                    Text("${food.name} — Ne tür reaksiyon görüldü?", style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    const Text("Görülen belirtileri seçin (birden fazla olabilir).", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: lightColor)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [...common.map(chip), ...custom.map(chip)]),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customC,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: textColor),
                            decoration: InputDecoration(hintText: "Başka bir belirti ekle...", hintStyle: const TextStyle(color: lightColor, fontSize: 13), isDense: true, filled: true, fillColor: bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                            onSubmitted: (_) {
                              final v = customC.text.trim();
                              if (v.isNotEmpty) setSheet(() { custom.add(v); selected.add(v); customC.clear(); });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final v = customC.text.trim();
                            if (v.isNotEmpty) setSheet(() { custom.add(v); selected.add(v); customC.clear(); });
                          },
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white, size: 20)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Not (isteğe bağlı)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: lightColor)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteC,
                      maxLines: 3,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: textColor),
                      decoration: InputDecoration(hintText: "Belirtilerin başlama zamanı, süresi, şiddeti vb.", hintStyle: const TextStyle(color: lightColor, fontSize: 13), filled: true, fillColor: bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: danger.withOpacity(0.2))),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: danger),
                          SizedBox(width: 8),
                          Expanded(child: Text("Nefes darlığı, yüz/dudak şişmesi, sürekli kusma veya yaygın morarma gibi ciddi belirtilerde vakit kaybetmeden 112'yi arayın.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: danger, height: 1.3))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, {"symptoms": selected.toList(), "note": noteC.text.trim()}),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text("Devam", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    noteC.dispose();
    customC.dispose();
    return result;
  }

  // Map Recipe to claymation visual plate assets
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

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    const primaryColor = Color(0xFFFF7A45); // Vibrant Apricot
    const textColor = Color(0xFF2D2D3A); // Darker charcoal for legibility
    const lightTextColor = Color(0xFFA8A8B3);
    const borderGreyColor = Color(0xFFE2E2E6);

    // Filter recipes that contain this food
    final relatedRecipes = globalRecipesDatabase.where((r) => r.ingredients.contains(food.name)).toList();

    // Per-baby trial state for this food
    final st = readFoodState(widget.babyId, food.name);
    final tried = st?["tried"] == true;
    final reactionStatus = st?["status"] as String?; // sorunsuz | reaksiyon | null
    final retryDate = st?["retryDate"] as String?;

    // Determine allergy risk color
    Color allergyColor;
    if (food.allergyRisk == "Düşük") {
      allergyColor = const Color(0xFF10B981); // Emerald Green
    } else if (food.allergyRisk == "Orta") {
      allergyColor = const Color(0xFFFF7A45); // Vibrant Apricot
    } else {
      allergyColor = const Color(0xFFFF4D6A); // Red
    }

    return webPageShell(
      context,
      maxWidth: 880,
      child: Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: Icon(
                food.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: food.isFavorite ? const Color(0xFFFF4D6A) : textColor,
                size: 24,
              ),
              onPressed: () {
                final st = ensureFoodState(widget.babyId, food.name);
                setState(() {
                  st["favorite"] = !(st["favorite"] == true);
                  food.isFavorite = st["favorite"] == true; // keep projection in sync
                });
                widget.onStateChanged?.call();
              },
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) => Center(
          child: SizedBox(
            // Web/masaüstünde içeriği makul genişlikte tut → yayılma olmaz.
            width: c.maxWidth < 820 ? c.maxWidth : 820,
            height: c.maxHeight,
            child: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Emoji Header
                        Center(
                          child: Column(
                            children: [
                              // Big Circular Badge for Emoji
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderGreyColor, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: isPhotoUrl(food.imageUrl)
                                    ? photoOrFallback(food.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          food.emoji,
                                          style: const TextStyle(fontSize: 60),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Name
                              Text(
                                food.name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              
                              // Category
                              Text(
                                food.category,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: lightTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),

                        // Uzman onayı bekleyen (toplu eklenmiş) gıdalar için uyarı.
                        if (effectiveFoodNeedsReview(food))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Color(0xFFB26A00)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Bu gıdanın besin ve güvenlik bilgileri uzman onayı bekliyor. Kesin bilgi olarak kullanmadan önce bir uzmana danışın.",
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFB26A00), fontWeight: FontWeight.w600, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Allergy and Month Info row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              // Allergy box
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderGreyColor, width: 1.0),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Alerji Riski",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: lightTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        food.allergyRisk,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: allergyColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Month box
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderGreyColor, width: 1.0),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Başlangıç Ayı",
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: lightTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${food.startingMonth}+ Ay",
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
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
                        tabs: const [
                          Tab(text: "Sunum Şekli"),
                          Tab(text: "Besin Değeri"),
                          Tab(text: "Tarifler"),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Sunum Şekli View
                  _buildPresentationTab(food),
                  
                  // 2. Besin Değeri View
                  _buildNutritionTab(food),
                  
                  // 3. Tarifler View
                  _buildRecipesTab(food, relatedRecipes),
                ],
              ),
            ),
          ),
          
          // Trial + reaction status bottom panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: borderGreyColor.withOpacity(0.5))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      !tried
                          ? Icons.radio_button_unchecked
                          : (reactionStatus == "reaksiyon" ? Icons.warning_amber_rounded : Icons.check_circle),
                      color: !tried
                          ? lightTextColor
                          : (reactionStatus == "reaksiyon" ? const Color(0xFFFF4D6A) : const Color(0xFF10B981)),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !tried
                                ? "Gıda henüz denenmedi"
                                : (reactionStatus == "reaksiyon" ? "Denendi · Reaksiyon görüldü" : "Denendi · Sorunsuz"),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: !tried
                                  ? textColor
                                  : (reactionStatus == "reaksiyon" ? const Color(0xFFFF4D6A) : const Color(0xFF10B981)),
                            ),
                          ),
                          if (tried && reactionStatus == "reaksiyon") ...[
                            if (((st?["reactionSymptoms"] as List?)?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 2),
                              Text(
                                "Belirtiler: ${(st!["reactionSymptoms"] as List).join(", ")}",
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: lightTextColor),
                              ),
                            ],
                            if (retryDate != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                "Tekrar deneme: ${_formatTr(retryDate)}",
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: lightTextColor),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: _recordTrial,
                      icon: Icon(tried ? Icons.edit_outlined : Icons.restaurant_menu, size: 18),
                      label: Text(
                        tried ? "Durumu Güncelle" : "Denedim — Reaksiyonu Kaydet",
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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
      ),
    ),
    );
  }

  Widget _buildPresentationTab(Food food) {
    const textColor = Color(0xFF2D2D3A);
    const lightTextColor = Color(0xFFA8A8B3);
    const bgColor = Color(0xFFFFF7F2); // Soft cream
    const indicatorColor = Color(0xFFFF7A45);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      children: [
        _buildSafetyCard(food),
        const SizedBox(height: 4),
        ...food.presentationStyles.entries.map((entry) {
        final int month = entry.key;
        final String text = entry.value;

        String title = "";
        if (month == 6) {
          title = "Püre veya Ezme";
        } else if (month == 9) {
          title = "Yumuşak Dilimler";
        } else if (month == 12) {
          title = "Küp Doğrama";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Bubble
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "$month",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: indicatorColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: lightTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
      ],
    );
  }

  /// Boğulma riski + güvenli sunum uyarısı kartı (sunum sekmesinin başında).
  Widget _buildSafetyCard(Food food) {
    final risk = chokingRiskFor(food);
    final note = chokingNoteFor(food);
    Color color;
    IconData icon;
    if (risk == "Yüksek") {
      color = const Color(0xFFE5484D);
      icon = Icons.warning_amber_rounded;
    } else if (risk == "Orta") {
      color = const Color(0xFFF5A623);
      icon = Icons.info_outline_rounded;
    } else {
      color = const Color(0xFF30A46C);
      icon = Icons.check_circle_outline_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                "Boğulma Riski: $risk",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF5A5A66),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTab(Food food) {
    const textColor = Color(0xFF2D2D3A);
    final n = nutritionForFood(food);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Besin Değerleri",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          NutritionDetailCard(
            energyKcal: n["Enerji"]!,
            carb: n["Karbonhidrat"]!,
            protein: n["Protein"]!,
            fat: n["Yağ"]!,
            portionLabel: "100 g",
            tableRows: nutrientRowsFromMap(n),
          ),
          const SizedBox(height: 16),
          const MedicalDisclaimer(),
          const SizedBox(height: 16),
          AdBanner(
            onUpgrade: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PremiumScreen(onChanged: () {})),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesTab(Food food, List<Recipe> relatedRecipes) {
    const textColor = Color(0xFF2D2D3A);
    const lightTextColor = Color(0xFFA8A8B3);
    const primaryColor = Color(0xFFFF7A45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${food.name} Tarifleri",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                "Tümünü Gör",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: relatedRecipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text(
                        "Bu gıda ile ilgili henüz tarif bulunmuyor.",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: lightTextColor,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: relatedRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = relatedRecipes[index];
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(
                                recipe: recipe,
                                onStateChanged: widget.onStateChanged,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.015),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Recipe Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  color: primaryColor.withOpacity(0.1),
                                  child: SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: _getRecipeImage(recipe),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${recipe.startingMonth}+ Ay • ${recipe.prepTime}",
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: lightTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${recipe.kcal.toInt()} kcal",
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
                            const Icon(Icons.chevron_right, color: lightTextColor),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFFAF9F6), // Match scaffold background
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
