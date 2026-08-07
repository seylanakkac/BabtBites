import 'package:flutter/material.dart';

/// Web (ve google_mobile_ads desteklemeyen platformlar) için no-op.
Future<void> initMobileAds() async {}

/// Mobil banner reklamı — web'de görünmez.
Widget mobileBannerAd() => const SizedBox.shrink();

/// Mobil ödüllü reklam — web'de kullanılamaz (null → çağıran yer-tutucuya düşer).
Future<bool?> showRewardedMobile() async => null;

/// Mobil geçiş (interstitial) reklamı — web'de kullanılamaz.
Future<bool> showInterstitialMobile() async => false;

/// Geçiş reklamı ön-yüklemesi — web'de no-op.
Future<void> preloadInterstitialMobile() async {}

/// Mobil surumle ayni API yuzeyi (web'de reklam hatasi izlenmiyor).
String? lastBannerError;
