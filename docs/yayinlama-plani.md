# BabyBites — Yayınlama Yol Haritası

> Bu doküman; uygulamanı web ve mobil mağazalarda yayınlaman için adım adım plan, Firebase/Hosting kurulumu ve Türkiye'de **şirketsiz (istisna belgesi)** yol için rehberdir. Vergi/hukuk kısımları **bilgilendirme amaçlıdır**; kesin işlem öncesi bir **mali müşavir (SMMM)** ve **vergi dairesi** ile teyit et.

---

## 0) Uygulama "yayına hazır" mı? (Önce bunlar)

- [x] Kalıcılık (yerel) çalışıyor
- [x] Tıbbi sorumluluk reddi metinleri eklendi
- [x] Kullanım Koşulları + Gizlilik Politikası (uygulama içi + dosya)
- [ ] **Gizlilik politikasını bir URL'de yayınla** (Hosting ile, aşağıda)
- [ ] Uygulama ikonu + açılış (splash) görselleri (mağaza için yüksek çözünürlük)
- [ ] Mağaza ekran görüntüleri (telefon + tablet) ve açıklama metinleri
- [ ] Admin girişini gizle/koru (admin@babybites.com sabit şifre yerine güvenli hale getir — Firebase Auth ile rol)
- [ ] Sürüm numarası (`pubspec.yaml` → `version: 1.0.0+1`)
- [ ] Gerçek cihazda test (Android/iOS)

> **Not (mevcut durum):** Uygulama şu an **yalnızca cihazda** veri tutuyor; bulut/giriş yok. Bu haliyle yayınlanabilir. Çok cihaz senkronu/hesap istiyorsan Firebase göçü (Bölüm 3) gerekir.

---

## 1) Web Sürümü + Firebase Hosting (en hızlı yayın)

Spark (ücretsiz) plan Hosting için yeterlidir.

**Kurulum (tek seferlik):**
```bash
npm install -g firebase-tools
firebase login
cd C:\Users\Lexth3r\Desktop\BabyBites
firebase init hosting
#  - "Use an existing project" → Firebase Console'da oluşturduğun projeyi seç
#  - public directory:  build/web
#  - single-page app (rewrite all urls to /index.html): Yes
#  - automatic builds with GitHub: No (şimdilik)
```

**Her yayında:**
```bash
flutter build web --web-renderer html
firebase deploy --only hosting
```
- Yayın adresi: `https://PROJE-ADI.web.app` (ücretsiz). İstersen **özel alan adı** (ör. babybites.com) bağlayabilirsin: Console → Hosting → Add custom domain.

**Gizlilik politikası/koşullar URL'si:** `legal/*.md` dosyalarını basit HTML'e çevirip web build'e koy ya da Notion/GitHub Pages'te yayınla. Mağaza formlarında bu URL istenir.

> **Firebase Spark limitleri (özet):** Hosting depolama 10 GB, aylık ~360 MB/gün indirme; Firestore 1 GB depolama, günlük 50K okuma / 20K yazma; Auth ücretsiz. **Cloud Functions Spark'ta yok** (Blaze gerekir). Bu uygulama için Spark başlangıçta yeterli.

---

## 2) Mobil Mağazalar

### A) Google Play (Android) — daha kolay/ucuz
1. **Google Play Developer** hesabı: tek seferlik **25 USD**. (Bireysel hesap açılır.)
2. Sürüm derle:
   ```bash
   flutter build appbundle   # .aab üretir
   ```
   İmzalama anahtarı (keystore) oluştur ve `key.properties` ile imzala (Flutter dokümanındaki "Signing the app" adımları).
3. Play Console → Uygulama oluştur → mağaza kaydı (açıklama, ekran görüntüleri, ikon, kategori: "Sağlık ve Fitness" veya "Ebeveynlik").
4. **Veri güvenliği formu** (Data Safety): "Veriler cihazda saklanır, sunucuya gönderilmez" beyanı (uygulamanın gerçeğine göre).
5. **Gizlilik Politikası URL'si** zorunlu (Bölüm 1).
6. İçerik derecelendirme anketi, hedef kitle (yetişkin/ebeveyn — çocuklara yönelik DEĞİL olarak işaretle).
7. Kapalı test (internal testing) → sonra production.

### B) Apple App Store (iOS) — daha katı/pahalı
1. **Apple Developer Program**: yıllık **99 USD**. (Bireysel olarak kaydolabilirsin; **Mac** + Xcode gerekir.)
2. Xcode ile `flutter build ipa`, App Store Connect'e yükle (Transporter/Xcode).
3. App Store Connect → uygulama kaydı, ekran görüntüleri, açıklama.
4. **App Privacy** bölümü (veri toplama beyanı), **Gizlilik Politikası URL'si**.
5. **Sağlık/tıbbi** uygulamalar için: tıbbi tavsiye vermediğini, bilgilendirme amaçlı olduğunu net belirt (App Review Guideline 1.4.1 / 5.x). Senin eklediğimiz disclaimer'lar bunun için.
6. İncelemeye gönder (genelde 1–3 gün).

> **Önemli (reddi önleme):** Her iki mağazada da (1) çalışan gizlilik politikası URL'si, (2) tıbbi sorumluluk reddi, (3) doğru veri beyanı, (4) çocuğa değil ebeveyne yönelik hedefleme şart. Bunlar tamam.

