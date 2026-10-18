import 'package:flutter/foundation.dart';

import '../config/ads_config.dart';
import '../data/admin_store.dart';
import '../widgets/house_ad.dart';
import '../widgets/mobile_ads.dart';
import 'push_notifications.dart';

/// Geçiş (interstitial) reklamı — sıklık sınırlı.
///
/// Tam ekran reklam en yüksek getirili biçim ama en riskli olanı da:
///   • Google, beklenmedik/çok sık geçiş reklamını politika ihlali sayar ve
///     yayıncı hesabını askıya alabilir.
///   • Apple, içeriği engelleyen reklamları 4.2'den reddedebilir.
///   • Bu bir bebek sağlığı uygulaması; her dokunuşta tam ekran reklam
///     kullanıcıyı kaybettirir.
///
/// Bu yüzden gösterim iki koşula bağlı:
///   1. Uygulama açıldıktan sonra en az [kInterstitialWarmupOpens] tarif
///      açılmış olmalı — kullanıcı önce değeri görsün,
///   2. Son geçiş reklamının üzerinden [kInterstitialMinGap] geçmiş olmalı.
class InterstitialAds {
  InterstitialAds._();
  static final InterstitialAds instance = InterstitialAds._();

  int _opens = 0;
  DateTime? _lastShown;

  /// Tarif detayı her açıldığında çağrılır. Koşullar uygunsa reklam gösterir.
  Future<void> onRecipeOpened() async {
    _opens++;

    // ÖN-YÜKLEME (AdMob yapılandırılmışsa): gösterime hak kazanmadan BİR açılış
    // önce yüklemeye başla. AdMob geçiş reklamları ~1 saat geçerli.
    if (interstitialConfigured && _opens >= kInterstitialWarmupOpens) {
      preloadInterstitialMobile();
    }

    if (_opens <= kInterstitialWarmupOpens) return;
    final last = _lastShown;
    if (last != null && DateTime.now().difference(last) < kInterstitialMinGap) return;

    // Önce AdMob geçiş reklamı (yapılandırılmışsa). Dolmazsa VEYA AdMob kapalıysa
    // kendi tam ekran house reklamımızı göster (admin banner'ı varsa, 5 sn sonra
    // otomatik kapanır).
    var shown = false;
    if (interstitialConfigured) {
      shown = await showInterstitialMobile();
    }
    if (!shown && hasHouseBanners) {
      final ctx = PushNotifications.navigatorKey.currentContext;
      if (ctx != null) {
        await showHouseInterstitial(ctx);
        shown = true;
      }
    }
    if (shown) _lastShown = DateTime.now();
    debugPrint('Interstitial: opens=$_opens shown=$shown');
  }
}
