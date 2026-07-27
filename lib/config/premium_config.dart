// BabyBites+ (abonelik) özelliğinin ana açma/kapama bayrağı.
//
// NEDEN KAPALI (v1.0):
// App Store Review Guideline 3.1.1 — ücretli içerik/işlev yalnızca In-App
// Purchase ile satılabilir ve açılabilir. Uygulamada IAP entegrasyonu henüz
// yok; abonelik satışı, "7 gün ücretsiz deneme" ve promosyon koduyla premium
// açma bu nedenle 26.07.2026'da reddedildi (Submission c9588afc).
//
// Bayrak false iken:
//   • BabyBites+ satış ekranı, fiyat, deneme butonu ve promosyon kodu gizlenir.
//   • Premium özellikler (büyüme grafiği, gelişim takvimi, rapor, sınırsız
//     bebek profili) TÜM kullanıcılara açıktır — kilit gösterilmez.
//   • Ödüllü reklam ile geçici reklamsız kullanım özelliği çalışmaya devam
//     eder (Apple bunu satın alma saymaz).
//
// IAP (in_app_purchase / StoreKit) tamamlanınca bu bayrağı true yap; kilitler
// ve satış ekranı olduğu gibi geri gelir.
const bool kPremiumEnabled = false;
