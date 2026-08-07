import 'package:flutter/foundation.dart';

import '../config/ads_config.dart';
import '../data/extras_store.dart';
import '../widgets/mobile_ads.dart';

/// Geçiş (interstitial) reklamı — sıklık sınırlı.
///
/// Tam ekran reklam en yüksek getirili biçim ama en riskli olanı da:
///   • Google, beklenmedik/çok sık geçiş reklamını politika ihlali sayar ve
///     yayıncı hesabını askıya alabilir.
///   • Apple, içeriği engelleyen reklamları 4.2'den reddedebilir.
///   • Bu bir bebek sağlığı uygulaması; her dokunuşta tam ekran reklam
///     kullanıcıyı kaybettirir.
///
/// Bu yüzden gösterim üç koşula bağlı:
///   1. Reklamsız pencere aktif değil (ödüllü reklam / kurucu üye hediyesi),
///   2. Uygulama açıldıktan sonra en az [kInterstitialWarmupOpens] tarif
///      açılmış olmalı — kullanıcı önce değeri görsün,
///   3. Son geçiş reklamının üzerinden [kInterstitialMinGap] geçmiş olmalı.
class InterstitialAds {
  InterstitialAds._();
  static final InterstitialAds instance = InterstitialAds._();

  int _opens = 0;
  DateTime? _lastShown;

  /// Tarif detayı her açıldığında çağrılır. Koşullar uygunsa reklam gösterir.
  Future<void> onRecipeOpened() async {
    _opens++;
    if (!interstitialConfigured) return;
    if (adFreeActive()) return;

    // ÖN-YÜKLEME: gösterime hak kazanmadan BİR açılış önce yüklemeye başla.
    // Reklamı gösterim anında yüklemek, dolgu oranımız (~%10) yüzünden
    // fırsatın çoğu kez boşa gitmesi demekti; ayrıca yükleme 1-5 sn sürdüğü
    // için reklam kullanıcı tarifi okumaya başladıktan sonra açılıyordu.
    // AdMob geçiş reklamları ~1 saat geçerli; bu yüzden uygulama açılışında
    // değil, tam gerekmeden hemen önce yükleniyor.
    if (_opens >= kInterstitialWarmupOpens) preloadInterstitialMobile();

    if (_opens <= kInterstitialWarmupOpens) return;
    final last = _lastShown;
    if (last != null && DateTime.now().difference(last) < kInterstitialMinGap) return;

    final shown = await showInterstitialMobile();
    if (shown) _lastShown = DateTime.now();
    debugPrint('Interstitial: opens=$_opens shown=$shown');
  }
}
