import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../screens/recipe_detail_screen.dart' show globalCartList;
import 'ad_banner.dart';

const Color _primary = Color(0xFFFF7A45);
const Color _text = Color(0xFF2D2D3A);
const Color _light = Color(0xFFA8A8B3);

/// Web üst nav'dan bir sekme istendiğinde HomeScreen bunu dinler ve geçer.
/// -1 = bekleyen istek yok.
final ValueNotifier<int> homeTabRequest = ValueNotifier<int>(-1);

/// Tüm web sayfalarında ortak üst portal menüsü (turuncu marka + yatay sekmeler).
/// Pushed sayfalarda bir sekmeye basınca kök sayfaya (HomeScreen) dönülür ve
/// ilgili sekme açılır.
class WebTopNav extends StatelessWidget {
  final int selectedIndex;
  const WebTopNav({super.key, this.selectedIndex = -1});

  void _go(BuildContext context, int i) {
    homeTabRequest.value = i;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
              decoration: const BoxDecoration(color: Color(0xFFFF4D6A), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text("${globalCartList.length}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ["Ana Sayfa", "Gıdalar", "Takvim", "Sepet", "Profil"];
    const iconsOut = [Icons.home_outlined, Icons.restaurant_outlined, Icons.calendar_today_outlined, Icons.shopping_cart_outlined, Icons.person_outline];
    const iconsIn = [Icons.home, Icons.restaurant, Icons.calendar_today, Icons.shopping_cart, Icons.person];
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
          child: Row(
            children: [
              const Text("🍼", style: TextStyle(fontSize: 22)),
              const SizedBox(width: 9),
              const Text("BabyBites", style: TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "bebeğinin beslenme rehberi",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withOpacity(0.85)),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFECECEF))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(labels.length, (i) {
                final sel = selectedIndex == i;
                final Widget icon = i == 3 ? _cartIcon(sel) : Icon(sel ? iconsIn[i] : iconsOut[i]);
                return InkWell(
                  onTap: () => _go(context, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: sel ? _primary : Colors.transparent, width: 3)),
                    ),
                    child: Row(
                      children: [
                        IconTheme(data: IconThemeData(color: sel ? _primary : _light, size: 20), child: icon),
                        const SizedBox(width: 8),
                        Text(labels[i], style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? _primary : _text)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Geniş ekranda (web/masaüstü) bir sayfayı kalıcı üst nav + ortalanmış içerik
/// + yanlarda reklam şeritleriyle sarar. Dar ekranda/mobilde sayfa olduğu gibi
/// döner. [child] genelde sayfanın kendi Scaffold'udur.
Widget webPageShell(BuildContext context, {int selectedIndex = -1, double maxWidth = 820, required Widget child}) {
  if (!kIsWeb) return child;
  return LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 900) return child;
      final showAds = c.maxWidth >= 1320 && !(globalIsPremium || adFreeActive());
      return Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WebTopNav(selectedIndex: selectedIndex),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth + (showAds ? 420 : 0)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showAds) const SideAdBox(),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: child,
                          ),
                        ),
                        if (showAds) const SideAdBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
