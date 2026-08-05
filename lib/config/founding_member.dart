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
/// Metin "bazı özellikleri ücretli hâle getiriyoruz" diyor; premium satışı
/// gerçekten başlamadan çok önce göstermek kafa karıştırır. IAP hazır
/// olmadığında kapatmak için bu bayrağı false yap.
const bool kFoundingThanksEnabled = true;
