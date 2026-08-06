import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';
import '../services/tracking_consent.dart';

/// Platforma göre doğru banner/ödüllü reklam birimini seçer.
String get _bannerUnit =>
    Platform.isIOS ? kAdmobBannerUnitIOS : kAdmobBannerUnitAndroid;
String get _rewardedUnit =>
    Platform.isIOS ? kAdmobRewardedUnitIOS : kAdmobRewardedUnitAndroid;

/// AdMob SDK'sını başlatır (uygulama açılışında, mobilde).
Future<void> initMobileAds() async {
  try {
    // Uygulama EBEVEYNLER (yetişkinler) içindir, çocuklara yönelik değildir.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    await MobileAds.instance.initialize();
  } catch (_) {}
}

/// Son banner isteginin hatasi; basariliysa null.
///
/// Banner yuklenemeyince widget hicbir sey cizmiyor. Bu, "reklamsiz donem
/// acik" ile "AdMob dolgu vermedi" durumlarini AYIRT EDILEMEZ yapiyordu.
/// Profil ekrani bunu gosterebilsin diye kaydediliyor.
String? lastBannerError;

/// Yatay banner reklamı (yüklenince görünür; yüklenmezse boş).
Widget mobileBannerAd() => const _AdmobBanner();

/// Ödüllü reklamı yükler+gösterir. Ödül kazanıldıysa true, yüklenmezse null
/// (çağıran tarafta yer-tutucuya düşülür), gösterildi ama ödül yoksa false.
Future<bool?> showRewardedMobile() async {
  final completer = Completer<bool?>();
  // ATT sonuçlanmadan istek atarsak reklam kişiselleştirilmemiş sayılır.
  // Bekleme sınırlı; bkz. waitSettled.
  await TrackingConsent.instance.waitSettled();
  try {
    RewardedAd.load(
      adUnitId: _rewardedUnit,
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
    _startLoad();
  }

  /// ATT sorusu sonuçlanmadan reklam istemez. Aksi halde ilk açılıştaki ilk
  /// banner IDFA'sız istenir ve kişiselleştirilmemiş sayılır (gelir kaybı).
  Future<void> _startLoad() async {
    await TrackingConsent.instance.waitSettled();
    if (!mounted) return;
    _ad = BannerAd(
      adUnitId: _bannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner yuklenemedi: $err');
          lastBannerError = '${err.code}: ${err.message}';
          ad.dispose();
        },
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

/// Geçiş (interstitial) reklamını yükleyip gösterir. Gösterildiyse true.
///
/// Sıklık sınırı burada DEĞİL, InterstitialAds servisinde — bu fonksiyon
/// yalnızca "yükle ve göster" işini yapar.
Future<bool> showInterstitialMobile() async {
  final unit = Platform.isIOS ? kAdmobInterstitialUnitIOS : kAdmobInterstitialUnitAndroid;
  if (unit.isEmpty) return false;
  await TrackingConsent.instance.waitSettled();
  final completer = Completer<bool>();
  try {
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(true);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('Interstitial gosterilemedi: $err');
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial yuklenemedi: $err');
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
  } catch (e) {
    debugPrint('Interstitial hata: $e');
    if (!completer.isCompleted) completer.complete(false);
  }
  return completer.future;
}
