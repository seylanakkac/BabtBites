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
    //
    // İÇERİK DERECESİ NEDEN "G" DEĞİL: MaxAdContentRating.g, AdMob'un EN DAR
    // filtresi — yalnızca "genel izleyici" olarak derecelendirilmiş reklamlar
    // sunulur. Reklam verenlerin büyük çoğunluğu kampanyalarını PG olarak
    // etiketliyor; G seçmek talep havuzunu kendi elimizle daraltıyor ve
    // doğrudan "no fill" (1: Request Error: No ad to show) üretiyordu.
    // PG, bir ebeveyn uygulaması için hâlâ güvenli: müstehcen içerik, sert
    // şiddet ve yetişkin temaları (T/MA) dışarıda kalıyor.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        maxAdContentRating: MaxAdContentRating.pg,
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
  int _attempt = 0;
  Timer? _retryTimer;

  /// "Dolgu yok" gelince kaç kez yeniden denenecek.
  ///
  /// NEDEN GEREKLİ: eskiden tek deneme vardı. AdMob eşleşme oranımız ~%10;
  /// yani ilk istek büyük olasılıkla boş dönüyor ve widget bir daha HİÇ
  /// denemiyordu — kullanıcı o ekranda oturum boyunca reklam görmüyordu.
  /// Doğrudan gelir kaybıydı.
  static const int _kMaxAttempts = 4;

  /// Denemeler arası bekleme (artan). Google, arka arkaya istek atmayı
  /// politika ihlali sayıyor; bu yüzden agresif değil.
  static const List<Duration> _kBackoff = [
    Duration(seconds: 20),
    Duration(seconds: 45),
    Duration(seconds: 90),
  ];

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

    // UYARLANABİLİR BANNER: sabit 320x50 yerine ekran genişliğine göre boyut.
    // Hem daha çok reklam veren bu formatı destekliyor (dolgu artar) hem de
    // birim başına gelir daha yüksek. Boyut alınamazsa sabit bannera düşer.
    final width = MediaQuery.of(context).size.width.truncate();
    AdSize size = AdSize.banner;
    try {
      final adaptive = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width,
      );
      if (adaptive != null) size = adaptive;
    } catch (e) {
      debugPrint('Uyarlanabilir banner boyutu alinamadi: $e');
    }
    if (!mounted) return;

    _attempt++;
    _ad = BannerAd(
      adUnitId: _bannerUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          lastBannerError = null;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner yuklenemedi (deneme $_attempt): $err');
          lastBannerError = '${err.code}: ${err.message}';
          ad.dispose();
          _ad = null;
          _scheduleRetry();
        },
      ),
    )..load();
  }

  void _scheduleRetry() {
    if (!mounted || _attempt >= _kMaxAttempts) return;
    final wait = _kBackoff[(_attempt - 1).clamp(0, _kBackoff.length - 1)];
    _retryTimer?.cancel();
    _retryTimer = Timer(wait, () {
      if (mounted && !_loaded) _startLoad();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
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

/// ÖNBELLEĞE ALINMIŞ geçiş reklamı. Gösterildikten sonra null'lanır.
InterstitialAd? _preloadedInterstitial;
bool _interstitialLoading = false;
int _interstitialAttempt = 0;
Timer? _interstitialRetry;

String get _interstitialUnit =>
    Platform.isIOS ? kAdmobInterstitialUnitIOS : kAdmobInterstitialUnitAndroid;

/// Geçiş reklamını ÖNCEDEN yükler (arka planda).
///
/// NEDEN ÖNBELLEK: eskiden reklam gösterim ANINDA yükleniyordu. İki sorun:
///   • Yükleme 1-5 sn sürüyor; kullanıcı tarifi okumaya başlamışken reklam
///     geç açılıyordu (kötü deneyim, Google da önden yüklemeyi öneriyor).
///   • Eşleşme oranımız ~%10 olduğu için istek çoğunlukla boş dönüyor ve o
///     fırsat tamamen kaybediliyordu — yeniden deneme yoktu.
/// Önden yükleyince, an geldiğinde elde hazır reklam oluyor; dolgu gelmezse
/// arka planda sessizce tekrar deneniyor.
Future<void> preloadInterstitialMobile() async {
  if (_interstitialUnit.isEmpty) return;
  if (_preloadedInterstitial != null || _interstitialLoading) return;
  _interstitialLoading = true;
  await TrackingConsent.instance.waitSettled();
  _interstitialAttempt++;
  try {
    InterstitialAd.load(
      adUnitId: _interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialAttempt = 0;
          _preloadedInterstitial = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial on-yukleme basarisiz ($_interstitialAttempt): $err');
          _interstitialLoading = false;
          _scheduleInterstitialRetry();
        },
      ),
    );
  } catch (e) {
    debugPrint('Interstitial hata: $e');
    _interstitialLoading = false;
  }
}

/// Dolgu gelmezse artan aralıklarla yeniden dener (en fazla 3 kez).
/// Agresif değil: Google arka arkaya isteği politika ihlali sayıyor.
void _scheduleInterstitialRetry() {
  if (_interstitialAttempt >= 3) return;
  const waits = [Duration(seconds: 30), Duration(seconds: 90)];
  _interstitialRetry?.cancel();
  _interstitialRetry = Timer(
    waits[(_interstitialAttempt - 1).clamp(0, waits.length - 1)],
    preloadInterstitialMobile,
  );
}

/// Elde hazır geçiş reklamı varsa gösterir. Gösterildiyse true.
///
/// Sıklık sınırı burada DEĞİL, InterstitialAds servisinde — bu fonksiyon
/// yalnızca "varsa göster" işini yapar. Gösterimden sonra bir sonraki reklam
/// arka planda yüklenmeye başlar.
Future<bool> showInterstitialMobile() async {
  final ad = _preloadedInterstitial;
  if (ad == null) {
    // Hazır reklam yok — bu fırsat kaçtı ama bir sonraki için yüklemeyi başlat.
    preloadInterstitialMobile();
    return false;
  }
  _preloadedInterstitial = null;
  final completer = Completer<bool>();
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      preloadInterstitialMobile(); // sıradakini hazırla
      if (!completer.isCompleted) completer.complete(true);
    },
    onAdFailedToShowFullScreenContent: (ad, err) {
      debugPrint('Interstitial gosterilemedi: $err');
      ad.dispose();
      preloadInterstitialMobile();
      if (!completer.isCompleted) completer.complete(false);
    },
  );
  try {
    ad.show();
  } catch (e) {
    debugPrint('Interstitial show hata: $e');
    return false;
  }
  return completer.future;
}
