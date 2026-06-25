// Google ile giriş (native Android/iOS) yapılandırması.
//
// `serverClientId` = Firebase'in oluşturduğu "Web istemci kimliği":
//   Firebase Console → Authentication → Sign-in method → Google →
//   "Web SDK configuration" → Web client ID
//   (biçim: 951840473715-xxxxxxxx.apps.googleusercontent.com)
//
// Boş bırakılırsa giriş accessToken ile yapılır (genelde yeterlidir); ancak
// sunucu tarafı doğrulanabilir idToken almak için doldurulması önerilir.
const String kGoogleServerClientId =
    '951840473715-93fkk1icif5ni8vredq0k66pkr4h13mr.apps.googleusercontent.com';
