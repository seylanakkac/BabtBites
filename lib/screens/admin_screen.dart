import 'package:flutter/material.dart';
import '../data/admin_store.dart';
import '../data/food_database.dart';
import '../services/storage_service.dart';
import '../widgets/image_helpers.dart';
import 'articles_screen.dart';

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
  final _recipeSearch = TextEditingController();
  final _articleSearch = TextEditingController();
  final _newFoodCat = TextEditingController();
  final _newArticleCat = TextEditingController();
  final _newAvatar = TextEditingController();
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
    final extended = MediaQuery.of(context).size.width > 1080;
    const destinations = [
      (Icons.dashboard_outlined, "Genel Bakış"),
      (Icons.restaurant, "Gıdalar"),
      (Icons.menu_book, "Tarifler"),
      (Icons.article_outlined, "Yazılar"),
      (Icons.category_outlined, "Kategoriler"),
      (Icons.tune, "Varsayılanlar"),
      (Icons.monitor_heart_outlined, "Beslenme"),
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              color: Colors.white,
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
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: "Çıkış",
                        icon: const Icon(Icons.logout, color: _red),
                        onPressed: _logout,
                      ),
                    ),
                  ),
                ),
                destinations: destinations
                    .map((d) => NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)))
                    .toList(),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEDEDED)),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  void _logout() {
    setAdminMode(false);
    StorageService.instance.saveIsAdmin(false);
    Navigator.of(context).pushReplacementNamed('/login');
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
    final babyCount = StorageService.instance.loadBabies()?.length ?? 0;
    return _pane([
      _sectionHeader("Genel Bakış", "İçerik ve kullanım istatistikleri"),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _statCard("${globalFoodsDatabase.length}", "Toplam Gıda", _green, Icons.restaurant),
        _statCard("${globalRecipesDatabase.length}", "Toplam Tarif", _primary, Icons.menu_book),
        _statCard("${globalCustomArticles.length}", "Özel Yazı", const Color(0xFF2980B9), Icons.article_outlined),
        _statCard("${globalCustomFoods.length}", "Özel Gıda", const Color(0xFF8B5E3C), Icons.add_box_outlined),
        _statCard("${globalCustomRecipes.length}", "Özel Tarif", const Color(0xFFD4AC0D), Icons.add_box_outlined),
        _statCard("$babyCount", "Kayıtlı Bebek", _red, Icons.child_care),
      ]),
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

  // ---------- generic list item ----------
  Widget _itemCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required bool isCustom,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
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
                      const SizedBox(width: 8),
                      Flexible(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
                    ],
                  ),
                ],
              ),
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
  Widget _foodsManager() {
    final q = _foodSearch.text.trim().toLowerCase();
    final foods = globalFoodsDatabase.where((f) => f.name.toLowerCase().contains(q)).toList();
    return _pane([
      _sectionHeader("Gıdalar", "${globalFoodsDatabase.length} gıda • düzenle, sil veya yeni ekle",
          action: _primaryBtn("Yeni Gıda", Icons.add, () => _foodDialog(null))),
      _searchBar(_foodSearch, "Gıda ara...", (_) => setState(() {})),
      ...foods.map((f) => _itemCard(
            leading: isPhotoUrl(f.imageUrl)
                ? photoOrFallback(f.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                : Container(color: const Color(0xFFFAF9F6), child: Center(child: Text(f.emoji, style: const TextStyle(fontSize: 22)))),
            title: f.name,
            subtitle: "${f.category} • ${f.startingMonth}+ ay • Alerji: ${f.allergyRisk}",
            isCustom: isCustomFood(f.name),
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
    final ps = (existing?["presentationStyles"] as Map?);
    final presentation = TextEditingController(text: ps != null && ps.values.isNotEmpty ? ps.values.first.toString() : "");
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
                  _field(presentation, "Sunum şekli", maxLines: 3),
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
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  _toast("Lütfen ad girin");
                  return;
                }
                final m = int.tryParse(month.text.trim()) ?? 6;
                double pn(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
                saveFoodEdit({
                  "name": n,
                  "emoji": existing?["emoji"]?.toString() ?? "🍽️",
                  "category": cat,
                  "startingMonth": m,
                  "allergyRisk": risk,
                  "imageUrl": image,
                  "presentationStyles": {m.toString(): presentation.text.trim()},
                  "nutritionValues": {
                    "Enerji": pn(energy), "Karbonhidrat": pn(carb), "Protein": pn(protein), "Yağ": pn(fat),
                    "Lif": pn(fiber), "Kolesterol": pn(chol), "Sodyum": pn(sodium), "Potasyum": pn(potassium),
                    "Kalsiyum": pn(calcium), "Vitamin A": pn(vitA), "Vitamin C": pn(vitC), "Demir": pn(iron),
                  },
                });
                _persistAll();
                Navigator.pop(ctx);
                setState(() {});
                _toast(existing == null ? "$n eklendi" : "$n güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [name, month, presentation, energy, carb, protein, fat, fiber, chol, sodium, potassium, calcium, vitA, vitC, iron]) {
        c.dispose();
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
            subtitle: "${r.startingMonth}+ ay • ${r.prepTime} • ${r.kcal.toInt()} kcal",
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

  void _recipeDialog(Map<String, dynamic>? existing) {
    final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
    String image = existing?["imageUrl"]?.toString() ?? "";
    final prep = TextEditingController(text: existing?["prepTime"]?.toString() ?? "15 dk");
    final month = TextEditingController(text: "${existing?["startingMonth"] ?? 6}");
    final kcal = TextEditingController(text: existing?["kcal"]?.toString() ?? "");
    final ing = TextEditingController(text: ((existing?["ingredients"] as List?) ?? []).join(", "));
    final amt = TextEditingController(text: ((existing?["ingredientAmounts"] as List?) ?? []).join(", "));
    final steps = TextEditingController(text: ((existing?["steps"] as List?) ?? []).join("\n"));
    final warn = TextEditingController(text: existing?["allergyWarning"]?.toString() ?? "");

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
                children: [
                  PhotoPickerField(value: image, label: "Tarif fotoğrafı", height: 130, onChanged: (v) => setD(() => image = v ?? "")),
                  const SizedBox(height: 14),
                  _field(name, "Tarif adı"),
                  Row(children: [Expanded(child: _field(prep, "Hazırlık", hint: "15 dk")), const SizedBox(width: 10), Expanded(child: _field(month, "Ay", hint: "6", keyboard: TextInputType.number))]),
                  _field(kcal, "Kalori (kcal)", keyboard: TextInputType.number),
                  _field(ing, "Malzemeler (virgülle)", maxLines: 2),
                  _field(amt, "Miktarlar (virgülle)", maxLines: 2),
                  _field(steps, "Adımlar (her satır)", maxLines: 5),
                  _field(warn, "Alerji uyarısı"),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  _toast("Lütfen ad girin");
                  return;
                }
                List<String> sl(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                saveRecipeEdit({
                  "id": existing?["id"]?.toString() ?? "rc_${DateTime.now().millisecondsSinceEpoch}",
                  "name": n,
                  "prepTime": prep.text.trim().isEmpty ? "15 dk" : prep.text.trim(),
                  "startingMonth": int.tryParse(month.text.trim()) ?? 6,
                  "kcal": double.tryParse(kcal.text.trim().replaceAll(',', '.')) ?? 0,
                  "imageUrl": image,
                  "ingredients": sl(ing.text),
                  "ingredientAmounts": sl(amt.text),
                  "steps": steps.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  "allergyWarning": warn.text.trim(),
                });
                _persistAll();
                Navigator.pop(ctx);
                setState(() {});
                _toast(existing == null ? "$n eklendi" : "$n güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [name, prep, month, kcal, ing, amt, steps, warn]) {
        c.dispose();
      }
    });
  }

  // ---------- articles manager ----------
  Widget _articlesManager() {
    final q = _articleSearch.text.trim().toLowerCase();
    final base = <Article>[...globalCustomArticles];
    // Built-in articles aren't exposed as a list here; manage custom + overrides.
    final all = base.where((a) => a.title.toLowerCase().contains(q)).toList();
    return _pane([
      _sectionHeader("Yazılar", "Özel yazıları yönet • yeni ekle",
          action: _primaryBtn("Yeni Yazı", Icons.add, () => _articleDialog(null))),
      _searchBar(_articleSearch, "Yazı ara...", (_) => setState(() {})),
      ...all.map((a) => _itemCard(
            leading: isPhotoUrl(a.imageUrl)
                ? photoOrFallback(a.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                : Container(color: const Color(0xFF2980B9).withOpacity(0.1), child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 20)))),
            title: a.title,
            subtitle: "${a.category} • ${a.readTime}",
            isCustom: true,
            onEdit: () => _articleDialog(a),
            onDelete: () => _confirmDelete("'${a.title}' yazısı", () {
              deleteArticle(a.id);
              _persistAll();
              setState(() {});
              _toast("Yazı silindi");
            }),
          )),
      if (all.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text("Henüz özel yazı yok. 'Yeni Yazı' ile ekleyin.", style: TextStyle(fontFamily: 'Inter', color: _light))),
    ]);
  }

  void _articleDialog(Article? existing) {
    final title = TextEditingController(text: existing?.title ?? "");
    String image = existing?.imageUrl ?? "";
    String cat = existing?.category ?? articleCategories.first;
    final readTime = TextEditingController(text: existing?.readTime ?? "3 dk");
    final summary = TextEditingController(text: existing?.summary ?? "");
    final content = TextEditingController(text: existing?.content ?? "");

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
                  _field(content, "İçerik", maxLines: 8),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () {
                final t = title.text.trim();
                if (t.isEmpty) {
                  _toast("Lütfen başlık girin");
                  return;
                }
                saveArticleEdit(Article(
                  id: existing?.id ?? "ac_${DateTime.now().millisecondsSinceEpoch}",
                  title: t,
                  category: cat,
                  readTime: readTime.text.trim().isEmpty ? "3 dk" : readTime.text.trim(),
                  summary: summary.text.trim(),
                  content: content.text.trim(),
                  emoji: existing?.emoji ?? "📝",
                  imageUrl: image,
                ));
                _persistAll();
                Navigator.pop(ctx);
                setState(() {});
                _toast(existing == null ? "Yazı eklendi" : "Yazı güncellendi");
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in [title, readTime, summary, content]) {
        c.dispose();
      }
    });
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
    ]);
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
