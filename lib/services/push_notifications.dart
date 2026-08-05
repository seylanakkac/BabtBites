import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/push_config.dart';

/// Push bildirimleri (FCM).
///
/// Web'de VAPID anahtarıyla, mobilde platformun kendi servisiyle çalışır.
/// iOS'ta FCM token'ı ANCAK APNs token'ı geldikten sonra alınabilir; aksi
/// halde getToken() `apns-token-not-set` ile patlar. Bu yüzden iOS'ta önce
/// APNs token'ı beklenir.
///
/// iOS'ta çalışması için kod dışında iki şart daha var:
///   1. Runner.entitlements içinde `aps-environment` anahtarı (ve App ID'de
///      Push Notifications yetkisi açık olmalı, yoksa imzalama başarısız olur).
///   2. Firebase Console → Proje Ayarları → Cloud Messaging → Apple app
///      configuration'a APNs Auth Key (.p8) yüklenmiş olmalı.
/// Bunlar eksikken izin verilse bile token alınamaz.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  String? token;

  /// Son başarısızlığın gerçek sebebi (arayüzde göstermek için).
  /// Genel bir "açılamadı" mesajı hem kullanıcıyı hem bizi kör bırakıyordu.
  String? lastError;

  /// Web'de VAPID anahtarı şart; mobilde gerekmez.
  bool get _configured => kIsWeb ? pushConfigured : true;

  /// Kullanıcı "Bildirimleri Aç" deyince çağrılır (izin penceresi kullanıcı
  /// hareketiyle açılmalı). Başarılıysa true döner.
  Future<bool> enable() async {
    lastError = null;
    if (!_configured) {
      lastError = "Web push yapılandırılmamış (VAPID anahtarı yok).";
      return false;
    }
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission(alert: true, badge: true, sound: true);
      final status = settings.authorizationStatus;
      if (status != AuthorizationStatus.authorized && status != AuthorizationStatus.provisional) {
        lastError = status == AuthorizationStatus.denied
            ? "Bildirim izni reddedildi. Cihaz ayarlarından açabilirsin."
            : "Bildirim izni verilmedi.";
        return false;
      }

      // iOS: APNs token gelmeden getToken() çağrılamaz.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await _awaitApnsToken(m);
        if (apns == null) {
          lastError = "Cihaz Apple bildirim servisine kaydedilemedi. "
              "Uygulamanın push yetkisi veya sunucu tarafı anahtarı eksik olabilir.";
          return false;
        }
      }

      final t = kIsWeb ? await m.getToken(vapidKey: kFcmVapidKey) : await m.getToken();
      token = t;
      if (t == null) {
        lastError = "Bildirim kimliği (token) alınamadı.";
        return false;
      }
      // Ön planda gelen mesajları logla (arka planı service worker gösterir).
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('Push (foreground): ${msg.notification?.title} — ${msg.notification?.body}');
      });
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('Push.enable failed: $e');
      return false;
    }
  }

  /// APNs token'ı kısa süre bekler (kayıt birkaç saniye sürebiliyor).
  /// Gelmezse null döner — bu genelde entitlement/APNs anahtarı eksikliğidir.
  Future<String?> _awaitApnsToken(FirebaseMessaging m) async {
    for (var i = 0; i < 10; i++) {
      try {
        final t = await m.getAPNSToken();
        if (t != null) return t;
      } catch (e) {
        debugPrint('getAPNSToken failed: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// İzin durumu (zaten verilmiş mi?).
  Future<bool> isGranted() async {
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }
}
