import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cihazda zamanlanan yerel bildirimler ("6 saat sonra hatırlat").
///
/// FCM'DEN FARKI: FCM sunucudan anlık bildirim gönderir; burada gelecekteki bir
/// ana randevu koyuyoruz ve bunu CİHAZ tutuyor. İnternet gerekmez, uygulama
/// kapalıyken de çalışır.
///
/// ⚠️ WEB'DE ÇALIŞMAZ. flutter_local_notifications'ın web uygulaması yok;
/// çağrılar burada [kIsWeb] ile kısa devre edilir ve null/false döner. Arayüz
/// bu yüzden web'de hatırlatma seçeneğini hiç göstermemeli — bkz. [available].
///
/// ⚠️ GARANTİ DEĞİL. Kullanıcı bildirim iznini reddedebilir, Android'de pil
/// optimizasyonu alarmı geciktirebilir, cihaz kapalı olabilir. Bu yüzden
/// hatırlatma bir YARDIMCI olarak sunulmalı; ilaç saatinin tek dayanağı
/// olmamalı. Verilen dozun kaydı her hâlükârda günlükte durur.
class LocalReminders {
  LocalReminders._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Bu platformda zamanlanmış bildirim kurulabilir mi?
  static bool get available => !kIsWeb;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'babybites_reminders',
    'Hatırlatmalar',
    channelDescription: 'İlaç, takviye ve beslenme hatırlatmaları',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );

  /// Eklentiyi ve saat dilimi veritabanını hazırlar. Birden çok kez çağrılabilir.
  ///
  /// Uygulama açılışında DEĞİL, ilk hatırlatma kurulurken çağrılır: açılışı
  /// yavaşlatmasın ve hiç hatırlatma kullanmayan kullanıcıdan izin istenmesin.
  static Future<bool> _ensureReady() async {
    if (!available) return false;
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      // Cihazın yerel saatini kullan. Kesin IANA adını almak için ek bir paket
      // gerekir; bunun yerine UTC ofsetiyle eşleşen bir bölge seçiyoruz —
      // "şimdiden N saat sonra" hesabı için bu yeterli.
      tz.setLocalLocation(tz.getLocation(_guessTimeZone()));
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // İzin, kullanıcı gerçekten hatırlatma kurarken istenir.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(init);
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('LocalReminders._ensureReady failed: $e');
      return false;
    }
  }

  /// Cihazın UTC ofsetine karşılık gelen bir IANA bölgesi. Türkiye UTC+3.
  static String _guessTimeZone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == const Duration(hours: 3)) return 'Europe/Istanbul';
    // Diğer ofsetler için Etc/GMT kullan. DİKKAT: Etc/GMT işaretleri TERSTİR
    // (POSIX mirası) — UTC+2 için 'Etc/GMT-2' doğru olandır.
    final hours = offset.inMinutes ~/ 60;
    final sign = hours >= 0 ? '-' : '+';
    return 'Etc/GMT$sign${hours.abs()}';
  }

  /// Bildirim iznini ister. Zaten verilmişse true döner.
  static Future<bool> requestPermission() async {
    if (!await _ensureReady()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      // Android 13+ bildirim izni.
      final granted = await android.requestNotificationsPermission() ?? false;
      if (!granted) return false;
      // Android 12+ tam zamanlı alarm izni. Verilmezse yine zamanlarız, sadece
      // dakikalar mertebesinde gecikebilir — bu yüzden sonucu bloklayıcı
      // saymıyoruz.
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('LocalReminders.requestPermission failed: $e');
      return false;
    }
  }

  /// [after] süre sonrasına bir bildirim kurar; kurulamazsa null döner.
  /// Dönen kimlik iptal için saklanmalı.
  static Future<int?> scheduleIn({
    required Duration after,
    required String title,
    required String body,
  }) async {
    if (!await _ensureReady()) return null;
    final when = tz.TZDateTime.now(tz.local).add(after);
    // Kimlik 32-bit int olmalı; milisaniye damgası taşar.
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return id;
    } on Exception catch (e) {
      // Tam alarm izni yoksa exact mod hata verir; şaşmaz olmayan modla
      // yeniden dene — hatırlatma hiç kurulmamasındansa birkaç dakika
      // gecikmesi iyidir.
      debugPrint('LocalReminders exact schedule failed, retrying inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        return id;
      } catch (e2) {
        debugPrint('LocalReminders.scheduleIn failed: $e2');
        return null;
      }
    }
  }

  /// Kurulmuş bir hatırlatmayı iptal eder.
  static Future<void> cancel(int id) async {
    if (!await _ensureReady()) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('LocalReminders.cancel failed: $e');
    }
  }
}
