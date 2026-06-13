# BabyBites — Firebase (Hesap + Bulut Senkron) Kurulum Planı

> Hedef: Kullanıcılar **hesap oluştursun**, **birden çok cihazda giriş** yapabilsin, uygulamayı **silip tekrar kurduğunda verileri geri gelsin**. ~20.000 kullanıcı ölçeğine sağlam temel.

---

## 1) Plan seçimi: **Blaze** (kullandıkça öde) — Spark değil

- Spark'ın günlük ücretsiz Firestore limiti (50K okuma / 20K yazma) **20K kullanıcıda çok çabuk aşılır** ve aşınca uygulama **durur** (hard cap).
- **Blaze**: aynı ücretsiz kotayı içerir ama üstüne **otomatik ölçeklenir** ve duraklamaz. Kullanım az olduğu için **maliyet düşüktür**.
- **Mutlaka bütçe alarmı kur** (ör. 10–20 USD): Console → Billing → Budgets & alerts.

**Kaba maliyet tahmini (20K kullanıcı, günde ~1–2 açılış):**
- Firestore okuma: doküman-başına okuma modeliyle ayda ~birkaç milyon okuma → **birkaç USD**.
- Storage (fotoğraflar): boyuta bağlı; küçültülmüş fotoğraflarla **birkaç USD**.
- Auth: ücretsiz.
- **Toplam: aylık genelde tek haneli USD** seviyesinde başlar.

---

## 2) Kullanılacak Servisler

| Servis | Ne için |
|---|---|
| **Authentication** | Hesap (e-posta/şifre). İsteğe bağlı Google/Apple. |
| **Cloud Firestore** | Kullanıcı verisi + ortak katalog (gıda/tarif/yazı). |
| **Cloud Storage** | Fotoğraflar (base64 yerine gerçek dosya). |

---

## 3) Veri Modeli (önerilen)

### A) Kullanıcıya özel veri (gizli, senkron, reinstall'da geri gelir)
```
/users/{uid}                      → { parent:{name,relationship}, settings, cart, favorites, weeklyPlan }
/users/{uid}/babies/{babyId}      → { name, gender, dob, weight, height, avatar }
/users/{uid}/tracking/{babyId}    → { foodStates, reminders, meds, dailyLogs }
```
- Fotoğraflar: `Storage: /users/{uid}/photos/...` (Firestore'a base64 koyma — 1 MB doküman limiti).

### B) Ortak katalog (yöneticinin yönettiği, herkes okur)
```
/catalog/foods        /catalog/recipes        /catalog/articles
/catalog/config       (kategoriler, market linkleri, birimler, beslenme hedefleri…)
```
- **Neden merkezi?** Şu an admin içeriği her cihazda ayrı (localStorage) tutuluyor; bu üründe yanlış. Merkezi olunca **senin yaptığın gıda/tarif/yazı düzenlemelerini tüm kullanıcılar görür**.

---

## 4) Güvenlik Kuralları (özet mantık)
```
// users: herkes sadece KENDİ verisine erişir
match /users/{uid}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
// catalog: herkes okur, sadece admin yazar (custom claim: admin==true)
match /catalog/{document=**} {
  allow read: if true;
  allow write: if request.auth != null && request.auth.token.admin == true;
}
```
- Admin yetkisi: senin hesabına **custom claim (admin:true)** atanır (tek seferlik script/Cloud Function ile).

---

## 5) Yerelden Buluta Geçiş (migration)
- İlk girişte: cihazda mevcut yerel veri varsa, **bir kez buluta yüklenir**, sonra kaynak olarak bulut kullanılır.
- Çevrimdışı: Firestore **offline cache** açık → internet yokken de çalışır, gelince senkronlar.

---

## 6) SENİN YAPMAN GEREKENLER (Firebase Console — hesabın gerekli)

1. **Firebase projesi oluştur:** https://console.firebase.google.com → Add project (ör. `babybites-prod`).
2. **Authentication** → Get started → **Email/Password** sağlayıcısını **Enable**.
3. **Firestore Database** → Create database → **Production mode** → konum: **eur3 (europe-west)** (Türkiye'ye yakın).
4. **Storage** → Get started → Production mode.
5. **Blaze planına yükselt** (Billing) ve **bütçe alarmı** (10–20 USD) kur.
6. Bilgisayarda (tek seferlik):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   cd C:\Users\Lexth3r\Desktop\BabyBites
   flutterfire configure   # projeni seç → lib/firebase_options.dart üretir
   ```
7. Bana **"flutterfire configure bitti"** de — gerisini kodda ben yaparım.

---

## 7) BENİM YAPACAKLARIM (kod — fazlı)

**Faz 1 — Temel + Giriş**
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` paketleri.
- `main()` içinde Firebase init.
- Gerçek **Kayıt / Giriş / Şifremi unuttum** (login_screen'i Firebase Auth'a bağla).
- Oturum durumuna göre yönlendirme (giriş yoksa login, varsa app).

**Faz 2 — Kullanıcı verisi senkron**
- `CloudRepository`: babies/tracking/cart/favorites/weeklyPlan'ı `/users/{uid}` altına yaz/oku.
- `StorageService`'i repository'ye dönüştür (yerel cache + bulut).
- İlk girişte yerel → bulut migration.

**Faz 3 — Ortak katalog + admin**
- Admin CMS, `/catalog/*`'a yazar; istemciler okur.
- Admin custom claim; güvenlik kuralları deploy.

**Faz 4 — Fotoğraflar Storage'a**
- Fotoğraf yükleme → Storage URL; base64'ten geçiş.

---

## 8) Önemli Notlar
- **Apple kuralı:** Yalnızca Google ile giriş eklersen Apple "Sign in with Apple" da ister. **Sadece e-posta/şifre** kullanırsan bu zorunluluk yok — başlangıç için en sade yol.
- **KVKK:** Artık veriyi buluta (yurt dışı sunucu olabilir) aktarıyorsun → Gizlilik Politikası'nın 3. maddesini güncelleyeceğiz (açık rıza + yurt dışı aktarım bilgisi). Bunu Faz 1'de yapacağım.
- **Yedek/çift yazma:** Geçiş döneminde yerel kalıcılığı bir süre koruyup paralel yazmak güvenlidir.

---

*Hazır olduğunda: önce Bölüm 6'daki adımları yap, `flutterfire configure`'ı çalıştır, sonra bana haber ver — Faz 1'den koda başlarım.*
