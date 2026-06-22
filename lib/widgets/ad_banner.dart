import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../config/ads_config.dart';
import 'web_ads.dart';

/// A revenue ad slot. Reklamlar TÜM kullanıcılara gösterilir (premium dahil);
/// yalnızca ödüllü "1 gün reklamsız" penceresi (adFreeActive) sırasında gizlenir.
///
/// Web'de gerçek reklam AdSense ile (ads_config.dart slot'ları dolunca) gelir;
/// boşken stilize "Reklam alanı" yer-tutucusu gösterilir.
/// Dikey "skyscraper" reklam yuvası — yalnızca geniş ekranda (web/masaüstü).
class SideAdBox extends StatelessWidget {
  final double width;
  final VoidCallback? onUpgrade;
  const SideAdBox({super.key, this.width = 170, this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (adFreeActive()) return const SizedBox.shrink();

    // AdSense yapılandırılmışsa gerçek dikey reklamı göster.
    if (adsConfigured && kAdsenseSideSlot.isNotEmpty) {
      return Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: adsenseAd(client: kAdsenseClient, slot: kAdsenseSideSlot, width: width, height: 600),
      );
    }

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
    // Reklamlar premium dahil herkese gösterilir; yalnızca ödüllü reklamsız
    // pencere sırasında gizlenir.
    if (adFreeActive()) return const SizedBox.shrink();

    // AdSense yapılandırılmışsa gerçek yatay banner reklamı göster.
    if (adsConfigured && kAdsenseBannerSlot.isNotEmpty) {
      return Container(
        margin: margin,
        height: 90,
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, c) => adsenseAd(
            client: kAdsenseClient,
            slot: kAdsenseBannerSlot,
            width: c.maxWidth.isFinite ? c.maxWidth : 320,
            height: 90,
          ),
        ),
      );
    }

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
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
