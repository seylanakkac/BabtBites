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
