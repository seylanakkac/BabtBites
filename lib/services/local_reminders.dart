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
    final id = _nextId();
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

  /// HER GÜN aynı saatte tekrarlayan bir hatırlatma kurar (ör. "sabah 09:00
  /// demir damlası"). Kurulamazsa null döner; dönen kimlik iptal için saklanmalı.
  ///
  /// Bugünkü saat geçmişse ilk bildirim YARIN çalar — `matchDateTimeComponents`
  /// yalnızca saati eşleştirdiği için tarih kendiliğinden ilerler.
  static Future<int?> scheduleDailyAt({
    required int hour,
    required int minute,
    required String title,
    required String body,
    int? id,
  }) async {
    if (!await _ensureReady()) return null;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    final nid = id ?? _nextId();
    for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
      try {
        await _plugin.zonedSchedule(
          nid, title, body, when, _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time, // her gün tekrar
        );
        return nid;
      } catch (e) {
        debugPrint('LocalReminders.scheduleDailyAt ($mode) failed: $e');
      }
    }
    return null;
  }

  /// Çakışmayan bildirim kimliği. Aynı milisaniyede birden çok hatırlatma
  /// kurulabildiği için (bir ilacın 3 saati) sayaçla ayrıştırılıyor —
  /// yoksa ikinci bildirim birincinin üzerine yazardı.
  static int _seq = 0;
  static int _nextId() {
    _seq = (_seq + 1) % 100000;
    return (DateTime.now().millisecondsSinceEpoch + _seq).remainder(1 << 31);
  }

  /// Bir (ilaç, saat) çifti için DEĞİŞMEZ bildirim kimliği.
  ///
  /// Rastgele kimlik yerine türetilmiş kimlik kullanmak, aynı planı birden
  /// çok kez zamanlamayı zararsız kılıyor (aynı kimlik üzerine yazılır,
  /// kopya bildirim oluşmaz). [syncMedReminders] buna dayanıyor.
  static int dailyIdFor(String medId, String hm) {
    var h = 0;
    for (final c in '$medId@$hm'.codeUnits) {
      h = (h * 31 + c) & 0x3FFFFFFF; // 30 bit: 32-bit int sınırında kal
    }
    return h;
  }

  /// Cihazdaki günlük ilaç hatırlatmalarını kayıtlı planla EŞİTLER.
  ///
  /// NEDEN GEREKLİ: bildirim yalnızca "Kaydet" anında ve o cihazda kuruluyordu.
  /// Planı web'den (yerel bildirim desteği yok) ya da başka bir telefondan
  /// kuran kullanıcının bu cihazında hiçbir alarm olmuyordu — özellik sessizce
  /// çalışmıyordu. Bu yüzden açılışta plan ile cihaz alarmları karşılaştırılıyor.
  ///
  /// [desired] her biri (medId, time, title, body) olan hedef liste.
  /// [previousIds] bu cihazda en son kurulmuş kimlikler; artık planda olmayanlar
  /// iptal edilir. Dönen küme çağıran tarafından saklanmalı.
  ///
  /// Tek seferlik doz hatırlatmalarına ("6 saat sonra") DOKUNMAZ — onların
  /// kimlikleri bu türetilmiş kümede yer almaz.
  static Future<Set<int>> syncMedReminders(
    List<({String medId, String time, String title, String body})> desired, {
    required Set<int> previousIds,
  }) async {
    if (!available) return const {};
    final wanted = {for (final d in desired) dailyIdFor(d.medId, d.time)};
    // Planda olmayan eski alarmlar (saat silinmiş / ilaç kaldırılmış).
    await cancelAll(previousIds.difference(wanted));
    if (desired.isEmpty) return const {};
    if (!await _ensureReady()) return previousIds;
    final ok = <int>{};
    for (final d in desired) {
      final p = d.time.split(':');
      final h = int.tryParse(p.first);
      final m = p.length > 1 ? int.tryParse(p[1]) : null;
      if (h == null || m == null) continue;
      final id = await scheduleDailyAt(
        hour: h,
        minute: m,
        title: d.title,
        body: d.body,
        id: dailyIdFor(d.medId, d.time),
      );
      if (id != null) ok.add(id);
    }
    return ok;
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

  /// Birden çok hatırlatmayı iptal eder (bir ilacın tüm saatleri).
  static Future<void> cancelAll(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }
}
