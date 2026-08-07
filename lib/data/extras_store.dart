import '../config/premium_config.dart';

// Extra engagement/premium state (local; persisted by StorageService).
// - Growth measurements over time (for the growth chart).
// - Milestone "done" toggles (development & teeth calendar).
// - Premium (BabyBites+) flag + trial start (real billing comes later with
//   store in-app purchase / Firebase).

/// babyId -> list of measurements.
/// Shape: { "date":"yyyy-MM-dd", "weight":double, "height":double, "head":double }
final Map<String, List<Map<String, dynamic>>> globalGrowthRecords = {};

List<Map<String, dynamic>> growthFor(String babyId) =>
    globalGrowthRecords.putIfAbsent(babyId, () => []);

/// babyId -> set of completed milestone ids.
final Map<String, Set<String>> globalMilestonesDone = {};

Set<String> milestonesDoneFor(String babyId) =>
    globalMilestonesDone.putIfAbsent(babyId, () => <String>{});

/// BabyBites+ premium flag (demo). When store IAP / Firebase is added, this is
/// driven by the real subscription state.
bool globalIsPremium = false;

/// Premium özelliklere erişim hakkı.
///
/// Premium satışı kapalıyken (kPremiumEnabled == false) kilit yoktur; tüm
/// özellikler herkese açıktır. Bkz. lib/config/premium_config.dart
bool premiumUnlocked() => !kPremiumEnabled || globalIsPremium;

/// ISO date the free trial started (or null).
String? globalTrialStart;

/// Zaman-sınırlı premium'un (deneme veya promosyon kodu) bitiş tarihi (ISO).
/// null → zaman sınırı yok. Süre dolunca bir sonraki yüklemede premium kapanır.
String? globalPremiumUntil;

/// Belirtilen gün kadar premium uygular (deneme veya promosyon kodu). Var olan
/// süre devam ediyorsa üzerine ekler (uzatır) ve premium'u açar.
void applyPremiumForDays(int days) {
  final now = DateTime.now();
  var base = now;
  final cur = globalPremiumUntil != null ? DateTime.tryParse(globalPremiumUntil!) : null;
  if (cur != null && cur.isAfter(now)) base = cur;
  globalPremiumUntil = base.add(Duration(days: days)).toIso8601String();
  globalIsPremium = true;
}

/// Yüklemede çağrılır: zaman-sınırlı premium süresi dolduysa premium'u kapatır.
void refreshPremiumFromExpiry() {
  final s = globalPremiumUntil;
  if (s == null) return;
  final until = DateTime.tryParse(s);
  if (until == null) return;
  if (until.isAfter(DateTime.now())) {
    globalIsPremium = true;
  } else {
    globalPremiumUntil = null;
    globalIsPremium = false;
  }
}

/// babyId -> list of uploaded report/document files (e.g. e-Nabız PDFs).
/// Item shape: { "name": String, "date": "yyyy-MM-dd", "dataUri": "data:application/pdf;base64,..." }
/// Stored LOCALLY only for now (files are large); moves to Firebase Storage in Faz 4.
final Map<String, List<Map<String, dynamic>>> globalReportFiles = {};

/// Uploaded documents for a baby (mutable list, created if absent).
List<Map<String, dynamic>> reportFilesFor(String babyId) =>
    globalReportFiles.putIfAbsent(babyId, () => []);

/// Temporary ad-free window earned by watching a rewarded ad (ISO8601), or null.
/// While active (and the user isn't premium), ad banners are hidden.
String? globalAdFreeUntil;

/// Reklamsız hakkı kapatırken yazılan geçmiş tarih ("mezar taşı").
///
/// ⚠️ `globalAdFreeUntil = null` YAPMA. saveExtras/saveAll o durumda prefs
/// anahtarını SİLİYOR; `exportUserData` yalnızca prefs'te var olan anahtarları
/// topladığı için alan buluta hiç gitmiyor ve `CloudSync.push`'un
/// `merge: true` ayarı Firestore'daki ESKİ tarihe dokunmuyor. Bir sonraki
/// `pull()` o tarihi geri indirip hakkı diriltiyor — kullanıcı "kapattım"
/// dediği hâlde reklamlar yine görünmüyor.
///
/// Geçmiş bir tarih yazmak alanı prefs'te tutuyor, buluta gönderiyor ve eski
/// değerin üzerine yazıyor.
final String kAdFreeRevokedMarker = DateTime.utc(2000).toIso8601String();

/// Reklamsız dönemi kapatır (buluta da yansıyacak biçimde).
void clearAdFreeUntil() {
  globalAdFreeUntil = kAdFreeRevokedMarker;
}

/// Reklamsız dönem aktif mi? ARTIK HER ZAMAN false.
///
/// Reklamsız hak veren iki sistem de kaldırıldı (kurucu üye hediyesi ve
/// ödüllü reklamın 1 günlük penceresi), çünkü reklamlar uygulamanın tek gelir
/// kaynağı. Fonksiyon SİLİNMİYOR, sabitleniyor: eski kurulumlarda ve bulutta
/// hâlâ ileri tarihli `ad_free_until` değerleri var; bu değerler
/// [revokeAllAdFree] ile temizlenene kadar tek bir çağrı bile reklamları
/// gizlemeye yeter. Burada false döndürmek o yarışı tamamen kapatıyor.
bool adFreeActive() => false;

/// The current user's in-app notifications (loaded from Firestore
/// /notifications). Item: { id, title, body, type, read, date }.
final List<Map<String, dynamic>> globalNotifications = [];

/// Number of unread notifications (for the bell badge).
int unreadNotificationCount() =>
    globalNotifications.where((n) => n["read"] != true).length;

/// featureKey -> ISO time until which a rewarded-ad temporary unlock is active.
/// Lets non-premium users open a specific premium feature by watching an ad.
final Map<String, String> globalFeatureUnlocks = {};

/// True if [key] has an active rewarded-ad unlock window.
bool featureUnlocked(String key) {
  final s = globalFeatureUnlocks[key];
  if (s == null) return false;
  final until = DateTime.tryParse(s);
  return until != null && until.isAfter(DateTime.now());
}
