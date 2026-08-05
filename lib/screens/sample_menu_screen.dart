import 'package:flutter/material.dart';

import '../data/food_database.dart';
import '../data/sample_menu.dart';
import '../services/auth_gate.dart';
import '../widgets/ad_banner.dart';
import '../widgets/web_shell.dart';
import 'recipe_detail_screen.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);

/// Örnek haftalık menü detayı.
///
/// Kullanıcı günleri gezip tek tek kalem ekleyebilir ya da tüm haftayı kendi
/// takvimine kopyalayabilir.
class SampleMenuScreen extends StatefulWidget {
  final SampleMenu menu;

  /// Tek bir kalemi kullanıcının planına ekler: (gün indeksi, öğün, ad).
  final void Function(int dayIndex, String slot, String name) onAddItem;

  /// Tüm menüyü kullanıcının takvimine kopyalar. Kopyalanan kalem sayısını
  /// döndürür (kullanıcıya "34 öğün eklendi" demek için).
  final int Function(SampleMenu menu) onCopyAll;

  const SampleMenuScreen({
    super.key,
    required this.menu,
    required this.onAddItem,
    required this.onCopyAll,
  });

  @override
  State<SampleMenuScreen> createState() => _SampleMenuScreenState();
}

class _SampleMenuScreenState extends State<SampleMenuScreen> {
  int _day = 0;
  final Set<String> _added = {};

  String _key(int d, String slot, String name) => "$d|$slot|$name";

  Recipe? _findRecipe(String name) {
    final n = name.trim().toLowerCase();
    for (final r in globalRecipesDatabase) {
      if (r.name.trim().toLowerCase() == n) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => webPageShell(context, child: _body(context));

  Widget _body(BuildContext context) {
    final menu = widget.menu;
    final dayName = kWeekDays[_day];
    final slots = menu.days[dayName] ?? const <String, List<String>>{};
    final slotNames = slots.keys.where((s) => (slots[s] ?? const []).isNotEmpty).toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: const Text("Örnek Menü",
            style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(menu.title,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 4),
          Text(
            [
              if (menu.month > 0) kMonthNames[menu.month],
              if (menu.ageMonths > 0) "${menu.ageMonths}+ ay",
              "${menu.itemCount} öğün",
            ].join(" · "),
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light),
          ),
          if (menu.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Text(menu.note,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: _text, height: 1.45)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyAll,
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text("Tüm Menüyü Takvimime Kopyala",
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text("Bu haftanın günlerine eklenir; mevcut planın silinmez.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
          const SizedBox(height: 16),
          // Gün seçici
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kWeekDays.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = i == _day;
                final has = (menu.days[kWeekDays[i]] ?? const {}).values.any((l) => l.isNotEmpty);
                return GestureDetector(
                  onTap: () => setState(() => _day = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6)),
                    ),
                    child: Text(
                      kWeekDays[i].substring(0, 3),
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : (has ? _text : _light)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (slotNames.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text("Bu gün için öğün eklenmemiş.",
                  textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
            )
          else
            ...slotNames.map((slot) => _slotCard(slot, slots[slot]!)),
          const SizedBox(height: 12),
          const AdBanner(),
        ],
      ),
    );
  }

  Widget _slotCard(String slot, List<String> items) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 8),
            ...items.map((name) {
              final recipe = _findRecipe(name);
              final added = _added.contains(_key(_day, slot, name));
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        // Tarif olarak kayıtlıysa dokununca tarifi aç.
                        onTap: recipe == null
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                                ),
                        child: Row(
                          children: [
                            Icon(recipe != null ? Icons.menu_book_outlined : Icons.restaurant,
                                size: 15, color: recipe != null ? _primary : _light),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(name,
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.5,
                                      color: _text,
                                      decoration: recipe != null ? TextDecoration.underline : null,
                                      decorationColor: _primary.withOpacity(0.4))),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: added ? "Eklendi" : "Planıma ekle",
                      icon: Icon(added ? Icons.check_circle : Icons.add_circle_outline,
                          size: 22, color: added ? const Color(0xFF10B981) : _primary),
                      onPressed: added
                          ? null
                          : () {
                              if (requireLogin(context)) return;
                              widget.onAddItem(_day, slot, name);
                              setState(() => _added.add(_key(_day, slot, name)));
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("\"$name\" ${kWeekDays[_day]} $slot'a eklendi."),
                                duration: const Duration(seconds: 2),
                              ));
                            },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

  Future<void> _copyAll() async {
    if (requireLogin(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Menü takvimine kopyalansın mı?",
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
        content: Text(
          "\"${widget.menu.title}\" bu haftanın günlerine eklenecek. "
          "Mevcut planındaki öğünler SİLİNMEZ, üzerine eklenir.",
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF5A5A6A), height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text("Vazgeç", style: TextStyle(fontFamily: 'Inter', color: _light))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text("Kopyala", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = widget.onCopyAll(widget.menu);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n > 0 ? "$n öğün takvimine eklendi 🎉" : "Eklenecek yeni öğün yoktu."),
      duration: const Duration(seconds: 3),
    ));
  }
}
