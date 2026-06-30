import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../screens/recipe_detail_screen.dart' show globalCartList;
import '../screens/notifications_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/community_screen.dart';
import '../services/auth_gate.dart';
import 'ad_banner.dart';

const Color _primary = Color(0xFFFF7A45);
const Color _text = Color(0xFF2D2D3A);
const Color _light = Color(0xFFA8A8B3);

/// Web üst nav'dan bir sekme istendiğinde HomeScreen bunu dinler ve geçer.
/// -1 = bekleyen istek yok.
final ValueNotifier<int> homeTabRequest = ValueNotifier<int>(-1);

/// Üst portal çubuğunun (her sayfada) ihtiyaç duyduğu bebek/favori köprüsü.
/// HomeScreen alanları doldurur; WebTopNav okur. [rev] değişince üst çubuk yenilenir.
class WebTopBar {
  final ValueNotifier<int> rev = ValueNotifier<int>(0);
  List<Map<String, dynamic>> babies = const [];
  Map<String, dynamic>? activeBaby;
  void Function(Map<String, dynamic> baby)? onSelectBaby;
  VoidCallback? onOpenFavorites;
  /// Profil açılır menüsündeki öğeler. Her biri:
  /// {"label":String, "icon":IconData, "premium":bool, "onTap":VoidCallback}
  List<Map<String, dynamic>> profileItems = const [];
  void bump() => rev.value++;
}

final WebTopBar webTopBar = WebTopBar();

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

  /// "Rehber" (makaleler) sayfasını açar; bir makale bir sekmeye yönlendirirse
  /// o sekmeye geçilir.
  void _openGuide(BuildContext context) {
    Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const ArticlesScreen())).then((idx) {
      if (idx != null) homeTabRequest.value = idx;
    });
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

  Widget _circleBtn(Widget icon, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: icon)),
        ),
      );

  Widget _bell(BuildContext context) {
    final unread = unreadNotificationCount();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => webTopBar.bump()),
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, color: _text, size: 20),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(color: const Color(0xFFFF4D6A), borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white, width: 1)),
                    child: Text(unread > 9 ? "9+" : "$unread", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Profil açılır menüsü: bebek seçici + profil/yasal öğeleri (hepsi tıklanır).
  Widget _profileMenu(BuildContext context) {
    // Misafir: profil menüsü yerine "Giriş Yap / Üye Ol" butonu.
    if (isGuest()) {
      return GestureDetector(
        onTap: () => requireLogin(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(22)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text("Giriş Yap / Üye Ol", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      );
    }
    final active = webTopBar.activeBaby;
    final avatar = active?["avatar"]?.toString() ?? "👶";
    return PopupMenuButton<int>(
      tooltip: "Profil",
      offset: const Offset(0, 46),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[];
        items.add(const PopupMenuItem<int>(
          enabled: false,
          height: 28,
          child: Text("BEBEK", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _light, letterSpacing: 0.5)),
        ));
        for (final b in webTopBar.babies) {
          final isActive = identical(b, active);
          items.add(PopupMenuItem<int>(
            onTap: () { webTopBar.onSelectBaby?.call(b); webTopBar.bump(); },
            child: Row(children: [
              Text(b["avatar"]?.toString() ?? "👶", style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(b["name"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
              if (isActive) ...[const SizedBox(width: 10), const Icon(Icons.check_circle, color: Color(0xFF2BB673), size: 16)],
            ]),
          ));
        }
        items.add(const PopupMenuDivider());
        for (final it in webTopBar.profileItems) {
          final premium = it["premium"] == true;
          final danger = it["danger"] == true;
          final iconColor = danger ? const Color(0xFFE5484D) : _primary;
          final textColor = danger ? const Color(0xFFE5484D) : _text;
          items.add(PopupMenuItem<int>(
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              (it["onTap"] as VoidCallback?)?.call();
            },
            child: Row(children: [
              Icon(it["icon"] as IconData? ?? Icons.circle, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Text(it["label"]?.toString() ?? "", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: danger ? FontWeight.w600 : FontWeight.normal, color: textColor)),
              if (premium) ...[const Spacer(), const Icon(Icons.lock_outline, size: 13, color: _primary)],
            ]),
          ));
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 26, height: 26, decoration: BoxDecoration(color: _primary.withOpacity(0.15), shape: BoxShape.circle), alignment: Alignment.center, child: Text(avatar, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 6),
            const Text("Profil", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _primary)),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: _primary),
          ],
        ),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              // Logo + ad → ana sayfa
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _go(context, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/logo.png', height: 34, errorBuilder: (_, __, ___) => const Text("🍼", style: TextStyle(fontSize: 22))),
                      const SizedBox(width: 9),
                      const Text("BabyBites", style: TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Sağ küme: favoriler + bildirim + bebek seçici + profil
              ValueListenableBuilder<int>(
                valueListenable: webTopBar.rev,
                builder: (context, _, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleBtn(const Icon(Icons.favorite, color: Color(0xFFFF4D6A), size: 20), () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      webTopBar.onOpenFavorites?.call();
                    }),
                    const SizedBox(width: 8),
                    _bell(context),
                    const SizedBox(width: 8),
                    _profileMenu(context),
                  ],
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                ...List.generate(labels.length, (i) {
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
                _communityNavItem(context),
                _guideNavItem(context),
              ],
            ),
        ),
      ],
    );
  }

  Widget _guideNavItem(BuildContext context) => InkWell(
        onTap: () => _openGuide(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: _light),
              SizedBox(width: 8),
              Text("Rehber", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: _text)),
            ],
          ),
        ),
      );

  Widget _communityNavItem(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: const Row(
            children: [
              Icon(Icons.forum_outlined, size: 20, color: _light),
              SizedBox(width: 8),
              Text("Topluluk", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: _text)),
            ],
          ),
        ),
      );
}

/// Geniş ekranda (web/masaüstü) bir sayfayı kalıcı üst nav + ortalanmış içerik
/// + yanlarda reklam şeritleriyle sarar. Dar ekranda/mobilde sayfa olduğu gibi
/// döner. [child] genelde sayfanın kendi Scaffold'udur.
Widget webPageShell(BuildContext context, {int selectedIndex = -1, double maxWidth = 820, required Widget child}) {
  if (!kIsWeb) return child;
  return LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 900) return child;
      final showAds = c.maxWidth >= 1320 && !adFreeActive();
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