---

## 3) (Opsiyonel/İleride) Firebase ile Bulut + Hesap

Çok cihaz senkronu, gerçek admin rolü ve yedeklilik istiyorsan:
- **Firebase Auth**: sahte admin yerine gerçek giriş + admin custom claim.
- **Cloud Firestore**: `shared_preferences` global'leri → koleksiyonlar.
- **Firebase Storage**: base64 fotoğraflar → gerçek dosya.
- Kurulum: `flutterfire configure` (Firebase projen gerekir).
- Bu, veri katmanının yeniden yazımıdır → ayrı bir faz olarak planlanmalı. Tasarım dondurulunca yapılır.

> Spark plan başlangıç için yeterli; çok kullanıcı/işlev artarsa **Blaze** (kullandıkça öde) gerekebilir.

---

## 4) Türkiye'de Şirketsiz Yol: Mobil Uygulama Kazanç İstisnası ("istisna belgesi")

Türkiye'de **şirket kurmadan** uygulama geliri elde etmenin yasal yolu, **Gelir Vergisi Kanunu Mükerrer Madde 20/B** kapsamındaki **"sosyal içerik üreticiliği ve mobil cihazlar için uygulama geliştiriciliğinde kazanç istisnası"**dır. Senin "istisna belgesi" dediğin budur.

**Özet mantık:**
- Google Play / App Store gibi platformlardan elde ettiğin uygulama geliri, **belirli bir yıllık tutara kadar gelir vergisinden istisna** edilir.
- Bu istisnadan yararlanmak için **tam mükellefiyet/şirket kurmana gerek yoktur**; bunun yerine vergi dairesinden **istisna belgesi** alıp, geliri **özel bir banka hesabından** geçirirsin.
- Banka, bu hesaba gelen tutardan **%15 stopaj** keser; bu, **nihai vergidir** (yıllık beyanname vermezsin) — yıllık gelirin istisna sınırını aşmadığı sürece.

**Adımlar (genel):**
1. **Vergi dairesine** başvurup **istisna belgesi** al (mobil uygulama geliştiricisi olduğunu beyan edersin).
2. Bir bankada bu iş için **özel/münhasır hesap** aç (yalnızca uygulama gelirleri buradan geçmeli).
3. Google/Apple ödemelerini bu hesaba yönlendir.
4. Banka **%15 stopajı** otomatik keser ve vergi dairesine yatırır.
5. **Yıllık gelir, ilgili yılın istisna sınırını** (GVK 103. madde 4. dilim; her yıl güncellenir, 2024 için ~3 milyon TL civarı) **aşmazsa** ek beyan yok.
6. Sınırı **aşarsan** istisna bozulur, **yıllık gelir vergisi beyannamesi** verip normal usulde vergilendirilirsin (o yıl için).

**Avantajları:** Şirket/şahıs işletmesi açma, KDV mükellefiyeti, defter tutma, SGK Bağ-Kur gibi yükler **olmadan** başlayabilirsin (istisna kapsamında kaldığın sürece).

**Dikkat / mutlaka teyit et:**
- İstisna **yalnızca uygulama mağazası gelirleri** içindir (uygulama içi satış/reklam gelirleri için kapsamı SMMM'ye danış).
- Sınır tutarları ve usul **her yıl değişir** → güncel rakamı vergi dairesi/SMMM'den al.
- Genç girişimci isteğine göre **şahıs şirketi + genç girişimci istisnası** alternatif bir yoldur (3 yıl kazanç istisnası + 1 yıl Bağ-Kur teşviki) ama bu defter/mükellefiyet gerektirir. İkisini SMMM ile karşılaştır.

**Apple/Google ödeme için gerekenler:**
- Geçerli bir **TC kimlik / vergi kimlik no**, **IBAN** (yukarıdaki özel hesap), adres ve mağaza vergi anketlerinin doldurulması.
- Apple paralı satış için "Paid Apps Agreement" + banka/vergi bilgisi ister; ücretsiz uygulamada bu zorunlu değildir.

---

## 5) Tahmini Maliyet Özeti

| Kalem | Tutar |
|---|---|
| Google Play geliştirici hesabı | 25 USD (tek sefer) |
| Apple Developer Program | 99 USD / yıl |
| Firebase Hosting (Spark) | Ücretsiz |
| Özel alan adı (opsiyonel) | ~10–15 USD / yıl |
| Mali müşavir (SMMM) danışmanlığı | Değişken (önerilir) |

---

## 6) Önerilen Sıra

1. Web'i Firebase Hosting'e yayınla → gizlilik/koşullar URL'sini al.
2. Mağaza materyallerini hazırla (ikon, ekran görüntüleri, açıklama).
3. **Google Play** ile başla (ucuz/hızlı) → kapalı test → yayın.
4. Gerekirse **App Store** (Mac + 99 USD).
5. Vergi tarafı: SMMM ile **GVK Mük. 20/B istisna belgesi** yolunu netleştir, özel banka hesabını aç.
6. (İleride) Firebase ile bulut/hesap göçü.

---

*Bu doküman bilgilendirme amaçlıdır; vergi/hukuk işlemleri için yetkili mali müşavir ve vergi dairesi ile teyit alın. Rakamlar ve mağaza politikaları zamanla değişebilir.*
