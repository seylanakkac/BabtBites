/**
 * BabyBites — bildirim gönderici (Cloud Functions).
 *
 * NEDEN SUNUCU GEREKİYOR: FCM'e mesaj göndermek yönetici (admin) yetkisi
 * ister ve bunun anahtarı bir istemci uygulamasına GÖMÜLEMEZ — gömülse
 * herkes tüm kullanıcılara bildirim atabilirdi. Bu yüzden uygulama yalnızca
 * Firestore'a bir "duyuru" kaydı yazıyor, gönderimi buradaki tetikleyici
 * yapıyor.
 *
 * NEDEN TOKEN SAKLANMIYOR: alternatif, her kullanıcının FCM token'ını
 * Firestore'da tutup tek tek göndermek. Bunun yerine istemci KONULARA
 * (topic) abone oluyor (bkz. lib/services/push_notifications.dart):
 *   • all       → herkes
 *   • age_m<N>  → bebeği N aylık olanlar
 * Böylece token saklama, kullanıcı başına okuma ve fan-out maliyeti yok.
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
// Kullanıcıların tamamı Türkiye'de; en yakın bölge gecikmeyi düşürüyor.
setGlobalOptions({region: "europe-west1", maxInstances: 5});

/** Bir bebeğin takip edilebileceği en büyük ay yaşı (age_m0 … age_m36). */
const MAX_AGE_MONTHS = 36;

/**
 * Duyuru kaydı oluşunca telefon bildirimi gönderir.
 *
 * İki hedefleme biçimi var:
 *   • minMonth YOK  → "all" konusu (klasik duyuru/indirim)
 *   • minMonth VAR  → age_m{minMonth} … age_m36 konuları (yaşa uygun tarif)
 *
 * Yaş hedeflemesi için tek bir konu yetmiyor: 6+ ay bir tarif, bebeği 6, 7,
 * 8 … aylık olan HERKESE gitmeli. FCM koşulları (condition) en fazla 5 konu
 * destekliyor, bu yüzden ilgili konulara ayrı ayrı gönderiliyor. Tarif ekleme
 * seyrek bir işlem olduğu için bu maliyet önemsiz.
 */
exports.sendBroadcastPush = onDocumentCreated("notifications/{id}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const n = snap.data() || {};

  // Yalnızca herkese açık ve push işaretli kayıtlar. Kullanıcıya özel
  // bildirimler (toUid = gerçek uid) uygulama içinde kalır.
  if (n.push !== true) return;
  if (n.toUid !== "ALL") return;
  if (n.pushed === true) return; // yeniden deneme/çift tetiklemeye karşı

  const title = String(n.title || "BabyBites");
  const body = String(n.body || "");

  // Bildirime dokununca uygulama bu verilerle açılır.
  const data = {
    type: String(n.type || "announcement"),
    link: String(n.link || ""),
    recipeId: String(n.recipeId || ""),
    notificationId: event.params.id,
  };

  const topics = [];
  const minMonth = Number.isFinite(Number(n.minMonth)) ? Number(n.minMonth) : null;
  if (minMonth === null) {
    topics.push("all");
  } else {
    const from = Math.max(0, Math.min(minMonth, MAX_AGE_MONTHS));
    for (let m = from; m <= MAX_AGE_MONTHS; m++) topics.push(`age_m${m}`);
  }

  const message = {
    notification: {title, body},
    data,
    android: {priority: "high", notification: {channelId: "babybites_news"}},
    apns: {payload: {aps: {sound: "default", badge: 1}}},
  };

  const results = await Promise.allSettled(
      topics.map((t) => admin.messaging().send({...message, topic: t})),
  );
  const failed = results.filter((r) => r.status === "rejected");
  if (failed.length) {
    console.error(`Push: ${failed.length}/${topics.length} konu başarısız`,
        failed[0].reason && failed[0].reason.message);
  }

  // İşaretle ki yeniden çalıştırılırsa aynı bildirim ikinci kez gitmesin.
  await snap.ref.set({
    pushed: true,
    pushedAt: admin.firestore.FieldValue.serverTimestamp(),
    pushTopicCount: topics.length,
  }, {merge: true});
});


