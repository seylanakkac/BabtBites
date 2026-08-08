/// Instagram içe aktarma yapılandırması.
///
/// NE İŞE YARIYOR: admin panelindeki "Instagram" bölümü, hesabındaki
/// gönderileri (fotoğraf + açıklama) listeler ve seçtiğini TASLAK TARİF
/// olarak açar. Malzeme/miktarları admin tamamlar.
///
/// NEDEN OTOMATİK TARİF ÜRETİLMİYOR: gönderi açıklaması serbest metin.
/// "Malzemeler / yapılışı / porsiyon" alanlarına güvenilir biçimde
/// ayrıştırmak mümkün değil ve yanlış besin değeri üretmek bir bebek
/// beslenme uygulamasında kabul edilebilir bir risk değil. Bu yüzden
/// fotoğraf ve metin taşınıyor, yapı insan eliyle kuruluyor.
///
/// NASIL DOLDURULUR:
/// 1. Instagram hesabın BUSINESS ya da CREATOR olmalı ve bir Facebook
///    sayfasına bağlı olmalı (kişisel hesapta API çalışmıyor).
/// 2. developers.facebook.com → yeni uygulama → "Instagram Graph API"
///    ürününü ekle.
/// 3. Graph API Explorer'dan `instagram_basic` izniyle bir kullanıcı
///    jetonu al, sonra onu UZUN ÖMÜRLÜ jetona çevir (60 gün geçerli).
/// 4. `/me/accounts` → sayfanın `instagram_business_account.id` değerini
///    al; aşağıdaki kInstagramUserId budur.
///
/// ⚠️ JETON 60 GÜNDE BİR YENİLENMELİ. Süresi dolunca içe aktarma
/// "yetkilendirme hatası" verir; panel bunu açıkça yazıyor.
///
/// ⚠️ Bu değerler uygulama paketine gömülür. Jeton YALNIZCA kendi
/// gönderilerini okuma iznine sahip olmalı; yayınlama/silme izni verme.
library;

/// Instagram Business/Creator hesabının sayısal kimliği.
const String kInstagramUserId = "";

/// Uzun ömürlü erişim jetonu (instagram_basic).
const String kInstagramAccessToken = "";

/// İçe aktarma kullanılabilir mi?
bool get instagramConfigured =>
    kInstagramUserId.isNotEmpty && kInstagramAccessToken.isNotEmpty;
