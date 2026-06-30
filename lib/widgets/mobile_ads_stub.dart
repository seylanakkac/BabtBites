import 'package:flutter/material.dart';

/// Web (ve google_mobile_ads desteklemeyen platformlar) için no-op.
Future<void> initMobileAds() async {}

/// Mobil banner reklamı — web'de görünmez.
Widget mobileBannerAd() => const SizedBox.shrink();

/// Mobil ödüllü reklam — web'de kullanılamaz (null → çağıran yer-tutucuya düşer).
Future<bool?> showRewardedMobile() async => null;
