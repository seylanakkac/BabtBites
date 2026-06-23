/// Web Push (FCM) VAPID açık anahtarı.
///
/// NASIL ALINIR:
/// Firebase Console → Proje Ayarları → Cloud Messaging → "Web push certificates"
/// → "Generate key pair" → çıkan **anahtar çiftini (public key)** buraya yapıştır.
/// Boşken bildirim açma denemesi sessizce başarısız olur (uygulama bozulmaz).
const String kFcmVapidKey = "BBCpoITfEnO1TGMl31efrZtsULEposCvToq2APissOzeV7fI-khxNon1QGN0X8zHhoRdrKwa7dNxuPuHJ_7LZBw";

bool get pushConfigured => kFcmVapidKey.isNotEmpty;
