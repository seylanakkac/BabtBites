import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';

/// AdMob SDK'sını başlatır (uygulama açılışında, mobilde).
Future<void> initMobileAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
}

/// Yatay banner reklamı (yüklenince görünür; yüklenmezse boş).
Widget mobileBannerAd() => const _AdmobBanner();

/// Ödüllü reklamı yükler+gösterir. Ödül kazanıldıysa true, yüklenmezse null
/// (çağıran tarafta yer-tutucuya düşülür), gösterildi ama ödül yoksa false.
Future<bool?> showRewardedMobile() async {
  final completer = Completer<bool?>();
  try {
    RewardedAd.load(
      adUnitId: kAdmobRewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(null);
            },
          );
          ad.show(onUserEarnedReward: (ad, reward) => earned = true);
        },
        onAdFailedToLoad: (err) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

class _AdmobBanner extends StatefulWidget {
  const _AdmobBanner();
  @override
  State<_AdmobBanner> createState() => _AdmobBannerState();
}

class _AdmobBannerState extends State<_AdmobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: kAdmobBannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
