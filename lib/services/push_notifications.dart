import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/push_config.dart';

/// Web push (FCM) — kullanıcı izniyle açılır. Token FCM'e kaydolur; Firebase
/// Console → Cloud Messaging'den "tüm kullanıcılara" bildirim gönderilebilir.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  String? token;

  /// Kullanıcı "Bildirimleri Aç" deyince çağrılır (izin penceresi kullanıcı
  /// hareketiyle açılmalı). Başarılıysa true döner.
  Future<bool> enable() async {
    if (!pushConfigured) {
      debugPrint('Push: VAPID anahtarı boş (push_config.dart).');
      return false;
    }
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
      final t = await m.getToken(vapidKey: kFcmVapidKey);
      token = t;
      // Ön planda gelen mesajları logla (arka planı service worker gösterir).
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('Push (foreground): ${msg.notification?.title} — ${msg.notification?.body}');
      });
      return t != null;
    } catch (e) {
      debugPrint('Push.enable failed: $e');
      return false;
    }
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
