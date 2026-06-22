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
const String kAdsenseClient = ""; // ör. "ca-pub-1234567890123456"
const String kAdsenseBannerSlot = ""; // yatay banner reklam birimi data-ad-slot
const String kAdsenseSideSlot = ""; // dikey skyscraper reklam birimi data-ad-slot

/// AdSense kimliği girilmiş mi?
bool get adsConfigured => kAdsenseClient.isNotEmpty;
