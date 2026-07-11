/// Google AdSense yapılandırması (web reklamları).
///
/// Doldurulunca web'de gerçek reklamlar görünür; boşken mevcut "Reklam alanı"
/// yer-tutucusu gösterilir (uygulama hiç bozulmaz).
///
/// NASIL DOLDURULUR (AdSense ONAYINDAN SONRA):
/// 1. https://adsense.google.com → hesap aç, site olarak babybites.com.tr ekle,
///    onay bekle (sitende içerik + gizlilik politikası olmalı — zaten var).
/// 2. Onaylanınca yayıncı kimliğini al: "ca-pub-XXXXXXXXXXXXXXXX".
/// 3. Reklamlar → "Reklam birimleri" → 2 adet "Görüntülü reklam" oluştur
///    (biri yatay banner, biri dikey/skyscraper). Her birinin "data-ad-slot"
///    numarasını (ör. 1234567890) aşağıya yaz.
/// 4. AdSense'in verdiği doğrulama <script>'ini web/index.html <head>'ine ekle
///    (site doğrulaması için) — index.html'de bunun için işaretli yer var.
const String kAdsenseClient = "ca-pub-4036323836264136"; // yayıncı kimliği
const String kAdsenseBannerSlot = ""; // yatay banner reklam birimi data-ad-slot (onay sonrası doldur)
const String kAdsenseSideSlot = ""; // dikey skyscraper reklam birimi data-ad-slot (onay sonrası doldur)

/// AdSense kimliği girilmiş mi?
bool get adsConfigured => kAdsenseClient.isNotEmpty;

// ---- AdMob (MOBİL uygulama reklamları) ----
// ANDROID: App ID AndroidManifest.xml'de meta-data olarak bulunur:
//   ca-app-pub-4036323836264136~2084738864
const String kAdmobBannerUnitAndroid = "ca-app-pub-4036323836264136/1485973064";
const String kAdmobRewardedUnitAndroid = "ca-app-pub-4036323836264136/6923534942";

// iOS: App ID ios/Runner/Info.plist içindeki GADApplicationIdentifier'dır
// (ca-app-pub-4036323836264136~9572997011). Aşağıdakiler gerçek iOS birimleri.
const String kAdmobBannerUnitIOS = "ca-app-pub-4036323836264136/5608068364";
const String kAdmobRewardedUnitIOS = "ca-app-pub-4036323836264136/8126420492";

/// AdMob banner birimi girilmiş mi?
bool get admobConfigured => kAdmobBannerUnitAndroid.isNotEmpty;
