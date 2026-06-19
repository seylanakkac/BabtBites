import 'package:flutter/material.dart';
import '../data/extras_store.dart';

/// A revenue ad slot, shown only to NON-premium users.
///
/// Today this renders a styled placeholder so the placement is visible while we
/// test on web (Google AdMob does NOT support Flutter web). On the Android/iOS
/// build, replace the placeholder body with a real `google_mobile_ads`
/// `BannerAd` widget — the placement, sizing and premium-gating stay the same:
///
///   final ad = BannerAd(adUnitId: ..., size: AdSize.banner, request: AdRequest(),
///                        listener: BannerAdListener())..load();
///   return SizedBox(height: ad.size.height, child: AdWidget(ad: ad));
///
/// BabyBites+ subscribers never see ads (the "reklamsız" perk).
/// Dikey "skyscraper" reklam yuvası — yalnızca geniş ekranda (web/masaüstü),
/// içeriğin sol/sağ boşluklarında gösterilir. AdBanner ile aynı premium/ödüllü
/// gizleme kuralını uygular. Mobil derlemede gerçek `BannerAd` ile değiştirilir.
class SideAdBox extends StatelessWidget {
  final double width;
  final VoidCallback? onUpgrade;
  const SideAdBox({super.key, this.width = 170, this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (globalIsPremium || adFreeActive()) return const SizedBox.shrink();

    const primary = Color(0xFFFF7A45);
    const light = Color(0xFFA8A8B3);

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E6)),
      ),
      child: Column(
        children: [
          // "Reklam" etiketi (üstte, açıkça işaretli).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E2E6)),
            ),
            child: const Text(
              "Reklam",
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: light),
            ),
          ),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 30, color: light),
                  SizedBox(height: 8),
                  Text(
                    "Reklam alanı",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: light),
                  ),
                ],
              ),
            ),
          ),
          // Reklamsız yapma (BabyBites+) yönlendirmesi.
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, size: 14, color: primary),
                  SizedBox(width: 4),
                  Text(
                    "Reklamsız",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdBanner extends StatelessWidget {
  /// Opens the BabyBites+ screen so the user can remove ads. Optional.
  final VoidCallback? onUpgrade;
  final EdgeInsets margin;

  const AdBanner({
    super.key,
    this.onUpgrade,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    // Ad-free for premium subscribers OR during a rewarded ad-free window.
    if (globalIsPremium || adFreeActive()) return const SizedBox.shrink();

    const primary = Color(0xFFFF7A45);
    const light = Color(0xFFA8A8B3);

    return Container(
      margin: margin,
      height: 66,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E2E6)),
      ),
      child: Row(
        children: [
          // "Reklam" tag (so it's clearly labelled as an ad).
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E2E6)),
            ),
            child: const Text(
              "Reklam",
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: light),
            ),
          ),
          const Expanded(
            child: Text(
              "Reklam alanı",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: light),
            ),
          ),
          // Upsell: remove ads with BabyBites+.
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 14, color: primary),
                  SizedBox(width: 4),
                  Text(
                    "Reklamsız",
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
