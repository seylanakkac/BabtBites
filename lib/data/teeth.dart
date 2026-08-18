// Süt dişleri (20 diş) ve tipik çıkış yaşları (ay). Her bebek farklıdır;
// aralıklar geneldir. Diş haritası için `arch` (üst/alt) + `order` (0–9,
// soldan sağa) kullanılır.
//
// ⚠️ Genel bilgilendirme amaçlıdır; gecikme/erken çıkış endişelerinde diş
// hekimine/çocuk doktoruna danışılmalıdır.

class Tooth {
  final String id;
  final String name; // "Üst orta kesici (sol)"
  final String arch; // "upper" | "lower"
  final int order; // 0..9 soldan sağa (izleyene göre)
  final String type; // ci | li | canine | m1 | m2 (renk/gruplama)
  final int minMonth;
  final int maxMonth;
  const Tooth(this.id, this.name, this.arch, this.order, this.type,
      this.minMonth, this.maxMonth);
}

// Konum tipleri (0..9): [2M, 1M, köpek, yan kesici, orta kesici,
//                        orta kesici, yan kesici, köpek, 1M, 2M]
const List<Tooth> kTeeth = [
  // ----- Üst çene -----
  Tooth("u0", "Üst ikinci azı (sol)", "upper", 0, "m2", 25, 33),
  Tooth("u1", "Üst birinci azı (sol)", "upper", 1, "m1", 13, 19),
  Tooth("u2", "Üst köpek dişi (sol)", "upper", 2, "canine", 16, 22),
  Tooth("u3", "Üst yan kesici (sol)", "upper", 3, "li", 9, 13),
  Tooth("u4", "Üst orta kesici (sol)", "upper", 4, "ci", 8, 12),
  Tooth("u5", "Üst orta kesici (sağ)", "upper", 5, "ci", 8, 12),
  Tooth("u6", "Üst yan kesici (sağ)", "upper", 6, "li", 9, 13),
  Tooth("u7", "Üst köpek dişi (sağ)", "upper", 7, "canine", 16, 22),
  Tooth("u8", "Üst birinci azı (sağ)", "upper", 8, "m1", 13, 19),
  Tooth("u9", "Üst ikinci azı (sağ)", "upper", 9, "m2", 25, 33),
  // ----- Alt çene -----
  Tooth("l0", "Alt ikinci azı (sol)", "lower", 0, "m2", 23, 31),
  Tooth("l1", "Alt birinci azı (sol)", "lower", 1, "m1", 14, 18),
  Tooth("l2", "Alt köpek dişi (sol)", "lower", 2, "canine", 17, 23),
  Tooth("l3", "Alt yan kesici (sol)", "lower", 3, "li", 10, 16),
  Tooth("l4", "Alt orta kesici (sol)", "lower", 4, "ci", 6, 10),
  Tooth("l5", "Alt orta kesici (sağ)", "lower", 5, "ci", 6, 10),
  Tooth("l6", "Alt yan kesici (sağ)", "lower", 6, "li", 10, 16),
  Tooth("l7", "Alt köpek dişi (sağ)", "lower", 7, "canine", 17, 23),
  Tooth("l8", "Alt birinci azı (sağ)", "lower", 8, "m1", 14, 18),
  Tooth("l9", "Alt ikinci azı (sağ)", "lower", 9, "m2", 23, 31),
];
