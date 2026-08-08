import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/push_config.dart';
import '../data/tracking_store.dart';

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
      await _ensureAndroidChannel();
      await syncTopics();
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

  /// Duyuru ve yeni tarif bildirimlerinin Android kanalı.
  ///
  /// İlaç hatırlatmaları AYRI bir kanalda (`babybites_reminders`) kalıyor:
  /// kullanıcı duyuruları susturmak isterse hatırlatmaları kaybetmemeli,
  /// tersi de geçerli. AndroidManifest'te bu kimlik FCM'in varsayılan
  /// kanalı olarak tanıtılıyor; kanal önceden OLUŞTURULMAZSA Android 8+
  /// bildirimi hiç göstermiyor, bu yüzden burada açıkça yaratılıyor.
  static const String kAndroidChannelId = 'babybites_news';

  Future<void> _ensureAndroidChannel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final impl = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(const AndroidNotificationChannel(
        kAndroidChannelId,
        'Duyurular ve yeni tarifler',
        description: 'Kampanyalar, duyurular ve bebeğinize uygun yeni tarifler',
        importance: Importance.high,
      ));
    } catch (e) {
      debugPrint('Push._ensureAndroidChannel failed: $e');
    }
  }

  /// Herkese açık duyuruların gittiği konu.
  static const String kTopicAll = 'all';

  /// Bebeğin ay yaşına göre abone olunan konunun önekі: `age_m7` gibi.
  ///
  /// NEDEN KONU (topic) KULLANILIYOR: alternatifi her kullanıcının FCM
  /// token'ını Firestore'da tutup sunucuda tek tek göndermek. Konular hem
  /// token saklamayı hem de kullanıcı başına yazma/okuma maliyetini ortadan
  /// kaldırıyor; Cloud Function tek çağrıyla tüm aboneleri buluyor.
  ///
  /// Yaşı KONUYA gömmenin sebebi: "12+ ay" bir tarifin duyurusu 6 aylık
  /// bebeği olana gitmemeli. Cloud Function tarifi `age_m{startingMonth}`
  /// ile `age_m36` arasındaki konulara gönderiyor; böylece yalnızca bebeği
  /// yeterince büyük olanlar alıyor.
  static String ageTopic(int months) => 'age_m${months.clamp(0, 36)}';

  /// Cihazın abone olduğu son yaş konusu (değişince eskisinden çıkılır).
  static const String _kLastAgeTopic = 'push_last_age_topic';

  /// Abonelikleri bebeğin güncel yaşıyla eşitler.
  ///
  /// Açılışta ve bebek/yaş değiştiğinde çağrılır. Aynı konuya tekrar abone
  /// olmak zararsız (idempotent), ama ESKİ yaş konusundan çıkmak şart —
  /// yoksa bebek büyüdükçe kullanıcı eski yaş bildirimlerini de almaya
  /// devam eder.
  ///
  /// Web'de FCM konu aboneliği istemciden yapılamaz; orada sessizce atlanır.
  Future<void> syncTopics() async {
    if (kIsWeb) return;
    try {
      final m = FirebaseMessaging.instance;
      // Uygulama yeniden açıldığında token alanı boştur; izin zaten verilmişse
      // sessizce tazele. Aksi halde açılışta abonelik hiç güncellenmez ve
      // bebek büyüdükçe kullanıcı yanlış yaş bildirimlerini almaya devam eder.
      if (token == null) {
        if (!await isGranted()) return;
        token = await m.getToken();
        if (token == null) return;
      }
      await m.subscribeToTopic(kTopicAll);

      final months = globalActiveBabyMonths;
      if (months <= 0) return; // doğum tarihi yoksa yaş konusu kurulmaz
      final next = ageTopic(months);

      final prefs = await SharedPreferences.getInstance();
      final prev = prefs.getString(_kLastAgeTopic);
      if (prev == next) return;
      if (prev != null && prev.isNotEmpty) {
        await m.unsubscribeFromTopic(prev);
      }
      await m.subscribeToTopic(next);
      await prefs.setString(_kLastAgeTopic, next);
      debugPrint('Push konuları: $kTopicAll + $next');
    } catch (e) {
      debugPrint('Push.syncTopics failed: $e');
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
