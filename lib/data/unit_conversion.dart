// Birim → gram dönüşümü (tarif malzeme miktarlarını gerçek grama çevirir).
//
// Tariflerde malzemeler "100 gr", "1 adet", "2 yemek kaşığı ince kıyılmış"
// gibi serbest metin olarak saklanıyor. Besin değeri hesabı için bunları
// grama çevirmemiz gerekiyor; aksi halde her malzeme 100 gr sayılır ve
// kalori/besin değerleri yanlış çıkar.
//
// Yaklaşım: miktar metnindeki sayıyı (kesir/aralık dahil) çöz, sonra metinde
// bilinen ilk birim anahtarını bul, hacimsel birimleri yaklaşık gram ağırlığa
// çevir. "adet/tane/dilim" gibi parça birimleri için besine özel ortalama
// ağırlık ([gramsPerPieceFor]) kullanılır.

/// Hacim/ölçek birimlerinin yaklaşık gram karşılığı (1 birim = ? gram).
/// Sıvı/püre yoğunluğu ~1 g/ml kabul edilir (bebek mutfağı için yeterli).
const Map<String, double> kUnitGrams = {
  "kg": 1000,
  "gram": 1,
  "gr": 1,
  "g": 1,
  "mg": 0.001,
  "litre": 1000,
  "lt": 1000,
  "l": 1000,
  "ml": 1,
  "su bardağı": 200,
  "çay bardağı": 110,
  "fincan": 80,
  "kase": 250,
  "yemek kaşığı": 15,
  "tatlı kaşığı": 8,
  "çay kaşığı": 5,
  "kaşık": 12,
  "demet": 80,
  "avuç": 30,
  "tutam": 1,
};

/// "Bütün" parça birimleri — 1 adet = besine özel ortalama ağırlık.
const Set<String> kWholePieceUnits = {"adet", "tane", "parça"};

/// Alt-porsiyon parça birimleri — sabit küçük gram ağırlıkları (besinden bağımsız).
const Map<String, double> kSubPieceGrams = {
  "dilim": 30, "halka": 12, "küp": 10, "çiçek": 12,
  "yaprak": 5, "dal": 3, "diş": 5,
};

/// Tüm parça (sayı) birimleri.
final Set<String> kPieceUnits = {...kWholePieceUnits, ...kSubPieceGrams.keys};

/// Bir "bütün" parça birim için varsayılan gram ağırlığı (besine özel veri yoksa).
const double kDefaultPieceGrams = 80;

/// "1", "1/2", "1,5", "0.5", "2-3" gibi miktar metnini sayıya çevirir.
/// Aralık (2-3) verilirse ortalaması alınır. Bulamazsa null.
double? parseQuantity(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  // Aralık: "2-3", "2 - 3"
  final range = RegExp(r'^([\d.,]+)\s*-\s*([\d.,]+)').firstMatch(s);
  if (range != null) {
    final a = double.tryParse(range.group(1)!.replaceAll(',', '.'));
    final b = double.tryParse(range.group(2)!.replaceAll(',', '.'));
    if (a != null && b != null) return (a + b) / 2;
  }
  // Kesir: "1/2", "3/4"
  final frac = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(s);
  if (frac != null) {
    final a = double.tryParse(frac.group(1)!);
    final b = double.tryParse(frac.group(2)!);
    if (a != null && b != null && b != 0) return a / b;
  }
  // Tam sayı + kesir: "1 1/2"
  final mixed = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)').firstMatch(s);
  if (mixed != null) {
    final w = double.tryParse(mixed.group(1)!);
    final a = double.tryParse(mixed.group(2)!);
    final b = double.tryParse(mixed.group(3)!);
    if (w != null && a != null && b != null && b != 0) return w + a / b;
  }
  // Düz sayı: "100", "0.5", "1,5"
  final num = RegExp(r'^([\d]+[.,]?[\d]*)').firstMatch(s);
  if (num != null) {
    return double.tryParse(num.group(1)!.replaceAll(',', '.'));
  }
  return null;
}

/// Miktar metnindeki ilk bilinen birimi döndürür ("100 gr ..." → "gr").
/// Önce çok kelimeli birimler ("yemek kaşığı") taranır.
String? detectUnit(String raw) {
  final s = raw.toLowerCase();
  // Çok kelimeli birimler önce (uzun anahtar öncelikli eşleşme).
  final keys = [...kUnitGrams.keys, ...kPieceUnits]
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    // Kelime sınırına yakın eşleşme (ör. "gr" / "gram" ayrımı için).
    if (RegExp('(^|[^a-zçğıöşü])${RegExp.escape(k)}([^a-zçğıöşü]|\$)').hasMatch(s)) {
      return k;
    }
  }
  return null;
}

/// Bir malzeme miktarını ([amount]) grama çevirir; [gramsPerPiece] parça
/// birimleri için besine özel ortalama ağırlıktır (0 ise varsayılan kullanılır).
/// Çözülemezse null döner (hesaba katılmaz, böylece tahmin uydurmuş olmayız).
double? amountToGrams(String amount, {double gramsPerPiece = 0}) {
  if (amount.trim().isEmpty) return null;
  final qty = parseQuantity(amount);
  final unit = detectUnit(amount);

  if (unit == null) {
    // Birim yok ama sayı var → adet varsayalım (ör. "1" = 1 adet).
    if (qty != null) {
      final g = gramsPerPiece > 0 ? gramsPerPiece : kDefaultPieceGrams;
      return qty * g;
    }
    return null;
  }
  final q = qty ?? 1; // "yemek kaşığı" gibi sayısız ifade = 1 birim

  // Alt-porsiyon birimleri (dilim/çiçek/yaprak…) sabit küçük ağırlık kullanır.
  final subGrams = kSubPieceGrams[unit];
  if (subGrams != null) return q * subGrams;
  // "Bütün" parça birimleri (adet/tane/parça) → besine özel ağırlık.
  if (kWholePieceUnits.contains(unit)) {
    final g = gramsPerPiece > 0 ? gramsPerPiece : kDefaultPieceGrams;
    return q * g;
  }
  final perUnit = kUnitGrams[unit];
  if (perUnit != null) return q * perUnit;
  return null;
}
