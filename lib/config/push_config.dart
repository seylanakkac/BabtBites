/// Web Push (FCM) VAPID açık anahtarı.
///
/// NASIL ALINIR:
/// Firebase Console → Proje Ayarları → Cloud Messaging → "Web push certificates"
/// → "Generate key pair" → çıkan **anahtar çiftini (public key)** buraya yapıştır.
/// Boşken bildirim açma denemesi sessizce başarısız olur (uygulama bozulmaz).
const String kFcmVapidKey = "";

bool get pushConfigured => kFcmVapidKey.isNotEmpty;
