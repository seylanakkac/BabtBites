import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/admin_store.dart';
import '../data/recipe_social_store.dart';
import '../services/file_storage.dart';
import '../services/catalog_sync.dart';
import '../services/social_sync.dart';
import '../services/community_sync.dart';
import '../data/community_store.dart';
import '../data/food_database.dart';
import '../services/storage_service.dart';
import '../widgets/image_helpers.dart';
import 'articles_screen.dart';
import 'user_profile_screen.dart';

/// Full-screen professional admin area (only reached via the admin account).
/// Left navigation rail + content panes: dashboard, content managers (foods /
/// recipes / articles with search + add/edit/delete) and config editors.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _primary = Color(0xFFFF7A45);
  static const _text = Color(0xFF2D2D3A);
  static const _light = Color(0xFFA8A8B3);
  static const _bg = Color(0xFFFAF9F6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFFF4D6A);

  int _section = 0;

  final _foodSearch = TextEditingController();
  bool _onlyPendingFoods = false;
  final _recipeSearch = TextEditingController();
  final _articleSearch = TextEditingController();
  final _newFoodCat = TextEditingController();
  final _newArticleCat = TextEditingController();
  final _newAvatar = TextEditingController();
  final _newSuppName = TextEditingController();
  final _newDoseUnit = TextEditingController();
  final _newCartUnit = TextEditingController();
  final _newRecipeUnit = TextEditingController();
  final _newRecipeCat = TextEditingController();
  final _newCommunityCat = TextEditingController();
  final _newFormulaName = TextEditingController();
  final _newFeedingUnit = TextEditingController();
  final _newPromoCode = TextEditingController();
  int _newPromoDays = 7;
  final Map<String, TextEditingController> _nt = {};

  @override
  void initState() {
    super.initState();
    for (final k in kDefaultNutritionTargets.keys) {
      _nt[k] = TextEditingController(text: _trimNum(ntv(k)));
    }
  }

  @override
  void dispose() {
    _foodSearch.dispose();
    _recipeSearch.dispose();
    _articleSearch.dispose();
    _newFoodCat.dispose();
    _newArticleCat.dispose();
    _newAvatar.dispose();
    _newSuppName.dispose();
    _newDoseUnit.dispose();
    _newCartUnit.dispose();
    _newRecipeUnit.dispose();
    _newRecipeCat.dispose();
    _newCommunityCat.dispose();
    _newFormulaName.dispose();
    _newFeedingUnit.dispose();
    _newPromoCode.dispose();
    for (final c in _nt.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _trimNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  void _persistAll() {
    StorageService.instance.saveCustomContent();
    StorageService.instance.saveAdminContent();
  }

  /// Uploads a catalog image to Storage and returns its download URL. If the
  /// upload fails the helper returns "" (NOT the base64) and warns — storing a
  /// big base64 blob in the shared /catalog doc would blow past Firestore's
  /// 1 MiB/doc limit and make the whole save silently fail on reload.
  Future<String> _uploadCatalogImage(String path, String? image) async {
    final result = await FileStorage.instance.uploadDataUri(path, image);
    if (result.startsWith('data:')) {
      _toast("Fotoğraf sunucuya yüklenemedi (Storage). İçerik fotoğrafsız kaydedildi.");
      return "";
    }
    return result;
  }

  /// Runs [work] while showing a blocking spinner (used for photo uploads on
  /// save so the button doesn't look frozen). Always dismisses the spinner.
  Future<T> _runSaving<T>(Future<T> Function() work) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _primary)),
    );
    try {
      return await work();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ---------- shared field helpers ----------
  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light),
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light),
        isDense: true,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Widget _field(TextEditingController c, String label, {String? hint, int maxLines = 1, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
          decoration: _dec(label, hint: hint),
        ),
      );

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: _dec(label),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              isDense: true,
              isExpanded: true,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      );

  Widget _primaryBtn(String label, IconData icon, VoidCallback onPressed) => ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _sectionHeader(String title, String subtitle, {Widget? action}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
        ),
        child: child,
      );

  void _confirmDelete(String what, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
        content: Text("$what silinsin mi? Bu işlem geri alınamaz.",
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5A5A6A))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç", style: TextStyle(fontFamily: 'Inter', color: _light))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------- shell ----------
  @override
  Widget build(BuildContext context) {
    // Güvenlik: admin paneli yalnızca admin e-postasıyla giriş yapana açılır
    // (mevcut oturumdan doğrulanır; istemci-tarafı yetkisiz erişimi engeller).
    if (!isAdminEmail(FirebaseAuth.instance.currentUser?.email)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      });
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text("Bu sayfaya erişim yetkiniz yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _light))),
      );
    }
    final extended = MediaQuery.of(context).size.width > 1080;
    const destinations = [
      (Icons.dashboard_outlined, "Genel Bakış"),
      (Icons.restaurant, "Gıdalar"),
      (Icons.menu_book, "Tarifler"),
      (Icons.article_outlined, "Yazılar"),
      (Icons.category_outlined, "Kategoriler"),
      (Icons.tune, "Varsayılanlar"),
      (Icons.monitor_heart_outlined, "Beslenme"),
      (Icons.campaign_outlined, "Reklamlar"),
      (Icons.rate_review_outlined, "Yorumlar"),
      (Icons.menu_book_outlined, "Tarif Onayı"),
      (Icons.verified_outlined, "Uzman Onayı"),
      (Icons.forum_outlined, "Topluluk"),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                extended: extended,
                minExtendedWidth: 210,
                backgroundColor: Colors.white,
                selectedIndex: _section,
                onDestinationSelected: (i) => setState(() => _section = i),
                labelType: extended ? null : NavigationRailLabelType.all,
                selectedIconTheme: const IconThemeData(color: _primary),
                selectedLabelTextStyle: const TextStyle(fontFamily: 'Inter', color: _primary, fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelTextStyle: const TextStyle(fontFamily: 'Inter', color: _light, fontSize: 12),
                unselectedIconTheme: const IconThemeData(color: _light),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      const Text("🍼", style: TextStyle(fontSize: 26)),
                      if (extended) ...[
                        const SizedBox(height: 6),
                        const Text("BabyBites\nYönetim", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _text)),
                      ],
                    ],
                  ),
                ),
                // Düz öğe (Expanded DEĞİL): IntrinsicHeight + Expanded kaydirmayi
                // bozuyordu; bu sekilde kucuk/mobil ekranda menu kayar ve Cikis'a
                // ulasilabilir.
                trailing: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Column(
                    children: [
                      const Divider(height: 1, color: Color(0xFFEDEDED)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: _red, size: 20),
                        label: extended
                            ? const Text("Çıkış Yap", style: TextStyle(fontFamily: 'Inter', color: _red, fontWeight: FontWeight.bold, fontSize: 13))
                            : const SizedBox.shrink(),
                        style: TextButton.styleFrom(foregroundColor: _red),
                      ),
                    ],
                  ),
                ),
                destinations: destinations
                    .map((d) => NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)))
                    .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEDEDED)),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    final nav = Navigator.of(context);
    setAdminMode(false);
    StorageService.instance.saveIsAdmin(false);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await StorageService.instance.clearUserData();
    nav.pushReplacementNamed('/login');
  }

  Widget _content() {
    switch (_section) {
      case 1:
        return _foodsManager();
      case 2:
        return _recipesManager();
      case 3:
        return _articlesManager();
      case 4:
        return _categoriesManager();
      case 5:
        return _defaultsManager();
      case 6:
        return _nutritionManager();
      case 7:
        return _marketLinksManager();
      case 8:
        return _commentsManager();
      case 9:
        return _recipesApprovalManager();
      case 10:
        return _expertApprovalManager();
      case 11:
        return _communityManager();
      default:
        return _dashboard();
    }
  }

  Widget _pane(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(28),
        children: children,
      );

  // ---------- dashboard ----------
  Widget _statCard(String value, String label, Color color, IconData icon) => Container(
        width: 180,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _distChip(String label, int count, Color color) => Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Text("$label: $count", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _dashboard() {
    final totalViews = globalRecipesDatabase.fold<int>(0, (s, r) => s + recipeViewCount(r.id));
    final totalLikes = globalRecipesDatabase.fold<int>(0, (s, r) => s + recipeLikeCount(r.id));
    final pendingFoods = globalFoodsDatabase.where(effectiveFoodNeedsReview).length;
    return _pane([
      _sectionHeader("Genel Bakış", "İçerik ve kullanım istatistikleri"),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _statCard("${globalFoodsDatabase.length}", "Toplam Gıda", _green, Icons.restaurant),
        _statCard("${globalRecipesDatabase.length}", "Toplam Tarif", _primary, Icons.menu_book),
        _statCard("${globalCustomArticles.length}", "Özel Yazı", const Color(0xFF2980B9), Icons.article_outlined),
        _statCard("${globalCustomFoods.length}", "Özel Gıda", const Color(0xFF8B5E3C), Icons.add_box_outlined),
        _statCard("${globalCustomRecipes.length}", "Özel Tarif", const Color(0xFFD4AC0D), Icons.add_box_outlined),
      ]),
      const SizedBox(height: 16),
      // Etkileşim (tüm kullanıcılar) + moderasyon + profil
      Wrap(spacing: 16, runSpacing: 16, children: [
        _statCard("$totalViews", "Tarif Görüntülenme", const Color(0xFF3B9EDB), Icons.visibility_outlined),
        _statCard("$totalLikes", "Toplam Beğeni", const Color(0xFFE84393), Icons.favorite_border),
        _statCard("${pendingRecipeCount()}", "Onay Bekleyen Tarif", const Color(0xFFE67E22), Icons.pending_actions),
        _statCard("${pendingCommentCount()}", "Onay Bekleyen Yorum", const Color(0xFF8E44AD), Icons.mode_comment_outlined),
        _statCard("$pendingFoods", "Uzman Onayı Bekleyen", const Color(0xFFC0392B), Icons.verified_outlined),
        // Kayıtlı public profil — tıklayınca liste açılır.
        InkWell(
          onTap: _showProfilesDialog,
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<int?>(
            future: SocialSync.instance.profileCount(),
            builder: (ctx, snap) => _statCard(
              snap.connectionState == ConnectionState.waiting ? "…" : (snap.data?.toString() ?? "—"),
              "Kayıtlı Profil →",
              const Color(0xFF16A085),
              Icons.people_outline,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _card(
        child: const Row(
          children: [
            Icon(Icons.insights_outlined, color: _primary, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Toplam kayıtlı kullanıcı sayısı ve trafik/davranış raporları Firebase Console → Authentication ve Google Analytics (GA4) üzerindedir. Buradaki sayılar uygulama içi içerik ve etkileşim verileridir.",
                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: _light, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kategoriye Göre Gıda", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 12),
            Wrap(children: foodCategories.map((c) => _distChip(c, globalFoodsDatabase.where((f) => f.category == c).length, _primary)).toList()),
            const SizedBox(height: 16),
            const Text("Alerji Riskine Göre", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 12),
            Wrap(children: [
              _distChip("Düşük", globalFoodsDatabase.where((f) => f.allergyRisk == "Düşük").length, _green),
              _distChip("Orta", globalFoodsDatabase.where((f) => f.allergyRisk == "Orta").length, _primary),
              _distChip("Yüksek", globalFoodsDatabase.where((f) => f.allergyRisk == "Yüksek").length, _red),
            ]),
          ],
        ),
      ),
    ]);
  }

  /// Kayıtlı public profilleri (kullanıcı adı + sosyal hesap sayısı) listeler.
  void _showProfilesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Kayıtlı Profiller", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
        content: SizedBox(
          width: 420,
          height: 460,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: SocialSync.instance.loadAllProfiles(),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text("Henüz public profil oluşturulmamış.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${list.length} profil • toplam kayıtlı kullanıcı için Firebase Console → Authentication", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c2, i) {
                        final p = list[i];
                        final uname = p["username"]?.toString() ?? "";
                        final socials = (p["socials"] as Map?) ?? {};
                        final linked = socials.values.where((v) => (v?.toString() ?? "").trim().isNotEmpty).length;
                        final following = (p["following"] as List?)?.length ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundColor: _primary.withOpacity(0.15), child: Text(uname.isNotEmpty ? uname[0].toUpperCase() : "?", style: const TextStyle(color: _primary, fontWeight: FontWeight.bold))),
                          title: Text("@$uname", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                          subtitle: Text("$linked sosyal hesap • $following takip", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                          trailing: const Icon(Icons.open_in_new, size: 18, color: _primary),
                          onTap: uname.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(author: uname)));
                                },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat", style: TextStyle(fontFamily: 'Inter', color: _light)))],
      ),
    );
  }

  // ---------- generic list item ----------
  Widget _itemCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required bool isCustom,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    bool pending = false,
    VoidCallback? onApprove,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 46, height: 46, child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: _text)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: (isCustom ? _primary : _light).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(isCustom ? "Özel" : "Yerleşik", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: isCustom ? _primary : _light)),
                      ),
                      if (pending) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFC107).withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                          child: const Text("⏳ Onay bekliyor", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB26A00))),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
                    ],
                  ),
                ],
              ),
            ),
            if (pending && onApprove != null)
              IconButton(
                tooltip: "Uzman onayını ver",
                icon: const Icon(Icons.verified_outlined, color: _green, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: onApprove,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _primary, size: 19),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: _red, size: 19),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: onDelete,
            ),
          ],
        ),
      );

  Widget _searchBar(TextEditingController c, String hint, ValueChanged<String> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light),
            prefixIcon: const Icon(Icons.search, color: _light),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E2E6))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E2E6))),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );

  // ---------- foods manager ----------
  /// Bir gıdanın "uzman onayı bekliyor" işaretini kaldırır.
  /// Persist/sync çağıranın sorumluluğunda (toplu işlemde tek seferde yapılır).
  void _approveFood(Food f) {
    setFoodReviewApproved(f.name, true);
  }

  Widget _foodsManager() {
    final q = _foodSearch.text.trim().toLowerCase();
    final pendingCount = globalFoodsDatabase.where(effectiveFoodNeedsReview).length;
    var foods = globalFoodsDatabase.where((f) => f.name.toLowerCase().contains(q)).toList();
    if (_onlyPendingFoods) foods = foods.where(effectiveFoodNeedsReview).toList();
    return _pane([
      _sectionHeader("Gıdalar", "${globalFoodsDatabase.length} gıda • $pendingCount uzman onayı bekliyor",
          action: _primaryBtn("Yeni Gıda", Icons.add, () => _foodDialog(null))),
      // Uzman onayı filtresi + toplu onay
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _onlyPendingFoods = !_onlyPendingFoods),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _onlyPendingFoods ? const Color(0xFFFFC107).withOpacity(0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _onlyPendingFoods ? const Color(0xFFFFC107) : const Color(0xFFE2E2E6)),
                  ),
                  child: Row(
                    children: [
                      Icon(_onlyPendingFoods ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: const Color(0xFFB26A00)),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Sadece onay bekleyenler ($pendingCount)", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
                    ],
                  ),
                ),
              ),
            ),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _confirmDelete("⚠️ ${_onlyPendingFoods ? foods.length : pendingCount} gıdanın uzman onayını TOPLU vermek", () {
                  final list = (_onlyPendingFoods ? foods : globalFoodsDatabase.where(effectiveFoodNeedsReview).toList());
                  for (final f in list.toList()) {
                    _approveFood(f);
                  }
                  _persistAll();
                  setState(() {});
                  _toast("${list.length} gıda onaylandı");
                }),
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text("Tümünü Onayla", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ],
        ),
      ),
      _searchBar(_foodSearch, "Gıda ara...", (_) => setState(() {})),
      ...foods.map((f) => _itemCard(
            leading: isPhotoUrl(f.imageUrl)
                ? photoOrFallback(f.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                : Container(color: const Color(0xFFFAF9F6), child: Center(child: Text(f.emoji, style: const TextStyle(fontSize: 22)))),
            title: f.name,
            subtitle: "${f.category} • ${f.startingMonth}+ ay • Alerji: ${f.allergyRisk}",
            isCustom: isCustomFood(f.name),
            pending: effectiveFoodNeedsReview(f),
            onApprove: () {
              _approveFood(f);
              _persistAll();
              setState(() {});
              _toast("${f.name} onaylandı");
            },
            onEdit: () => _foodDialog(f.toJson()),
            onDelete: () => _confirmDelete("'${f.name}' gıdası", () {
              deleteFood(f.name);
              _persistAll();
              setState(() {});
              _toast("${f.name} silindi");
            }),
          )),
      if (foods.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("Sonuç yok.", style: TextStyle(fontFamily: 'Inter', color: _light))),
    ]);
  }

  void _foodDialog(Map<String, dynamic>? existing) {
    final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
    String image = existing?["imageUrl"]?.toString() ?? "";
    String cat = existing?["category"]?.toString() ?? foodCategories.first;
    final month = TextEditingController(text: "${existing?["startingMonth"] ?? 6}");
    String risk = existing?["allergyRisk"]?.toString() ?? "Düşük";
    String cartUnit = existing?["cartUnit"]?.toString() ?? "adet";
    if (!cartUnitOptions.contains(cartUnit)) cartUnit = cartUnitOptions.isNotEmpty ? cartUnitOptions.first : "adet";
    String choking = existing?["chokingRisk"]?.toString() ?? "";
    final chokingNote = TextEditingController(text: existing?["chokingNote"]?.toString() ?? "");
    final gramsPiece = TextEditingController(
        text: ((existing?["gramsPerPiece"] as num?)?.toDouble() ?? 0) > 0 ? existing!["gramsPerPiece"].toString() : "");
    // Presentation styles per age (month -> text). Each gets its own editable row.
    final ps = (existing?["presentationStyles"] as Map?) ?? {};
    final presEntries = <Map<String, TextEditingController>>[];
    ps.forEach((k, v) {
      presEntries.add({"month": TextEditingController(text: k.toString()), "text": TextEditingController(text: v.toString())});
    });
    presEntries.sort((a, b) => (int.tryParse(a["month"]!.text) ?? 0).compareTo(int.tryParse(b["month"]!.text) ?? 0));
    if (presEntries.isEmpty) {
      presEntries.add({"month": TextEditingController(text: "${existing?["startingMonth"] ?? 6}"), "text": TextEditingController()});
    }
    final nv = (existing?["nutritionValues"] as Map?) ?? {};
    TextEditingController nvc(String key, [String? alt]) => TextEditingController(
        text: (nv[key] ?? (alt != null ? nv[alt] : null))?.toString() ?? "");
    final energy = nvc("Enerji");
    final carb = nvc("Karbonhidrat");
    final protein = nvc("Protein");
    final fat = nvc("Yağ", "Sağlıklı Yağ");
    final fiber = nvc("Lif");
    final chol = nvc("Kolesterol");
    final sodium = nvc("Sodyum");
    final potassium = nvc("Potasyum");
    final calcium = nvc("Kalsiyum");
    final vitA = nvc("Vitamin A");
    final vitC = nvc("Vitamin C");
    final iron = nvc("Demir");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? "Yeni Gıda" : "Gıdayı Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhotoPickerField(value: image, label: "Gıda fotoğrafı", height: 130, onChanged: (v) => setD(() => image = v ?? "")),
                  const SizedBox(height: 14),
                  _field(name, "Gıda adı", hint: "Örn. Brokoli"),
                  _dropdown("Kategori", cat, foodCategories, (v) => setD(() => cat = v)),
                  _field(month, "Başlangıç ayı", hint: "6", keyboard: TextInputType.number),
                  _dropdown("Alerji riski", risk, const ["Düşük", "Orta", "Yüksek"], (v) => setD(() => risk = v)),
                  _dropdown("Sepet birimi", cartUnit, cartUnitOptions, (v) => setD(() => cartUnit = v)),
                  Row(children: [
                    Expanded(
                      child: _dropdown("Boğulma riski", choking.isEmpty ? "Otomatik" : choking,
                          const ["Otomatik", "Düşük", "Orta", "Yüksek"],
                          (v) => setD(() => choking = v == "Otomatik" ? "" : v)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _field(gramsPiece, "1 adet ≈ (gr)", hint: "ör. 100", keyboard: TextInputType.number)),
                  ]),
                  _field(chokingNote, "Güvenli sunum / boğulma notu", maxLines: 2, hint: "Boş bırakılırsa otomatik metin gösterilir"),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Sunum şekilleri (aya göre)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  ),
                  ...presEntries.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 60, child: _field(e["month"]!, "Ay", keyboard: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(e["text"]!, "Sunum şekli", maxLines: 2)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: _red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: presEntries.length > 1
                                ? () => setD(() {
                                      final removed = presEntries.removeAt(i);
                                      removed["month"]!.dispose();
                                      removed["text"]!.dispose();
                                    })
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setD(() => presEntries.add({"month": TextEditingController(), "text": TextEditingController()})),
                      icon: const Icon(Icons.add, size: 16, color: _primary),
                      label: const Text("Sunum ekle", style: TextStyle(fontFamily: 'Inter', color: _primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Besin Değerleri (100g)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  ),
                  Row(children: [Expanded(child: _field(energy, "Enerji (kcal)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(carb, "Karbonhidrat (g)", keyboard: TextInputType.number))]),
                  Row(children: [Expanded(child: _field(protein, "Protein (g)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(fat, "Yağ (g)", keyboard: TextInputType.number))]),
                  Row(children: [Expanded(child: _field(fiber, "Lif (g)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(chol, "Kolesterol (mg)", keyboard: TextInputType.number))]),
                  Row(children: [Expanded(child: _field(sodium, "Sodyum (mg)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(potassium, "Potasyum (mg)", keyboard: TextInputType.number))]),
                  Row(children: [Expanded(child: _field(calcium, "Kalsiyum (mg)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(iron, "Demir (mg)", keyboard: TextInputType.number))]),
                  Row(children: [Expanded(child: _field(vitA, "A Vitamini (IU)", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(vitC, "C Vitamini (mg)", keyboard: TextInputType.number))]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () async {
                final n = name.text.trim();
                if (n.isEmpty) {
                  _toast("Lütfen ad girin");
                  return;
                }
                final m = int.tryParse(month.text.trim()) ?? 6;
                double pn(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
                final nav = Navigator.of(ctx);
                final imgUrl = await _runSaving(() => _uploadCatalogImage("catalog/foods/${n.hashCode}.jpg", image));
                saveFoodEdit({
                  "name": n,
                  "emoji": existing?["emoji"]?.toString() ?? "🍽️",
                  "category": cat,
                  "startingMonth": m,
                  "allergyRisk": risk,
                  "imageUrl": imgUrl,
                  "cartUnit": cartUnit,
                  "gramsPerPiece": double.tryParse(gramsPiece.text.trim().replaceAll(',', '.')) ?? 0,
                  "chokingRisk": choking,
                  "chokingNote": chokingNote.text.trim(),
                  "presentationStyles": {
                    for (final e in presEntries)
                      if (e["text"]!.text.trim().isNotEmpty)
                        (int.tryParse(e["month"]!.text.trim()) ?? m).toString(): e["text"]!.text.trim(),
                  },
                  "nutritionValues": {
                    "Enerji": pn(energy), "Karbonhidrat": pn(carb), "Protein": pn(protein), "Yağ": pn(fat),
                    "Lif": pn(fiber), "Kolesterol": pn(chol), "Sodyum": pn(sodium), "Potasyum": pn(potassium),
                    "Kalsiyum": pn(calcium), "Vitamin A": pn(vitA), "Vitamin C": pn(vitC), "Demir": pn(iron),
                  },
                });
                _persistAll();
                final err = await _runSaving(() => CatalogSync.instance.push());
                nav.pop();
                if (mounted) setState(() {});
                if (err != null) {
                  _toast("Buluta kaydedilemedi: $err");
                } else {
                  _toast(existing == null ? "$n eklendi" : "$n güncellendi");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [name, month, energy, carb, protein, fat, fiber, chol, sodium, potassium, calcium, vitA, vitC, iron, chokingNote, gramsPiece]) {
        c.dispose();
      }
      for (final e in presEntries) {
        e["month"]!.dispose();
        e["text"]!.dispose();
      }
    });
  }

  // ---------- recipes manager ----------
  Widget _recipesManager() {
    final q = _recipeSearch.text.trim().toLowerCase();
    final recipes = globalRecipesDatabase.where((r) => r.name.toLowerCase().contains(q)).toList();
    return _pane([
      _sectionHeader("Tarifler", "${globalRecipesDatabase.length} tarif • düzenle, sil veya yeni ekle",
          action: _primaryBtn("Yeni Tarif", Icons.add, () => _recipeDialog(null))),
      _searchBar(_recipeSearch, "Tarif ara...", (_) => setState(() {})),
      ...recipes.map((r) => _itemCard(
            leading: isPhotoUrl(r.imageUrl)
                ? photoOrFallback(r.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                : Container(color: _primary.withOpacity(0.1), child: const Icon(Icons.menu_book, color: _primary)),
            title: r.name,
            subtitle: "${r.startingMonth}+ ay • ${r.prepTime} • ${computedRecipeEnergy(r).round()} kcal",
            isCustom: isCustomRecipe(r.id),
            onEdit: () => _recipeDialog(r.toJson()),
            onDelete: () => _confirmDelete("'${r.name}' tarifi", () {
              deleteRecipe(r.id);
              _persistAll();
              setState(() {});
              _toast("${r.name} silindi");
            }),
          )),
      if (recipes.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("Sonuç yok.", style: TextStyle(fontFamily: 'Inter', color: _light))),
    ]);
  }

  void _recipeDialog(Map<String, dynamic>? existing, {Map<String, dynamic>? pending}) {
    final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
    String image = existing?["imageUrl"]?.toString() ?? "";
    final prep = TextEditingController(text: existing?["prepTime"]?.toString() ?? "15 dk");
    final month = TextEditingController(text: "${existing?["startingMonth"] ?? 6}");
    final kcal = TextEditingController(text: existing?["kcal"]?.toString() ?? "");
    final servings = TextEditingController(text: "${existing?["servings"] ?? 1}");
    final author = TextEditingController(text: existing?["author"]?.toString() ?? "BabyBites");
    final steps = TextEditingController(text: ((existing?["steps"] as List?) ?? []).join("\n"));
    final warn = TextEditingController(text: existing?["allergyWarning"]?.toString() ?? "");
    final video = TextEditingController(text: existing?["videoUrl"]?.toString() ?? "");
    final storage = TextEditingController(text: existing?["storage"]?.toString() ?? "");
    final productLinks = <Map<String, String>>[
      for (final l in ((existing?["productLinks"] as List?) ?? const []))
        {"label": (l as Map)["label"]?.toString() ?? "", "url": l["url"]?.toString() ?? ""}
    ];
    final sponsorLabel = TextEditingController(text: existing?["sponsorLabel"]?.toString() ?? "");
    bool sponsored = existing?["sponsored"] == true;
    String category = existing?["category"]?.toString() ?? "Diğer";
    if (!recipeCategoryOptions.contains(category)) category = "Diğer";

    // Structured ingredient list: name (from foods or custom) + quantity + unit.
    final ingredients = <String>[];
    final qtyCtrls = <TextEditingController>[];
    final ingUnits = <String>[];
    final defaultUnit = recipeUnitOptions.isNotEmpty ? recipeUnitOptions.first : "adet";
    // Parse a stored "100 gr" / "1 yemek kaşığı" into (quantity, unit).
    List<String> parseAmount(String s) {
      final m = RegExp(r'^\s*([\d.,]+)\s*(.*)$').firstMatch(s.trim());
      if (m != null) return [m.group(1)!.trim(), m.group(2)!.trim()];
      return ["", s.trim()];
    }

    final ingList = ((existing?["ingredients"] as List?) ?? const []).map((e) => e.toString()).toList();
    final amtList = ((existing?["ingredientAmounts"] as List?) ?? const []).map((e) => e.toString()).toList();
    for (var i = 0; i < ingList.length; i++) {
      ingredients.add(ingList[i]);
      final parts = parseAmount(i < amtList.length ? amtList[i] : "");
      qtyCtrls.add(TextEditingController(text: parts[0]));
      ingUnits.add(parts[1].isEmpty ? defaultUnit : parts[1]);
    }
    // Dropdown options = managed units ∪ any legacy units already stored.
    final unitsAll = <String>[...recipeUnitOptions];
    for (final u in ingUnits) {
      if (u.isNotEmpty && !unitsAll.contains(u)) unitsAll.add(u);
    }

    String emojiFor(String n) {
      final m = globalFoodsDatabase.where((f) => f.name.toLowerCase() == n.toLowerCase()).toList();
      return m.isNotEmpty ? m.first.emoji : "🧺";
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? "Yeni Tarif" : "Tarifi Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhotoPickerField(value: image, label: "Tarif fotoğrafı", height: 130, onChanged: (v) => setD(() => image = v ?? "")),
                  const SizedBox(height: 14),
                  _field(name, "Tarif adı"),
                  Row(children: [Expanded(child: _field(prep, "Hazırlık", hint: "15 dk")), const SizedBox(width: 10), Expanded(child: _field(month, "Ay", hint: "6", keyboard: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(servings, "Porsiyon", hint: "1", keyboard: TextInputType.number))]),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: _field(kcal, "Kalori (kcal)", keyboard: TextInputType.number)),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        final amts = List.generate(ingredients.length, (i) {
                          final q = qtyCtrls[i].text.trim();
                          final u = ingUnits[i].trim();
                          return q.isEmpty ? u : (u.isEmpty ? q : "$q $u");
                        });
                        final e = computeEnergyFromIngredients(ingredients, amts);
                        if (e > 0) {
                          setD(() => kcal.text = e.round().toString());
                          _toast("Malzemelerden ${e.round()} kcal hesaplandı");
                        } else {
                          _toast("Miktarlardan kalori hesaplanamadı (gıdaları/birimleri kontrol edin)");
                        }
                      },
                      icon: const Icon(Icons.calculate_outlined, size: 18, color: _primary),
                      label: const Text("Otomatik", style: TextStyle(fontFamily: 'Inter', color: _primary, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  _field(author, "Hazırlayan", hint: "BabyBites"),
                  const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: Text("Kategori", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        items: recipeCategoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)))).toList(),
                        onChanged: (v) => setD(() => category = v ?? "Diğer"),
                      ),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: Text("Malzemeler", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  if (ingredients.isEmpty)
                    const Padding(padding: EdgeInsets.only(bottom: 6), child: Text("Henüz malzeme yok. Aşağıdan gıdalardan ekleyin.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
                  ...List.generate(ingredients.length, (i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7))),
                        child: Column(
                          children: [
                            Row(children: [
                              Text(emojiFor(ingredients[i]), style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(ingredients[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: _red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                onPressed: () => setD(() {
                                  ingredients.removeAt(i);
                                  qtyCtrls.removeAt(i).dispose();
                                  ingUnits.removeAt(i);
                                }),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              SizedBox(
                                width: 78,
                                child: TextField(controller: qtyCtrls[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text), decoration: _dec("Miktar")),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: unitsAll.contains(ingUnits[i]) ? ingUnits[i] : (unitsAll.isNotEmpty ? unitsAll.first : null),
                                      items: unitsAll.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text)))).toList(),
                                      onChanged: (v) => setD(() => ingUnits[i] = v ?? ingUnits[i]),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      )),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickFood((picked) {
                        setD(() {
                          ingredients.add(picked);
                          qtyCtrls.add(TextEditingController());
                          ingUnits.add(defaultUnit);
                        });
                      }),
                      icon: const Icon(Icons.add, size: 18, color: _primary),
                      label: const Text("Gıdalardan Malzeme Ekle", style: TextStyle(fontFamily: 'Inter', color: _primary, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: _primary.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _field(steps, "Adımlar (her satır)", maxLines: 5),
                  _field(warn, "Alerji uyarısı"),
                  _field(storage, "Saklama koşulları", hint: "ör. Buzdolabında 3 gün, buzlukta 1 ay"),
                  _field(video, "Video linki (YouTube/Shorts, opsiyonel)", hint: "https://youtube.com/... veya youtu.be/..."),
                  const Padding(padding: EdgeInsets.only(top: 10, bottom: 2), child: Align(alignment: Alignment.centerLeft, child: Text("Ürün / İşbirliği Linkleri", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light)))),
                  const Padding(padding: EdgeInsets.only(bottom: 6), child: Align(alignment: Alignment.centerLeft, child: Text("Tarif detayında 'Bu Tarifte Kullandıklarım' altında tıklanabilir çıkar (affiliate).", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)))),
                  ...productLinks.asMap().entries.map((e) {
                    final i = e.key;
                    final l = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: TextEditingController(text: l["label"])..selection = TextSelection.collapsed(offset: (l["label"] ?? "").length),
                              decoration: _dec("Etiket (ör. Kullandığım tava)"),
                              onChanged: (v) => l["label"] = v,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: TextEditingController(text: l["url"])..selection = TextSelection.collapsed(offset: (l["url"] ?? "").length),
                              decoration: _dec("URL (https://...)"),
                              keyboardType: TextInputType.url,
                              onChanged: (v) => l["url"] = v,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: _red, size: 20), onPressed: () => setD(() => productLinks.removeAt(i))),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setD(() => productLinks.add({"label": "", "url": ""})),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Link Ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Sponsorlu içerik", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
                    subtitle: const Text("Kartlarda ve detayda 'Sponsorlu' etiketi gösterilir", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                    value: sponsored,
                    activeColor: _primary,
                    onChanged: (v) => setD(() => sponsored = v),
                  ),
                  if (sponsored) _field(sponsorLabel, "Sponsor adı (marka)", hint: "ör. MarkaAdı"),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () async {
                final n = name.text.trim();
                if (n.isEmpty) {
                  _toast("Lütfen ad girin");
                  return;
                }
                final nav = Navigator.of(ctx);
                final rid = existing?["id"]?.toString() ?? "rc_${DateTime.now().millisecondsSinceEpoch}";
                final imgUrl = await _runSaving(() => _uploadCatalogImage("catalog/recipes/$rid.jpg", image));
                final data = {
                  "id": rid,
                  "name": n,
                  "category": category,
                  "prepTime": prep.text.trim().isEmpty ? "15 dk" : prep.text.trim(),
                  "startingMonth": int.tryParse(month.text.trim()) ?? 6,
                  "kcal": double.tryParse(kcal.text.trim().replaceAll(',', '.')) ?? 0,
                  "imageUrl": imgUrl,
                  "ingredients": List<String>.from(ingredients),
                  "ingredientAmounts": List.generate(ingredients.length, (i) {
                    final q = qtyCtrls[i].text.trim();
                    final u = ingUnits[i].trim();
                    return q.isEmpty ? u : (u.isEmpty ? q : "$q $u");
                  }),
                  "steps": steps.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  "allergyWarning": warn.text.trim(),
                  "author": author.text.trim().isEmpty ? "BabyBites" : author.text.trim(),
                  "sponsored": sponsored,
                  "sponsorLabel": sponsorLabel.text.trim(),
                  "videoUrl": video.text.trim(),
                  "servings": int.tryParse(servings.text.trim()) ?? 1,
                  "storage": storage.text.trim(),
                  "productLinks": [
                    for (final l in productLinks)
                      if ((l["url"] ?? "").trim().isNotEmpty)
                        {"label": (l["label"] ?? "").trim(), "url": (l["url"] ?? "").trim()}
                  ],
                };
                saveRecipeEdit(data);
                // Onay kuyruğundan açıldıysa: yayına ekle + onay temizliği.
                if (pending != null) {
                  final saved = Recipe.fromJson(data);
                  if (!globalRecipesDatabase.any((x) => x.id == saved.id)) {
                    globalRecipesDatabase.add(saved);
                  }
                }
                _persistAll();
                final err = await _runSaving(() => CatalogSync.instance.push());
                if (pending != null) {
                  final docId = pending["_docId"]?.toString() ?? "";
                  final toUid = pending["uid"]?.toString() ?? "";
                  if (toUid.isNotEmpty) {
                    await SocialSync.instance.sendNotification(toUid, "Tarifin onaylandı! 🎉", "\"$n\" tarifin yayınlandı.", type: 'recipe');
                  }
                  if (docId.isNotEmpty) await SocialSync.instance.deletePendingRecipe(docId);
                  if (mounted) setState(() => _pendingRecipesList?.remove(pending));
                }
                nav.pop();
                if (mounted) setState(() {});
                if (err != null) {
                  _toast("Buluta kaydedilemedi: $err");
                } else {
                  _toast(pending != null ? "Tarif onaylandı ve yayınlandı" : (existing == null ? "$n eklendi" : "$n güncellendi"));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [name, prep, month, kcal, author, steps, warn, ...qtyCtrls]) {
        c.dispose();
      }
    });
  }

  /// Bottom-sheet picker to choose an ingredient from the foods database
  /// (or add a custom one by typing). Calls [onPick] with the chosen name.
  void _pickFood(void Function(String name) onPick) {
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
          final exact = globalFoodsDatabase.any((f) => f.name.toLowerCase() == q);
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: 480,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text("Malzeme Seç", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => setSheet(() {}),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                      decoration: InputDecoration(hintText: "Gıda ara veya yeni yaz...", prefixIcon: const Icon(Icons.search, color: _light), filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (q.isNotEmpty && !exact)
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: _primary),
                            title: Text("“${searchCtrl.text.trim()}” ekle (özel malzeme)", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _primary)),
                            onTap: () { onPick(searchCtrl.text.trim()); Navigator.pop(ctx); },
                          ),
                        ...foods.map((f) => ListTile(
                              leading: Text(f.emoji, style: const TextStyle(fontSize: 22)),
                              title: Text(f.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
                              subtitle: Text("${f.category} • ${f.startingMonth}+ ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                              onTap: () { onPick(f.name); Navigator.pop(ctx); },
                            )),
                      ],
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

  // ---------- articles manager ----------
  Widget _articlesManager() {
    final q = _articleSearch.text.trim().toLowerCase();
    final all = getAllArticles().where((a) => a.title.toLowerCase().contains(q) || a.summary.toLowerCase().contains(q)).toList();
    return _pane([
      _sectionHeader("Yazılar", "${getAllArticles().length} yazı • düzenle, sil veya yeni ekle",
          action: _primaryBtn("Yeni Yazı", Icons.add, () => _articleDialog(null))),
      _searchBar(_articleSearch, "Yazı ara...", (_) => setState(() {})),
      ...all.map((a) => _itemCard(
            leading: isPhotoUrl(a.imageUrl)
                ? photoOrFallback(a.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                : Container(color: const Color(0xFF2980B9).withOpacity(0.1), child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 20)))),
            title: a.title,
            subtitle: "${a.category} • ${a.readTime}",
            isCustom: isCustomArticle(a.id),
            onEdit: () => _articleDialog(a),
            onDelete: () => _confirmDelete("'${a.title}' yazısı", () {
              deleteArticle(a.id);
              _persistAll();
              setState(() {});
              _toast("Yazı silindi");
            }),
          )),
      if (all.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text("Sonuç yok.", style: TextStyle(fontFamily: 'Inter', color: _light))),
    ]);
  }

  void _articleDialog(Article? existing) {
    final title = TextEditingController(text: existing?.title ?? "");
    String image = existing?.imageUrl ?? "";
    String cat = existing?.category ?? articleCategories.first;
    final readTime = TextEditingController(text: existing?.readTime ?? "3 dk");
    final summary = TextEditingController(text: existing?.summary ?? "");
    final content = TextEditingController(text: existing?.content ?? "");
    final author = TextEditingController(text: existing?.author ?? "");
    final updatedDate = TextEditingController(text: existing?.updatedDate ?? "");
    final sponsorLabel = TextEditingController(text: existing?.sponsorLabel ?? "");
    bool sponsored = existing?.sponsored ?? false;
    // Bilimsel kaynaklar (başlık + URL).
    final sources = <Map<String, String>>[
      for (final s in (existing?.sources ?? const <Map<String, String>>[]))
        {"title": s["title"] ?? "", "url": s["url"] ?? ""}
    ];
    // Zengin içerik blokları (her birine düzenleyici-içi anahtar _k eklenir).
    var bkCounter = 0;
    final blocks = <Map<String, dynamic>>[
      for (final b in (existing?.blocks ?? const <Map<String, dynamic>>[])) {...Map<String, dynamic>.from(b), "_k": "k${bkCounter++}"}
    ];
    String newKey() => "k${bkCounter++}";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? "Yeni Yazı" : "Yazıyı Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhotoPickerField(value: image, label: "Kapak fotoğrafı", height: 130, onChanged: (v) => setD(() => image = v ?? "")),
                  const SizedBox(height: 14),
                  _field(title, "Başlık"),
                  _dropdown("Kategori", cat, articleCategories, (v) => setD(() => cat = v)),
                  _field(readTime, "Okuma süresi", hint: "3 dk"),
                  _field(summary, "Özet", maxLines: 2),
                  _field(author, "Hazırlayan", hint: "ör. Uzm. Dyt. Ayşe Yılmaz"),
                  _field(updatedDate, "Son güncelleme (AA.YYYY)", hint: "ör. 06.2026"),
                  _field(content, "İçerik (basit metin)", maxLines: 6),
                  const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 2),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Zengin İçerik (foto / video / YouTube + biçim)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Blok eklersen yazı bunlarla gösterilir; boşsa yukarıdaki basit metin kullanılır.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))),
                  ),
                  _articleBlockEditor(blocks, setD, newKey),
                  const Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 2),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Bilimsel Kaynaklar (referanslar)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _light))),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Yazının altında tıklanabilir liste olur (PubMed, WHO, Sağlık Bakanlığı…). En az bir kaynak eklenince 'Bilimsel kaynaklı' rozeti çıkar.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))),
                  ),
                  ...sources.asMap().entries.map((e) {
                    final i = e.key;
                    final s = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: TextEditingController(text: s["title"])..selection = TextSelection.collapsed(offset: (s["title"] ?? "").length),
                              decoration: _dec("Kaynak başlığı"),
                              onChanged: (v) => s["title"] = v,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: TextEditingController(text: s["url"])..selection = TextSelection.collapsed(offset: (s["url"] ?? "").length),
                              decoration: _dec("URL (https://...)"),
                              keyboardType: TextInputType.url,
                              onChanged: (v) => s["url"] = v,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: _red, size: 20), onPressed: () => setD(() => sources.removeAt(i))),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setD(() => sources.add({"title": "", "url": ""})),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Kaynak Ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Sponsorlu içerik", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
                    subtitle: const Text("Kartlarda ve detayda 'Sponsorlu' etiketi gösterilir", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                    value: sponsored,
                    activeColor: _primary,
                    onChanged: (v) => setD(() => sponsored = v),
                  ),
                  if (sponsored) _field(sponsorLabel, "Sponsor adı (marka)", hint: "ör. MarkaAdı"),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () async {
                final t = title.text.trim();
                if (t.isEmpty) {
                  _toast("Lütfen başlık girin");
                  return;
                }
                final nav = Navigator.of(ctx);
                final aid = existing?.id ?? "ac_${DateTime.now().millisecondsSinceEpoch}";
                final imgUrl = await _runSaving(() => _uploadCatalogImage("catalog/articles/$aid.jpg", image));
                // Blokları temizle: editör anahtarını at, yüklenen foto data-URI'lerini Storage'a yükle, boş blokları ele.
                final cleanBlocks = <Map<String, dynamic>>[];
                for (var i = 0; i < blocks.length; i++) {
                  final b = Map<String, dynamic>.from(blocks[i]);
                  b.remove("_k");
                  if (b["t"] == "image") {
                    final v = b["v"]?.toString() ?? "";
                    if (v.startsWith("data:")) {
                      b["v"] = await _runSaving(() => _uploadCatalogImage("catalog/articles/$aid/b$i.jpg", v));
                    }
                  }
                  if ((b["v"]?.toString() ?? "").trim().isEmpty) continue;
                  cleanBlocks.add(b);
                }
                saveArticleEdit(Article(
                  id: aid,
                  title: t,
                  category: cat,
                  readTime: readTime.text.trim().isEmpty ? "3 dk" : readTime.text.trim(),
                  summary: summary.text.trim(),
                  content: content.text.trim(),
                  emoji: existing?.emoji ?? "📝",
                  imageUrl: imgUrl,
                  sponsored: sponsored,
                  sponsorLabel: sponsorLabel.text.trim(),
                  author: author.text.trim(),
                  updatedDate: updatedDate.text.trim(),
                  sources: [
                    for (final s in sources)
                      if ((s["title"] ?? "").trim().isNotEmpty || (s["url"] ?? "").trim().isNotEmpty)
                        {"title": (s["title"] ?? "").trim(), "url": (s["url"] ?? "").trim()}
                  ],
                  blocks: cleanBlocks,
                ));
                _persistAll();
                nav.pop();
                if (mounted) setState(() {});
                _toast(existing == null ? "Yazı eklendi" : "Yazı güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [title, readTime, summary, content, author, updatedDate, sponsorLabel]) {
        c.dispose();
      }
    });
  }

  /// Zengin içerik blok editörü (metin renk/boyut, foto+genişlik, YouTube, video).
  Widget _articleBlockEditor(List<Map<String, dynamic>> blocks, StateSetter setD, String Function() newKey) {
    const palette = ["#2D2D3A", "#FF7A45", "#2BB673", "#E5484D", "#185FA5", "#8E8E9F"];
    const sizes = {"Küçük": 13.0, "Normal": 15.0, "Büyük": 18.0, "Başlık": 22.0};

    Widget iconBtn(IconData ic, VoidCallback? onTap, {Color color = _light}) => IconButton(
          icon: Icon(ic, size: 18, color: onTap == null ? const Color(0xFFD0D0D6) : color),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: onTap,
        );

    Widget blockCard(int i) {
      final b = blocks[i];
      final t = b["t"]?.toString() ?? "text";
      const labels = {"text": "Metin", "image": "Fotoğraf", "youtube": "YouTube", "video": "Video"};
      return Container(
        key: ValueKey(b["_k"]),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFAFAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(labels[t] ?? t, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
              const Spacer(),
              iconBtn(Icons.arrow_upward, i > 0 ? () => setD(() { final x = blocks.removeAt(i); blocks.insert(i - 1, x); }) : null),
              iconBtn(Icons.arrow_downward, i < blocks.length - 1 ? () => setD(() { final x = blocks.removeAt(i); blocks.insert(i + 1, x); }) : null),
              iconBtn(Icons.delete_outline, () => setD(() => blocks.removeAt(i)), color: _red),
            ]),
            const SizedBox(height: 6),
            if (t == "text") ...[
              TextFormField(
                initialValue: b["v"]?.toString() ?? "",
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                decoration: _dec("Metin"),
                onChanged: (v) => b["v"] = v,
              ),
              const SizedBox(height: 8),
              Row(children: [
                ...palette.map((c) {
                  final sel = (b["color"]?.toString() ?? "#2D2D3A") == c;
                  return GestureDetector(
                    onTap: () => setD(() => b["color"] = c),
                    child: Container(
                      width: 22, height: 22,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: Color(int.parse("FF${c.substring(1)}", radix: 16)), shape: BoxShape.circle, border: Border.all(color: sel ? _text : Colors.transparent, width: 2)),
                    ),
                  );
                }),
                const Spacer(),
                GestureDetector(
                  onTap: () => setD(() => b["bold"] = !(b["bold"] == true)),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: b["bold"] == true ? _primary : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E2E6))),
                    child: Icon(Icons.format_bold, size: 18, color: b["bold"] == true ? Colors.white : _light),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E2E6))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    isExpanded: true,
                    value: sizes.values.contains((b["size"] as num?)?.toDouble()) ? (b["size"] as num).toDouble() : 15.0,
                    items: sizes.entries.map((e) => DropdownMenuItem(value: e.value, child: Text("Yazı boyutu: ${e.key}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text)))).toList(),
                    onChanged: (v) => setD(() => b["size"] = v ?? 15.0),
                  ),
                ),
              ),
            ] else if (t == "image") ...[
              PhotoPickerField(value: b["v"]?.toString() ?? "", label: "Fotoğraf", height: 110, onChanged: (v) => setD(() => b["v"] = v ?? "")),
              const SizedBox(height: 6),
              Row(children: [
                const Text("Genişlik", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                Expanded(
                  child: Slider(
                    value: (((b["w"] as num?)?.toDouble() ?? 100).clamp(30, 100)),
                    min: 30, max: 100, divisions: 14, activeColor: _primary,
                    label: "%${((b["w"] as num?)?.toDouble() ?? 100).round()}",
                    onChanged: (v) => setD(() => b["w"] = v.round()),
                  ),
                ),
                Text("%${((b["w"] as num?)?.toDouble() ?? 100).round()}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _text)),
              ]),
            ] else ...[
              TextFormField(
                initialValue: b["v"]?.toString() ?? "",
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                decoration: _dec(t == "youtube" ? "YouTube linki (https://youtu.be/...)" : "Video (.mp4) linki"),
                onChanged: (v) => b["v"] = v,
              ),
            ],
          ],
        ),
      );
    }

    Widget addBtn(String label, IconData ic, VoidCallback onTap) => OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(ic, size: 16, color: _primary),
          label: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: _primary.withOpacity(0.4)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(blocks.length, blockCard),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: [
          addBtn("Metin", Icons.text_fields, () => setD(() => blocks.add({"_k": newKey(), "t": "text", "v": "", "color": "#2D2D3A", "size": 15.0, "bold": false}))),
          addBtn("Fotoğraf", Icons.image_outlined, () => setD(() => blocks.add({"_k": newKey(), "t": "image", "v": "", "w": 100}))),
          addBtn("YouTube", Icons.smart_display_outlined, () => setD(() => blocks.add({"_k": newKey(), "t": "youtube", "v": ""}))),
          addBtn("Video", Icons.movie_outlined, () => setD(() => blocks.add({"_k": newKey(), "t": "video", "v": ""}))),
        ]),
      ],
    );
  }

  // ---------- categories manager ----------
  Widget _catList(String title, List<String> cats, TextEditingController newCtrl, void Function(List<String>) save) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats
                  .map((c) => Container(
                        padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(c, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              final next = List<String>.from(cats)..remove(c);
                              save(next);
                            },
                            child: const Icon(Icons.close, size: 16, color: _light),
                          ),
                        ]),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: newCtrl,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                  decoration: _dec("Yeni kategori"),
                  onSubmitted: (_) {
                    final v = newCtrl.text.trim();
                    if (v.isNotEmpty && !cats.contains(v)) {
                      save(List<String>.from(cats)..add(v));
                      newCtrl.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              _primaryBtn("Ekle", Icons.add, () {
                final v = newCtrl.text.trim();
                if (v.isNotEmpty && !cats.contains(v)) {
                  save(List<String>.from(cats)..add(v));
                  newCtrl.clear();
                }
              }),
            ]),
          ],
        ),
      );

  Widget _categoriesManager() {
    return _pane([
      _sectionHeader("Kategoriler", "Gıda ve yazı kategorilerini yönet"),
      _catList("Gıda Kategorileri", foodCategories, _newFoodCat, (next) {
        setState(() => globalAdminConfig["foodCategories"] = next);
        StorageService.instance.saveAdminContent();
      }),
      const SizedBox(height: 16),
      _catList("Yazı Kategorileri", articleCategories, _newArticleCat, (next) {
        setState(() => globalAdminConfig["articleCategories"] = next);
        StorageService.instance.saveAdminContent();
      }),
    ]);
  }

  // ---------- defaults manager (supplements + avatars) ----------
  Widget _defaultsManager() {
    final supps = defaultSupplements;
    return _pane([
      _sectionHeader("Varsayılanlar", "Yeni bebeklere eklenen takviyeler ve avatar listesi"),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text("Varsayılan Takviyeler", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
              TextButton.icon(onPressed: () => _suppDialog(null), icon: const Icon(Icons.add, size: 16, color: _primary), label: const Text("Ekle", style: TextStyle(fontFamily: 'Inter', color: _primary, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 8),
            if (supps.isEmpty) const Text("Henüz yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
            ...supps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.wb_sunny_outlined, size: 18, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text("${e.value["name"]}  ·  ${e.value["dose"] ?? ""}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text))),
                    GestureDetector(
                      onTap: () {
                        final next = List<Map<String, dynamic>>.from(supps)..removeAt(e.key);
                        setState(() => globalAdminConfig["defaultSupplements"] = next);
                        StorageService.instance.saveAdminContent();
                      },
                      child: const Icon(Icons.delete_outline, size: 18, color: _red),
                    ),
                  ]),
                )),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Avatar Emojileri", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: avatarOptions
                  .map((a) => Container(
                        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(a, style: const TextStyle(fontSize: 20)),
                          GestureDetector(
                            onTap: () {
                              final next = List<String>.from(avatarOptions)..remove(a);
                              setState(() => globalAdminConfig["avatars"] = next);
                              StorageService.instance.saveAdminContent();
                            },
                            child: const Icon(Icons.close, size: 14, color: _light),
                          ),
                        ]),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _newAvatar,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 18, color: _text),
                  textAlign: TextAlign.center,
                  decoration: _dec("Emoji"),
                ),
              ),
              const SizedBox(width: 10),
              _primaryBtn("Ekle", Icons.add, () {
                final v = _newAvatar.text.trim();
                if (v.isNotEmpty && !avatarOptions.contains(v)) {
                  setState(() => globalAdminConfig["avatars"] = List<String>.from(avatarOptions)..add(v));
                  StorageService.instance.saveAdminContent();
                  _newAvatar.clear();
                }
              }),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Takviye / İlaç Adları",
        subtitle: "Ekleme formunda seçilebilecek hazır adlar",
        options: supplementNameOptions,
        controller: _newSuppName,
        hint: "Örn. K Vitamini",
        onSave: (next) => globalAdminConfig["supplementNames"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Doz Birimleri",
        subtitle: "Doz miktarı yanında çıkacak birimler (damla, ml, puf…)",
        options: doseUnitOptions,
        controller: _newDoseUnit,
        hint: "Örn. puf",
        onSave: (next) => globalAdminConfig["doseUnits"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Sepet Birimleri",
        subtitle: "Gıda formundaki 'Sepet birimi' seçeneğinde çıkacak birimler (adet, kg, demet…)",
        options: cartUnitOptions,
        controller: _newCartUnit,
        hint: "Örn. demet",
        onSave: (next) => globalAdminConfig["cartUnits"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Tarif Birimleri",
        subtitle: "Tarif malzemesi miktarındaki birim seçeneği (gr, ml, yemek kaşığı…)",
        options: recipeUnitOptions,
        controller: _newRecipeUnit,
        hint: "Örn. su bardağı",
        onSave: (next) => globalAdminConfig["recipeUnits"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Tarif Kategorileri",
        subtitle: "Tarif ekleme/filtre ekranlarında çıkacak kategoriler (Püreler, Çorbalar…)",
        options: recipeCategoryOptions,
        controller: _newRecipeCat,
        hint: "Örn. Bebek Smoothie'leri",
        onSave: (next) => globalAdminConfig["recipeCategories"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Topluluk Kategorileri",
        subtitle: "Toplulukta gönderi açarken/filtrede çıkacak kategoriler (Uyku, Alerji…)",
        options: communityCategoryOptions,
        controller: _newCommunityCat,
        hint: "Örn. Kreş & Bakıcı",
        onSave: (next) => globalAdminConfig["communityCategories"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Formül Mama Adları",
        subtitle: "Takvim beslenme takibinde seçilebilecek mama markaları",
        options: formulaNameOptions,
        controller: _newFormulaName,
        hint: "Örn. Aptamil",
        onSave: (next) => globalAdminConfig["formulaNames"] = next,
      ),
      const SizedBox(height: 16),
      _chipListCard(
        title: "Mama Ölçü Birimleri",
        subtitle: "Beslenme miktarı yanında çıkacak birimler (ml, ölçek, dakika…)",
        options: feedingUnitOptions,
        controller: _newFeedingUnit,
        hint: "Örn. ml",
        onSave: (next) => globalAdminConfig["feedingUnits"] = next,
      ),
      const SizedBox(height: 16),
      _promoCodeManager(),
    ]);
  }

  /// Premium promosyon kodları: kod + süre. Kullanıcı premium ekranında girer.
  Widget _promoCodeManager() {
    const durations = {"7 gün": 7, "1 ay": 30, "3 ay": 90, "6 ay": 180, "1 yıl": 365, "Sınırsız": -1};
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Premium Kodları", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 2),
          const Text("Kullanıcı premium ekranında bu kodu girince seçtiğin süre kadar premium açılır.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
          const SizedBox(height: 12),
          if (promoCodes.isEmpty)
            const Text("Henüz kod yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: promoCodes.map((p) {
                final code = p["code"]?.toString() ?? "";
                final days = (p["days"] as num?)?.toInt() ?? 0;
                return Container(
                  padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("$code · ${days < 0 ? "Sınırsız" : "$days gün"}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
                    GestureDetector(
                      onTap: () {
                        final next = List<Map<String, dynamic>>.from(promoCodes)..removeWhere((x) => x["code"] == p["code"]);
                        setState(() => globalAdminConfig["promoCodes"] = next);
                        StorageService.instance.saveAdminContent();
                      },
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.close, size: 14, color: _light)),
                    ),
                  ]),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_newPromoCode, "Kod", hint: "ör. ANNE7")),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _newPromoDays,
                  items: durations.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text)))).toList(),
                  onChanged: (v) => setState(() => _newPromoDays = v ?? 7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _primaryBtn("Ekle", Icons.add, () {
              final code = _newPromoCode.text.trim().toUpperCase();
              if (code.isEmpty) return;
              final list = List<Map<String, dynamic>>.from(promoCodes);
              if (list.any((p) => (p["code"]?.toString().toUpperCase() ?? "") == code)) {
                _toast("Bu kod zaten var");
                return;
              }
              list.add({"code": code, "days": _newPromoDays});
              setState(() => globalAdminConfig["promoCodes"] = list);
              StorageService.instance.saveAdminContent();
              _newPromoCode.clear();
              _toast("Kod eklendi: $code");
            }),
          ]),
        ],
      ),
    );
  }

  /// A reusable card that manages an editable list of string chips backed by a
  /// globalAdminConfig key.
  Widget _chipListCard({
    required String title,
    required String subtitle,
    required List<String> options,
    required TextEditingController controller,
    required String hint,
    required void Function(List<String> next) onSave,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((o) => Container(
                      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(o, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            final next = List<String>.from(options)..remove(o);
                            setState(() => onSave(next));
                            StorageService.instance.saveAdminContent();
                          },
                          child: const Icon(Icons.close, size: 14, color: _light),
                        ),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(width: 200, child: TextField(controller: controller, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text), decoration: _dec(hint))),
            const SizedBox(width: 10),
            _primaryBtn("Ekle", Icons.add, () {
              final v = controller.text.trim();
              if (v.isNotEmpty && !options.contains(v)) {
                setState(() => onSave(List<String>.from(options)..add(v)));
                StorageService.instance.saveAdminContent();
                controller.clear();
              }
            }),
          ]),
        ],
      ),
    );
  }

  // ---------- comment moderation ----------
  List<Map<String, dynamic>>? _pendingComments;

  Future<void> _reloadPendingComments() async {
    final list = await SocialSync.instance.loadPendingComments();
    if (mounted) setState(() => _pendingComments = list);
  }

  Widget _commentsManager() {
    // Lazy-load pending comments from Firestore the first time this opens.
    if (_pendingComments == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingComments == null) _reloadPendingComments();
      });
      return _pane([
        _sectionHeader("Yorum Onayı", "Yükleniyor…"),
        _card(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primary)))),
      ]);
    }

    final pending = _pendingComments!;
    String recipeName(String rid) {
      final m = globalRecipesDatabase.where((r) => r.id == rid).toList();
      return m.isNotEmpty ? m.first.name : "Tarif";
    }

    return _pane([
      Row(children: [
        Expanded(child: _sectionHeader("Yorum Onayı", "${pending.length} yorum onay bekliyor")),
        IconButton(tooltip: "Yenile", icon: const Icon(Icons.refresh, color: _primary), onPressed: _reloadPendingComments),
      ]),
      if (pending.isEmpty)
        _card(child: const Text("Onay bekleyen yorum yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...pending.map((c) {
        final id = c["id"]?.toString() ?? "";
        final rid = c["recipeId"]?.toString() ?? "";
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.restaurant_menu, size: 16, color: _primary),
                const SizedBox(width: 6),
                Expanded(child: Text("${recipeName(rid)}  •  ${c["name"]?.toString() ?? "Kullanıcı"}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text))),
                Text(c["date"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
              ]),
              const SizedBox(height: 8),
              if ((c["text"]?.toString() ?? "").isNotEmpty)
                Text(c["text"].toString(), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.4)),
              if (isPhotoUrl(c["photo"])) ...[
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 120, child: photoOrFallback(c["photo"], fallback: const SizedBox(), fit: BoxFit.cover))),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await SocialSync.instance.approveComment(id);
                      final toUid = c["uid"]?.toString() ?? "";
                      if (toUid.isNotEmpty) {
                        await SocialSync.instance.sendNotification(toUid, "Yorumun onaylandı 💬", "Bir tarife yaptığın yorum yayınlandı.", type: 'comment');
                      }
                      if (mounted) setState(() => _pendingComments!.remove(c));
                      _toast("Yorum onaylandı");
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Onayla", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SocialSync.instance.rejectComment(id);
                      if (mounted) setState(() => _pendingComments!.remove(c));
                      _toast("Yorum reddedildi");
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reddet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    ]);
  }

  // ---------- user-submitted recipe approval ----------
  List<Map<String, dynamic>>? _pendingRecipesList;

  Future<void> _reloadPendingRecipes() async {
    final list = await SocialSync.instance.loadPendingRecipes();
    if (mounted) setState(() => _pendingRecipesList = list);
  }

  Widget _recipesApprovalManager() {
    if (_pendingRecipesList == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingRecipesList == null) _reloadPendingRecipes();
      });
      return _pane([
        _sectionHeader("Tarif Onayı", "Yükleniyor…"),
        _card(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primary)))),
      ]);
    }
    final pending = _pendingRecipesList!;
    return _pane([
      Row(children: [
        Expanded(child: _sectionHeader("Tarif Onayı", "${pending.length} kullanıcı tarifi onay bekliyor")),
        IconButton(tooltip: "Yenile", icon: const Icon(Icons.refresh, color: _primary), onPressed: _reloadPendingRecipes),
      ]),
      if (pending.isEmpty)
        _card(child: const Text("Onay bekleyen tarif yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...pending.map((p) {
        final name = p["name"]?.toString() ?? "Tarif";
        final by = p["submittedBy"]?.toString() ?? "";
        final date = p["date"]?.toString() ?? "";
        final img = p["imageUrl"]?.toString() ?? "";
        final ings = (p["ingredients"] as List?)?.length ?? 0;
        final steps = (p["steps"] as List?)?.length ?? 0;
        final month = (p["startingMonth"] as num?)?.toInt() ?? 6;
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.menu_book, size: 16, color: _primary),
                const SizedBox(width: 6),
                Expanded(child: Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
                Text(date, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
              ]),
              const SizedBox(height: 4),
              Text("@$by • $month+ Ay • $ings malzeme • $steps adım", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              if (isPhotoUrl(img)) ...[
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 120, width: double.infinity, child: photoOrFallback(img, fallback: const SizedBox(), fit: BoxFit.cover))),
              ],
              if ((p["allergyWarning"]?.toString() ?? "").isNotEmpty) ...[
                const SizedBox(height: 8),
                Text("⚠️ ${p["allergyWarning"]}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _recipeDialog(p, pending: p),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("İncele / Düzenle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final docId = p["_docId"]?.toString() ?? "";
                      final recipe = Recipe.fromJson(p);
                      if (!globalRecipesDatabase.any((x) => x.id == recipe.id)) {
                        globalRecipesDatabase.add(recipe);
                      }
                      if (!globalCustomRecipes.any((m) => m["id"] == recipe.id)) {
                        globalCustomRecipes.add(recipe.toJson());
                      }
                      _persistAll(); // saves custom content → pushes to /catalog
                      final toUid = p["uid"]?.toString() ?? "";
                      if (toUid.isNotEmpty) {
                        await SocialSync.instance.sendNotification(toUid, "Tarifin onaylandı! 🎉", "\"$name\" tarifin yayınlandı.", type: 'recipe');
                      }
                      if (docId.isNotEmpty) await SocialSync.instance.deletePendingRecipe(docId);
                      if (mounted) setState(() => _pendingRecipesList!.remove(p));
                      _toast("Tarif onaylandı ve yayınlandı");
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Onayla", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final docId = p["_docId"]?.toString() ?? "";
                      if (docId.isNotEmpty) await SocialSync.instance.deletePendingRecipe(docId);
                      if (mounted) setState(() => _pendingRecipesList!.remove(p));
                      _toast("Tarif reddedildi");
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reddet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    ]);
  }

  // ---------- topluluk moderasyonu ----------
  List<CommunityPost>? _pendingCommunityPosts;
  List<CommunityPost>? _reportedCommunityPosts;
  List<CommunityPost>? _publishedCommunityPosts;

  Future<void> _reloadCommunity() async {
    final pend = await CommunitySync.instance.loadPendingPosts();
    final rep = await CommunitySync.instance.loadReportedPosts();
    await CommunitySync.instance.loadPosts(); // yayındakiler → globalCommunityPosts
    if (mounted) {
      setState(() {
        _pendingCommunityPosts = pend;
        _reportedCommunityPosts = rep;
        _publishedCommunityPosts = List<CommunityPost>.from(globalCommunityPosts);
      });
    }
  }

  Widget _communityManager() {
    if (_pendingCommunityPosts == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (_pendingCommunityPosts == null) _reloadCommunity(); });
      return _pane([
        _sectionHeader("Topluluk", "Yükleniyor…"),
        _card(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primary)))),
      ]);
    }
    final pending = _pendingCommunityPosts!;
    final reported = _reportedCommunityPosts ?? [];
    final published = _publishedCommunityPosts ?? [];
    return _pane([
      Row(children: [
        Expanded(child: _sectionHeader("Topluluk", "${pending.length} onay bekliyor • ${reported.length} şikayet • ${published.length} yayında")),
        IconButton(tooltip: "Yenile", icon: const Icon(Icons.refresh, color: _primary), onPressed: _reloadCommunity),
      ]),
      const Padding(padding: EdgeInsets.only(top: 4, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("Onay Bekleyen Gönderiler", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)))),
      if (pending.isEmpty) _card(child: const Text("Onay bekleyen gönderi yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...pending.map((p) => _communityPostCard(p, mode: "pending")),
      const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("Şikayet Edilen Gönderiler", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)))),
      if (reported.isEmpty) _card(child: const Text("Şikayet edilen gönderi yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...reported.map((p) => _communityPostCard(p, mode: "reported")),
      const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text("Yayındaki Gönderiler", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)))),
      if (published.isEmpty) _card(child: const Text("Yayında gönderi yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...published.map((p) => _communityPostCard(p, mode: "published")),
    ]);
  }

  Widget _communityPostCard(CommunityPost p, {required String mode}) {
    final pendingMode = mode == "pending";
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.forum_outlined, size: 16, color: _primary),
            const SizedBox(width: 6),
            Expanded(child: Text(p.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
            if (mode == "published" && p.pinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, size: 14, color: _primary)),
            if (mode == "reported" && p.reportCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _red.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text("${p.reportCount} şikayet", style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _red))),
          ]),
          const SizedBox(height: 4),
          Text("${p.anonymous ? "Anonim" : "@${p.authorName}"} • ${p.category}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
          if (p.body.trim().isNotEmpty) ...[const SizedBox(height: 6), Text(p.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5A5A6A), height: 1.4))],
          if (isPhotoUrl(p.imageUrl)) ...[const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 120, width: double.infinity, child: photoOrFallback(p.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)))],
          if (p.hasPoll) ...[const SizedBox(height: 6), Text("📊 Anket: ${p.pollOptions.join(" / ")}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _communityPostDialog(p, pendingMode: pendingMode),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text("İncele / Düzenle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (mode == "pending") ...[
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  await CommunitySync.instance.approvePost(p.id);
                  if (mounted) setState(() => _pendingCommunityPosts!.remove(p));
                  _toast("Gönderi onaylandı ve yayınlandı");
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text("Onayla", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
            ] else if (mode == "reported") ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await CommunitySync.instance.setHidden(p.id, true);
                  if (mounted) setState(() => _reportedCommunityPosts!.remove(p));
                  _toast("Gönderi gizlendi");
                },
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text("Gizle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await CommunitySync.instance.setHidden(p.id, false);
                  if (mounted) setState(() => _reportedCommunityPosts!.remove(p));
                  _toast("Şikayet temizlendi (yayında kaldı)");
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text("Sorun yok", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF10B981), side: const BorderSide(color: Color(0xFF10B981)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
            ] else ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await CommunitySync.instance.setPinned(p.id, !p.pinned);
                  await _reloadCommunity();
                  _toast(p.pinned ? "Sabit kaldırıldı" : "Gönderi sabitlendi");
                },
                icon: Icon(p.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                label: Text(p.pinned ? "Sabiti Kaldır" : "Sabitle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
            ],
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                await CommunitySync.instance.deletePost(p.id);
                if (mounted) setState(() { _pendingCommunityPosts?.remove(p); _reportedCommunityPosts?.remove(p); _publishedCommunityPosts?.remove(p); });
                _toast(pendingMode ? "Gönderi reddedildi" : "Gönderi silindi");
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(pendingMode ? "Reddet" : "Sil", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
          ]),
        ],
      ),
    );
  }

  /// Topluluk gönderisini incele/düzenle (tarif onayındaki gibi). pendingMode ise
  /// kaydet düğmesi 'Onayla ve Yayınla' olur.
  void _communityPostDialog(CommunityPost p, {required bool pendingMode}) {
    final titleC = TextEditingController(text: p.title);
    final bodyC = TextEditingController(text: p.body);
    String cat = communityCategoryOptions.contains(p.category) ? p.category : communityCategoryOptions.first;
    String image = p.imageUrl;
    bool anonymous = p.anonymous;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(pendingMode ? "Gönderiyi İncele / Onayla" : "Gönderiyi Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text("@${p.authorName}${p.anonymous ? " (anonim)" : ""} • ${communityTimeAgo(p.createdMs)}", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))),
                  const SizedBox(height: 10),
                  PhotoPickerField(value: image, label: "Fotoğraf", height: 130, onChanged: (v) => setD(() => image = v ?? "")),
                  const SizedBox(height: 12),
                  _field(titleC, "Başlık"),
                  _dropdown("Kategori", cat, communityCategoryOptions, (v) => setD(() => cat = v)),
                  _field(bodyC, "Metin", maxLines: 6),
                  if (p.hasPoll)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerLeft, child: Text("📊 Anket: ${p.pollOptions.join(" / ")}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)))),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Anonim göster", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
                    value: anonymous,
                    activeColor: _primary,
                    onChanged: (v) => setD(() => anonymous = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                var imgUrl = image;
                if (isPhotoUrl(imgUrl) && imgUrl.startsWith('data:')) {
                  imgUrl = await _runSaving(() => _uploadCatalogImage("community/${p.id}.jpg", image));
                }
                await CommunitySync.instance.updatePost(p.id, {
                  'title': titleC.text.trim(),
                  'body': bodyC.text.trim(),
                  'category': cat,
                  'imageUrl': imgUrl,
                  'anonymous': anonymous,
                  if (pendingMode) 'approved': true,
                });
                nav.pop();
                await _reloadCommunity();
                _toast(pendingMode ? "Gönderi onaylandı ve yayınlandı" : "Gönderi güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: pendingMode ? const Color(0xFF10B981) : _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(pendingMode ? "Onayla ve Yayınla" : "Kaydet", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleC.dispose();
      bodyC.dispose();
    });
  }

  // ---------- expert verification approval ----------
  List<Map<String, dynamic>>? _pendingExpertList;

  Future<void> _reloadPendingExperts() async {
    final list = await SocialSync.instance.loadPendingExpertRequests();
    if (mounted) setState(() => _pendingExpertList = list);
  }

  Widget _expertApprovalManager() {
    if (_pendingExpertList == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pendingExpertList == null) _reloadPendingExperts();
      });
      return _pane([
        _sectionHeader("Uzman Onayı", "Yükleniyor…"),
        _card(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primary)))),
      ]);
    }
    final pending = _pendingExpertList!;
    return _pane([
      Row(children: [
        Expanded(child: _sectionHeader("Uzman Onayı", "${pending.length} uzman etiketi talebi bekliyor")),
        IconButton(tooltip: "Yenile", icon: const Icon(Icons.refresh, color: _primary), onPressed: _reloadPendingExperts),
      ]),
      if (pending.isEmpty)
        _card(child: const Text("Onay bekleyen talep yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...pending.map((p) {
        final username = p["username"]?.toString() ?? "";
        final type = p["type"]?.toString() ?? "";
        final uni = p["university"]?.toString() ?? "";
        final diploma = p["diploma"]?.toString() ?? "";
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF2BB673)),
                const SizedBox(width: 6),
                Expanded(child: Text("@$username · $type", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
              ]),
              const SizedBox(height: 6),
              Text("Üniversite: $uni", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              Text("Diploma no: $diploma", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final docId = p["_docId"]?.toString() ?? "";
                      final uid = p["uid"]?.toString() ?? "";
                      await SocialSync.instance.approveExpertRequest(docId, uid: uid, username: username, type: type);
                      if (mounted) setState(() => _pendingExpertList!.remove(p));
                      _toast("Uzman etiketi onaylandı: @$username");
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Onayla", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final docId = p["_docId"]?.toString() ?? "";
                      if (docId.isNotEmpty) await SocialSync.instance.rejectExpertRequest(docId);
                      if (mounted) setState(() => _pendingExpertList!.remove(p));
                      _toast("Talep reddedildi");
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("Reddet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    ]);
  }

  // ---------- market links / ads manager ----------
  Widget _marketLinksManager() {
    final links = marketLinks;
    return _pane([
      _sectionHeader("İndirim Fırsatları", "Sepet ekranındaki indirim / affiliate kartları",
          action: _primaryBtn("Yeni", Icons.add, () => _marketLinkDialog(null))),
      if (links.isEmpty)
        _card(child: const Text("Henüz reklam kartı yok. 'Yeni' ile ekleyin.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light))),
      ...links.asMap().entries.map((e) {
        final i = e.key;
        final l = e.value;
        final img = l["imageUrl"]?.toString() ?? "";
        return _card(
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: isPhotoUrl(img) ? photoOrFallback(img, fallback: const Icon(Icons.storefront, color: _light)) : const Icon(Icons.storefront, color: _light),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l["name"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                const SizedBox(height: 2),
                Text(l["url"]?.toString() ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: _primary), onPressed: () => _marketLinkDialog(i)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: _red),
              onPressed: () {
                final next = List<Map<String, dynamic>>.from(marketLinks)..removeAt(i);
                setState(() => globalAdminConfig["marketLinks"] = next);
                StorageService.instance.saveAdminContent();
              },
            ),
          ]),
        );
      }),
    ]);
  }

  void _marketLinkDialog(int? index) {
    final existing = index != null ? marketLinks[index] : null;
    final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
    final url = TextEditingController(text: existing?["url"]?.toString() ?? "");
    final discount = TextEditingController(text: existing?["discount"]?.toString() ?? "");
    final subtitle = TextEditingController(text: existing?["subtitle"]?.toString() ?? "");
    final pages = <String>{...((existing?["pages"] as List?)?.map((e) => e.toString()) ?? const <String>[])};
    String image = existing?["imageUrl"]?.toString() ?? "";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(index == null ? "Yeni Fırsat" : "Fırsatı Düzenle", style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                PhotoPickerField(value: image, label: "Görsel (opsiyonel)", height: 120, onChanged: (v) => setD(() => image = v ?? "")),
                const SizedBox(height: 14),
                _field(name, "Ad", hint: "Örn. Getir Büyük"),
                _field(url, "Bağlantı (URL)", hint: "https://..."),
                _field(discount, "İndirim rozeti (opsiyonel)", hint: "Örn. %40"),
                _field(subtitle, "Alt başlık (opsiyonel)", hint: "Örn. Bebek ürünlerinde fırsat"),
                const SizedBox(height: 4),
                const Align(alignment: Alignment.centerLeft, child: Text("Gösterilecek sayfalar (boş = hepsi)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _light))),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: {"home": "Ana Sayfa", "cart": "Sepet", "calendar": "Takvim"}.entries.map((e) {
                      final sel = pages.contains(e.key);
                      return FilterChip(
                        label: Text(e.value, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: sel ? Colors.white : _text)),
                        selected: sel,
                        showCheckmark: false,
                        selectedColor: _primary,
                        backgroundColor: _bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: sel ? _primary : const Color(0xFFE2E2E6))),
                        onSelected: (v) => setD(() { if (v) { pages.add(e.key); } else { pages.remove(e.key); } }),
                      );
                    }).toList(),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  _toast("Ad girin");
                  return;
                }
                final data = {"name": n, "url": url.text.trim(), "imageUrl": image, "discount": discount.text.trim(), "subtitle": subtitle.text.trim(), "pages": pages.toList()};
                final next = List<Map<String, dynamic>>.from(marketLinks);
                if (index != null) {
                  next[index] = data;
                } else {
                  next.add(data);
                }
                setState(() => globalAdminConfig["marketLinks"] = next);
                StorageService.instance.saveAdminContent();
                Navigator.pop(ctx);
                _toast(index == null ? "Fırsat eklendi" : "Güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      name.dispose();
      url.dispose();
      discount.dispose();
      subtitle.dispose();
    });
  }

  void _suppDialog(Map<String, dynamic>? existing) {
    final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
    final dose = TextEditingController(text: existing?["dose"]?.toString() ?? "");
    final schedule = TextEditingController(text: existing?["schedule"]?.toString() ?? "Her gün");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Varsayılan Takviye", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(name, "Ad", hint: "D Vitamini"),
            _field(dose, "Doz", hint: "3 damla"),
            _field(schedule, "Program", hint: "Her gün"),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
          ElevatedButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) {
                _toast("Ad girin");
                return;
              }
              final next = List<Map<String, dynamic>>.from(defaultSupplements);
              next.add({"name": n, "dose": dose.text.trim(), "schedule": schedule.text.trim(), "type": "takviye", "active": true});
              setState(() => globalAdminConfig["defaultSupplements"] = next);
              StorageService.instance.saveAdminContent();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Ekle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      name.dispose();
      dose.dispose();
      schedule.dispose();
    });
  }

  // ---------- nutrition targets manager ----------
  static const Map<String, String> _ntLabels = {
    "infantEnergyPerKg": "Bebek (<12 ay) Enerji (kcal/kg)",
    "infantProteinPerKg": "Bebek Protein (g/kg)",
    "infantFatPerKg": "Bebek Yağ (g/kg)",
    "infantIron": "Bebek Demir (mg/gün)",
    "toddlerEnergyPerKg": "12+ ay Enerji (kcal/kg)",
    "toddlerProteinPerKg": "12+ ay Protein (g/kg)",
    "toddlerFatPerKg": "12+ ay Yağ (g/kg)",
    "toddlerIron": "12+ ay Demir (mg/gün)",
    "energyMin": "Enerji alt sınır",
    "energyMax": "Enerji üst sınır",
    "proteinMin": "Protein alt sınır",
    "proteinMax": "Protein üst sınır",
    "fatMin": "Yağ alt sınır",
    "fatMax": "Yağ üst sınır",
  };

  Widget _nutritionManager() {
    return _pane([
      _sectionHeader("Beslenme Hedefleri", "Yaşa/kiloya göre günlük makro hedef formülleri",
          action: TextButton.icon(
            onPressed: () {
              setState(() {
                globalAdminConfig.remove("nutritionTargets");
                for (final k in kDefaultNutritionTargets.keys) {
                  _nt[k]!.text = _trimNum(kDefaultNutritionTargets[k]!);
                }
              });
              StorageService.instance.saveAdminContent();
              _toast("Varsayılana sıfırlandı");
            },
            icon: const Icon(Icons.restart_alt, size: 16, color: _light),
            label: const Text("Sıfırla", style: TextStyle(fontFamily: 'Inter', color: _light, fontWeight: FontWeight.bold)),
          )),
      _card(
        child: Column(
          children: [
            ..._ntLabels.entries.map((e) => _field(_nt[e.key]!, e.value, keyboard: TextInputType.number)),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: _primaryBtn("Kaydet", Icons.save_outlined, () {
                final map = <String, double>{};
                for (final k in kDefaultNutritionTargets.keys) {
                  map[k] = double.tryParse(_nt[k]!.text.trim().replaceAll(',', '.')) ?? kDefaultNutritionTargets[k]!;
                }
                globalAdminConfig["nutritionTargets"] = map;
                StorageService.instance.saveAdminContent();
                _toast("Beslenme hedefleri kaydedildi");
              }),
            ),
          ],
        ),
      ),
    ]);
  }
}
