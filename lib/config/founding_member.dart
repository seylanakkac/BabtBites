/// "Kurucu üye" tanımı ve hediyesi.
///
/// BabyBites'ın ilk kullanıcıları (bu sürüm yayına çıkmadan önce kaydolanlar)
/// uygulamayı ortada çok az şey varken kullandı. Bazı özellikler BabyBites+ ile
/// ücretli hâle gelirken onlardan bir şey geri almamak için kurucu üye statüsü
/// tanımlandı.
library;

/// Bu andan ÖNCE hesabı oluşturulmuş kullanıcılar kurucu üyedir.
///
/// Kaynak: Firebase Auth'un kendi `user.metadata.creationTime` alanı — ek bir
/// veritabanı kaydı gerekmez ve ileride sunucu tarafında da doğrulanabilir.
///
/// ⚠️ SÜRÜM YAYINA ÇIKMADAN ÖNCE yayın gününe güncelle. Tarih geçmişte
/// kalırsa aradaki yeni kullanıcılar hediyeyi alamaz; ileride kalırsa
/// "kurucu üye" anlamını yitirir.
final DateTime kFoundingCutoff = DateTime.utc(2026, 8, 5);

/// Kurucu üyelere verilen reklamsız kullanım süresi (gün).
const int kFoundingAdFreeDays = 90;

/// Teşekkür ekranı gösterilsin mi?
///
/// KAPALI (04.08.2026): metin "bazı özellikleri ücretli hâle getiriyoruz"
/// diyor ama premium satışı henüz başlamadı (kPremiumEnabled == false, IAP
/// yok). Olmayan bir değişikliği duyurmak kafa karıştırır ve verilen sözü
/// erkene çeker.
///
/// ABONELİK YAYINA ALINDIĞINDA true yap — kurucu üye tespiti, hediye ve ekran
/// hazır, tek yapılacak bu bayrak ve [kFoundingCutoff] tarihini güncellemek.
const bool kFoundingThanksEnabled = false;