// ---------------------------------------------------------------------------
// Instagram gönderilerini çekme
// ---------------------------------------------------------------------------

/**
 * Instagram uzun ömürlü erişim jetonu.
 *
 * NEDEN SUNUCUDA: ilk tasarımda jeton lib/config/instagram_config.dart
 * içindeydi. İki ayrı sızıntı yolu vardı:
 *   1. Depo GitHub'da HERKESE AÇIK — jeton doğrudan yayınlanmış olurdu.
 *   2. Açık olmasa bile sabit, uygulama paketine gömülür; uygulamayı
 *      indiren herkes ikili dosyadan çıkarabilir.
 * Firebase gizli anahtarı olarak yalnızca fonksiyonun çalışma ortamında
 * bulunuyor; istemciye hiç gitmiyor.
 *
 * Ayarlamak için:
 *   firebase functions:secrets:set INSTAGRAM_TOKEN
 *   firebase functions:secrets:set INSTAGRAM_USER_ID
 */
const INSTAGRAM_TOKEN = defineSecret("INSTAGRAM_TOKEN");
const INSTAGRAM_USER_ID = defineSecret("INSTAGRAM_USER_ID");

/** Yönetici e-postaları — firestore.rules'daki isAdmin() ile aynı liste. */
const ADMIN_EMAILS = ["seylanakkac@gmail.com", "admin@babybites.com"];

/**
 * Admin panelinin çağırdığı uç: hesabın son gönderilerini döndürür.
 *
 * Yalnızca YÖNETİCİ çağırabilir. Kimlik doğrulaması sunucuda yapılıyor;
 * istemcide gizlemek yeterli olmazdı — çağrı doğrudan da yapılabilir.
 */
exports.instagramMedia = onCall(
    {secrets: [INSTAGRAM_TOKEN, INSTAGRAM_USER_ID], region: "europe-west1"},
    async (request) => {
      const email = request.auth && request.auth.token && request.auth.token.email;
      if (!email || !ADMIN_EMAILS.includes(email)) {
        throw new HttpsError("permission-denied", "Bu işlem yalnızca yöneticiye açık.");
      }

      const token = INSTAGRAM_TOKEN.value();
      const userId = INSTAGRAM_USER_ID.value();
      if (!token || !userId) {
        throw new HttpsError("failed-precondition",
            "Instagram bağlantısı kurulmamış (INSTAGRAM_TOKEN / INSTAGRAM_USER_ID).");
      }

      const limit = Math.min(Number(request.data && request.data.limit) || 25, 50);
      const fields = "id,caption,media_type,media_url,thumbnail_url,permalink,timestamp";
      const url = `https://graph.facebook.com/v21.0/${userId}/media` +
          `?fields=${fields}&limit=${limit}&access_token=${encodeURIComponent(token)}`;

      const res = await fetch(url);
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        const err = body && body.error;
        // 190 = jetonun süresi doldu. Ayrı mesaj veriyoruz; yoksa "liste boş"
        // gibi görünüp saatlerce yanlış yerde aranıyor.
        const msg = err && err.code === 190
          ? "Erişim jetonunun süresi dolmuş. Yeni bir uzun ömürlü jeton üretip " +
            "firebase functions:secrets:set INSTAGRAM_TOKEN ile güncelleyin."
          : `Instagram hatası: ${(err && err.message) || res.status}`;
        throw new HttpsError("unavailable", msg);
      }

      const data = Array.isArray(body.data) ? body.data : [];
      // VIDEO gönderilerinde media_url oynatma bağlantısıdır; kapak için
      // thumbnail_url kullanılıyor.
      return {
        posts: data.map((e) => ({
          id: String(e.id || ""),
          caption: String(e.caption || ""),
          mediaUrl: String((e.media_type === "VIDEO" ? e.thumbnail_url : e.media_url) || ""),
          permalink: String(e.permalink || ""),
          timestamp: String(e.timestamp || ""),
        })).filter((e) => e.mediaUrl),
      };
    });
