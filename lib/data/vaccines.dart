// T.C. Sağlık Bakanlığı Çocukluk Çağı Aşı Takvimi (Genişletilmiş Bağışıklama
// Programı) temel alınarak hazırlanmıştır.
//
// ⚠️ MEDİKAL UYARI: Bu takvim GENEL bilgilendirme amaçlıdır ve resmi takvim
// zaman zaman güncellenir. YAYINDAN ÖNCE bir çocuk doktoru / Sağlık Bakanlığı
// güncel takvimiyle DOĞRULANMALIDIR. Uygulama bir hatırlatma aracıdır; aşı
// kararları için mutlaka hekime danışılmalıdır.

class Vaccine {
  final String id;
  final String name; // "Beşli Karma (DaBT-İPA-Hib)"
  final String dose; // "1. doz", "Rapel"
  final int month; // önerilen uygulama ayı (yaş)
  final String against; // kısa açıklama: neye karşı korur
  /// true = ulusal (ücretsiz) takvimde YOK; özel/isteğe bağlı (ücretli) aşı.
  /// Bilgi amaçlı gösterilir; otomatik hatırlatma kurulmaz.
  final bool optional;
  const Vaccine(this.id, this.name, this.dose, this.month, this.against,
      {this.optional = false});
}

/// Ay bazında gruplanmış çocukluk çağı aşıları. `month` = önerilen yaş (ay).
const List<Vaccine> kVaccines = [
  // Doğumda
  Vaccine("hepb1", "Hepatit B", "1. doz", 0, "Karaciğer iltihabı (Hepatit B)"),
  // 1. ayın sonu
  Vaccine("hepb2", "Hepatit B", "2. doz", 1, "Karaciğer iltihabı (Hepatit B)"),
  // 2. ayın sonu
  Vaccine("bcg", "BCG (Verem)", "Tek doz", 2, "Verem (Tüberküloz)"),
  Vaccine("dabt1", "Beşli Karma (DaBT-İPA-Hib)", "1. doz", 2,
      "Difteri, boğmaca, tetanoz, çocuk felci, menenjit"),
  Vaccine("kpa1", "KPA (Konjuge Pnömokok)", "1. doz", 2,
      "Zatürre, menenjit (pnömokok)"),
  // 4. ayın sonu
  Vaccine("dabt2", "Beşli Karma (DaBT-İPA-Hib)", "2. doz", 4,
      "Difteri, boğmaca, tetanoz, çocuk felci, menenjit"),
  Vaccine("kpa2", "KPA (Konjuge Pnömokok)", "2. doz", 4,
      "Zatürre, menenjit (pnömokok)"),
  Vaccine("opa1", "OPA (Oral Çocuk Felci)", "1. doz", 4, "Çocuk felci (polio)"),
  // 6. ayın sonu
  Vaccine("dabt3", "Beşli Karma (DaBT-İPA-Hib)", "3. doz", 6,
      "Difteri, boğmaca, tetanoz, çocuk felci, menenjit"),
  Vaccine("opa2", "OPA (Oral Çocuk Felci)", "2. doz", 6, "Çocuk felci (polio)"),
  Vaccine("hepb3", "Hepatit B", "3. doz", 6, "Karaciğer iltihabı (Hepatit B)"),
  // 12. ay
  Vaccine("kkk1", "KKK (Kızamık-Kızamıkçık-Kabakulak)", "1. doz", 12,
      "Kızamık, kızamıkçık, kabakulak"),
  Vaccine("kpar", "KPA (Konjuge Pnömokok)", "Rapel", 12,
      "Zatürre, menenjit (pnömokok)"),
  Vaccine("sucicegi1", "Suçiçeği", "1. doz", 12, "Suçiçeği"),
  // 18. ay
  Vaccine("dabtr", "Beşli Karma (DaBT-İPA-Hib)", "Rapel", 18,
      "Difteri, boğmaca, tetanoz, çocuk felci, menenjit"),
  Vaccine("hepa1", "Hepatit A", "1. doz", 18, "Karaciğer iltihabı (Hepatit A)"),
  // 24. ay
  Vaccine("hepa2", "Hepatit A", "2. doz", 24, "Karaciğer iltihabı (Hepatit A)"),
  // 48. ay (okul öncesi, ~4 yaş)
  Vaccine("dabt_okul", "DaBT-İPA (Dörtlü Karma)", "Rapel", 48,
      "Difteri, boğmaca, tetanoz, çocuk felci"),
  Vaccine("kkk2", "KKK (Kızamık-Kızamıkçık-Kabakulak)", "2. doz", 48,
      "Kızamık, kızamıkçık, kabakulak"),
  Vaccine("opa3", "OPA (Oral Çocuk Felci)", "3. doz", 48, "Çocuk felci (polio)"),
  Vaccine("sucicegi2", "Suçiçeği", "2. doz", 48, "Suçiçeği"),

  // ----- Özel / isteğe bağlı aşılar (ulusal takvimde YOK, ücretli) -----
  // Bilgi amaçlıdır; marka ve şemaları değişebilir, hekime danışılmalıdır.
  Vaccine("rota1", "Rotavirüs (Rota)", "1. doz", 2,
      "Ağır ishal-kusma (rotavirüs) — ağızdan damla",
      optional: true),
  Vaccine("rota2", "Rotavirüs (Rota)", "2. doz", 4,
      "Ağır ishal-kusma (rotavirüs) — ağızdan damla",
      optional: true),
  Vaccine("rota3", "Rotavirüs (Rota)", "3. doz (markaya göre)", 6,
      "Ağır ishal-kusma (rotavirüs). Marka 2 veya 3 dozdur.",
      optional: true),
  Vaccine("menb1", "Meningokok B", "1. doz", 2,
      "Menenjit ve kan enfeksiyonu (meningokok B)",
      optional: true),
  Vaccine("menb2", "Meningokok B", "2. doz", 4,
      "Menenjit ve kan enfeksiyonu (meningokok B)",
      optional: true),
  Vaccine("menb3", "Meningokok B", "Rapel", 12,
      "Menenjit ve kan enfeksiyonu (meningokok B)",
      optional: true),
  Vaccine("menacwy", "Meningokok ACWY (Konjuge)", "Bilgi amaçlı", 12,
      "Menenjit (meningokok A, C, W, Y). Şema yaşa/markaya göre değişir.",
      optional: true),
  Vaccine("grip", "Grip (İnfluenza)", "Yıllık", 6,
      "Mevsimsel grip. 6. aydan itibaren her yıl önerilir.",
      optional: true),
];
