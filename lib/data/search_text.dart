/// Türkçe arama için metin normalleştirme.
///
/// SORUN: Dart'ın `toLowerCase()` metodu Türkçeye duyarlı değildir. Unicode
/// varsayılanına göre `"I".toLowerCase()` → `"i"` üretir (Türkçede `"ı"`
/// olmalıydı). Veritabanında gıda adı "Ispanak" olarak kayıtlı; kullanıcı
/// doğal biçimde "ıspanak" yazdığında:
///     "Ispanak".toLowerCase() == "ispanak"
///     "ıspanak"               != "ispanak"   → sonuç bulunamıyordu.
/// Kullanıcı ancak "Ispanak" yazarsa buluyordu ki bu beklenemez.
///
/// ÇÖZÜM: Aramada her iki taraf da ASCII'ye katlanır — büyük/küçük harf ve
/// Türkçe aksanlar tamamen yok sayılır. Böylece "ıspanak", "Ispanak",
/// "ISPANAK", "ispanak" hepsi eşleşir; ayrıca "cilek" → "Çilek",
/// "yogurt" → "Yoğurt" gibi aksansız yazımlar da bulunur.
///
/// NOT: Yalnızca ARAMA için. Malzeme→gıda eşleştirmesi gibi veri çözümleme
/// yerlerinde bilerek kullanılmıyor; oradaki eşleşmenin kesin olması gerekir.
const Map<String, String> _fold = {
  'ı': 'i', 'İ': 'i', 'I': 'i', 'i': 'i',
  'ş': 's', 'Ş': 's',
  'ğ': 'g', 'Ğ': 'g',
  'ü': 'u', 'Ü': 'u',
  'ö': 'o', 'Ö': 'o',
  'ç': 'c', 'Ç': 'c',
  'â': 'a', 'Â': 'a',
  'î': 'i', 'Î': 'i',
  'û': 'u', 'Û': 'u',
};

/// Aramada kullanılacak normalleştirilmiş biçim.
String searchKey(String s) {
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    b.write(_fold[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// [haystack] içinde [needle] geçiyor mu? İkisi de normalleştirilir.
bool searchMatches(String haystack, String needle) =>
    needle.isEmpty || searchKey(haystack).contains(searchKey(needle));
