// Seasonal produce in Turkey (vegetables, fruits, fish, herbs), with the baby
// age (in months) from which each can typically be introduced. Ages are
// general ek-gıda guidance — citrus / acidic / high-allergen items and fish
// start later. Always introduce one new food at a time.

class SeasonalItem {
  final String name;
  final String emoji;
  final int startMonth; // baby age (months) from which it can be given
  const SeasonalItem(this.name, this.emoji, this.startMonth);
}

const List<String> kSeasons = ["Kış", "İlkbahar", "Yaz", "Sonbahar"];

/// season -> category ("Sebze" | "Meyve" | "Balık" | "Otlar") -> items.
const Map<String, Map<String, List<SeasonalItem>>> kSeasonalFoods = {
  "Kış": {
    "Sebze": [
      SeasonalItem("Brokoli", "🥦", 6),
      SeasonalItem("Karnabahar", "🥬", 6),
      SeasonalItem("Ispanak", "🥬", 6),
      SeasonalItem("Havuç", "🥕", 6),
      SeasonalItem("Balkabağı", "🎃", 6),
      SeasonalItem("Pırasa", "🧅", 8),
      SeasonalItem("Lahana", "🥬", 8),
      SeasonalItem("Kereviz", "🌿", 9),
    ],
    "Meyve": [
      SeasonalItem("Elma", "🍎", 6),
      SeasonalItem("Armut", "🍐", 6),
      SeasonalItem("Muz", "🍌", 6),
      SeasonalItem("Mandalina", "🍊", 9),
      SeasonalItem("Portakal", "🍊", 9),
      SeasonalItem("Kivi", "🥝", 8),
      SeasonalItem("Greyfurt", "🍊", 10),
    ],
    "Balık": [
      SeasonalItem("Mezgit", "🐟", 8),
      SeasonalItem("Hamsi", "🐟", 9),
      SeasonalItem("İstavrit", "🐟", 9),
      SeasonalItem("Levrek", "🐟", 9),
      SeasonalItem("Çupra", "🐟", 9),
      SeasonalItem("Lüfer", "🐟", 9),
    ],
    "Otlar": [
      SeasonalItem("Maydanoz", "🌿", 6),
      SeasonalItem("Dereotu", "🌿", 6),
      SeasonalItem("Roka", "🥬", 8),
    ],
  },
  "İlkbahar": {
    "Sebze": [
      SeasonalItem("Kabak", "🥒", 6),
      SeasonalItem("Bezelye", "🫛", 6),
      SeasonalItem("Ispanak", "🥬", 6),
      SeasonalItem("Marul", "🥬", 8),
      SeasonalItem("Taze Soğan", "🧅", 9),
      SeasonalItem("Bakla", "🫛", 9),
      SeasonalItem("Turp", "🥬", 9),
      SeasonalItem("Enginar", "🥬", 12),
    ],
    "Meyve": [
      SeasonalItem("Kayısı", "🍑", 6),
      SeasonalItem("Muz", "🍌", 6),
      SeasonalItem("Çilek", "🍓", 8),
      SeasonalItem("Yeşil Erik", "🍏", 9),
      SeasonalItem("Dut", "🫐", 9),
    ],
    "Balık": [
      SeasonalItem("Mezgit", "🐟", 8),
      SeasonalItem("Sardalya", "🐟", 9),
      SeasonalItem("İstavrit", "🐟", 9),
      SeasonalItem("Tekir", "🐟", 9),
    ],
    "Otlar": [
      SeasonalItem("Maydanoz", "🌿", 6),
      SeasonalItem("Dereotu", "🌿", 6),
      SeasonalItem("Semizotu", "🥬", 8),
      SeasonalItem("Taze Nane", "🌿", 8),
      SeasonalItem("Roka", "🥬", 8),
    ],
  },
  "Yaz": {
    "Sebze": [
      SeasonalItem("Kabak", "🥒", 6),
      SeasonalItem("Domates", "🍅", 8),
      SeasonalItem("Salatalık", "🥒", 8),
      SeasonalItem("Patlıcan", "🍆", 8),
      SeasonalItem("Taze Fasulye", "🫛", 8),
      SeasonalItem("Bamya", "🥬", 8),
      SeasonalItem("Biber", "🫑", 9),
      SeasonalItem("Mısır", "🌽", 12),
    ],
    "Meyve": [
      SeasonalItem("Şeftali", "🍑", 6),
      SeasonalItem("Kayısı", "🍑", 6),
      SeasonalItem("Muz", "🍌", 6),
      SeasonalItem("Karpuz", "🍉", 8),
      SeasonalItem("Kavun", "🍈", 8),
      SeasonalItem("Kiraz", "🍒", 8),
      SeasonalItem("Erik", "🍇", 8),
      SeasonalItem("İncir", "🫐", 9),
      SeasonalItem("Üzüm", "🍇", 9),
    ],
    "Balık": [
      SeasonalItem("Sardalya", "🐟", 9),
      SeasonalItem("Barbun", "🐟", 9),
      SeasonalItem("İstavrit", "🐟", 9),
    ],
    "Otlar": [
      SeasonalItem("Maydanoz", "🌿", 6),
      SeasonalItem("Fesleğen", "🌿", 8),
      SeasonalItem("Nane", "🌿", 8),
      SeasonalItem("Semizotu", "🥬", 8),
    ],
  },
  "Sonbahar": {
    "Sebze": [
      SeasonalItem("Balkabağı", "🎃", 6),
      SeasonalItem("Havuç", "🥕", 6),
      SeasonalItem("Patates", "🥔", 6),
      SeasonalItem("Karnabahar", "🥬", 6),
      SeasonalItem("Brokoli", "🥦", 6),
      SeasonalItem("Ispanak", "🥬", 6),
      SeasonalItem("Pırasa", "🧅", 8),
      SeasonalItem("Pancar", "🥬", 8),
    ],
    "Meyve": [
      SeasonalItem("Elma", "🍎", 6),
      SeasonalItem("Armut", "🍐", 6),
      SeasonalItem("Ayva", "🍐", 9),
      SeasonalItem("Üzüm", "🍇", 9),
      SeasonalItem("İncir", "🫐", 9),
      SeasonalItem("Nar", "🍎", 9),
      SeasonalItem("Trabzon Hurması", "🍊", 9),
      SeasonalItem("Mandalina", "🍊", 9),
    ],
    "Balık": [
      SeasonalItem("Palamut", "🐟", 9),
      SeasonalItem("Lüfer", "🐟", 9),
      SeasonalItem("Hamsi", "🐟", 9),
      SeasonalItem("İstavrit", "🐟", 9),
      SeasonalItem("Çinekop", "🐟", 9),
      SeasonalItem("Levrek", "🐟", 9),
    ],
    "Otlar": [
      SeasonalItem("Maydanoz", "🌿", 6),
      SeasonalItem("Dereotu", "🌿", 6),
      SeasonalItem("Roka", "🥬", 8),
    ],
  },
};

/// The Turkish season name for a calendar month (1-12).
String seasonForMonth(int month) {
  if (month == 12 || month == 1 || month == 2) return "Kış";
  if (month >= 3 && month <= 5) return "İlkbahar";
  if (month >= 6 && month <= 8) return "Yaz";
  return "Sonbahar";
}
