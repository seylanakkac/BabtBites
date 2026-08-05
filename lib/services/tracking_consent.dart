import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App Tracking Transparency (iOS 14.5+).
///
/// NEDEN VAR: İzin verilmezse iOS reklam kimliğini (IDFA) sıfırlar ve AdMob
/// yalnızca KİŞİSELLEŞTİRİLMEMİŞ reklam sunar; eCPM belirgin şekilde düşer.
/// İzin istemek, reklam gelirini artırmanın en doğrudan yolu.
///
/// ÜÇÜ BİRLİKTE TUTARLI OLMALI, biri eksik kalırsa App Store gönderimi
/// reddedilir (1 Ağu 2026'da tam tersi yaşandı: anahtar vardı ama izin hiç
/// istenmiyordu, gönderim engellendi):
///   1. Bu kod — izni gerçekten ister.
///   2. ios/Runner/Info.plist — NSUserTrackingUsageDescription.
///   3. App Store Connect → App Privacy — "veriler izleme için kullanılıyor".
///
/// SIRALAMA ÖNEMLİ: iOS sistem penceresi ancak uygulama ÖN PLANDA (active)
/// iken çıkar. Uygulama açılışında, ilk kare çizilmeden çağrılırsa pencere
/// hiç görünmez ve durum sessizce `notDetermined` kalır — yani izin bir daha
/// istenemez. Bu yüzden ilk kareden sonra çağrılır.
class TrackingConsent {
  TrackingConsent._();
  static final TrackingConsent instance = TrackingConsent._();

  bool _asked = false;
  final _settled = Completer<void>();

  /// İzin sorusu sonuçlanınca tamamlanır (iOS dışında hemen).
  Future<void> get settled => _settled.future;

  /// Reklam isteklerinin beklediği yer.
  ///
  /// ATT çözülmeden gönderilen ilk istek IDFA'sız gider ve
  /// kişiselleştirilmemiş sayılır; o yüzden bekliyoruz. Ama SONSUZA KADAR
  /// DEĞİL: izin akışı hiç tetiklenmezse (ör. kullanıcı ana ekrana hiç
  /// uğramadan derin linkle doğrudan bir tarife girerse) reklamlar kalıcı
  /// olarak susardı. Süre dolarsa reklam yine istenir — kötü ihtimalde
  /// kişiselleştirilmemiş olur, hiç reklam olmamasından iyidir.
  Future<void> waitSettled() =>
      _settled.future.timeout(const Duration(seconds: 8), onTimeout: () {});

  void _markSettled() {
    if (!_settled.isCompleted) _settled.complete();
  }

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Sistem penceresini göstermeden önce ne için sorulduğunu anlatan kısa bir
  /// açıklama. Apple bunu serbest bırakıyor (yönlendirici/ödül vaat eden dil
  /// yasak) ve izin oranını belirgin şekilde yükseltiyor.
  ///
  /// [context] verilmezse ön açıklama atlanır, doğrudan sistem penceresi çıkar.
  Future<void> requestIfNeeded(BuildContext? context) async {
    if (!_isIOS) {
      _markSettled();
      return;
    }
    if (_asked) return;
    _asked = true;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      // Yalnızca hiç sorulmamışsa sor. Kullanıcı daha önce reddettiyse iOS
      // pencereyi bir daha göstermez; tekrar çağırmak anlamsız.
      if (status == TrackingStatus.notDetermined) {
        if (context != null && context.mounted) {
          await _showRationale(context);
        }
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('TrackingConsent failed: $e');
    } finally {
      // Ne olursa olsun reklamları serbest bırak — aksi halde izin akışındaki
      // bir hata tüm reklamları kalıcı olarak susturur.
      _markSettled();
    }
  }

  Future<void> _showRationale(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Reklamları sana göre gösterelim mi?",
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D3A)),
          ),
          content: const Text(
            "BabyBites ücretsiz; giderlerini reklamlarla karşılıyoruz. İzin verirsen "
            "reklamlar ilgi alanlarına daha uygun olur ve bize daha çok destek olur.\n\n"
            "İzin vermesen de uygulamanın tamamını aynı şekilde kullanmaya devam edersin.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF5A5A6A), height: 1.45),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A45),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Devam", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}
