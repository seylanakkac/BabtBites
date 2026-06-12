// Detailed per-100g nutrition for the built-in foods.
//
// Values are USDA / standard reference figures per 100 g of the edible part
// (raw unless the food is normally eaten cooked, e.g. rice/quinoa). They are
// approximations suitable for a guidance app, not clinical figures.
//
// Keys (units): Enerji(kcal), Karbonhidrat(g), Protein(g), Yağ(g), Lif(g),
// Kolesterol(mg), Sodyum(mg), Potasyum(mg), Kalsiyum(mg), Vitamin A(IU),
// Vitamin C(mg), Demir(mg). Keyed by lower-case Turkish food name.

/// Canonical nutrient order + display unit, used to build the detail table.
const List<List<String>> kNutrientDisplay = [
  ["Enerji", "kcal"],
  ["Karbonhidrat", "g"],
  ["Protein", "g"],
  ["Yağ", "g"],
  ["Lif", "g"],
  ["Kolesterol", "mg"],
  ["Sodyum", "mg"],
  ["Potasyum", "mg"],
  ["Kalsiyum", "mg"],
  ["Vitamin A", "IU"],
  ["Vitamin C", "mg"],
  ["Demir", "mg"],
];

/// Just the nutrient keys, in display order.
const List<String> kNutrientKeys = [
  "Enerji", "Karbonhidrat", "Protein", "Yağ", "Lif", "Kolesterol",
  "Sodyum", "Potasyum", "Kalsiyum", "Vitamin A", "Vitamin C", "Demir",
];

const Map<String, Map<String, double>> kDetailedNutrition = {
  // --- SEBZELER ---
  "brokoli": {"Enerji": 34, "Karbonhidrat": 6.6, "Protein": 2.8, "Yağ": 0.4, "Lif": 2.6, "Kolesterol": 0, "Sodyum": 33, "Potasyum": 316, "Kalsiyum": 47, "Vitamin A": 623, "Vitamin C": 89.2, "Demir": 0.73},
  "havuç": {"Enerji": 41, "Karbonhidrat": 9.6, "Protein": 0.9, "Yağ": 0.24, "Lif": 2.8, "Kolesterol": 0, "Sodyum": 69, "Potasyum": 320, "Kalsiyum": 33, "Vitamin A": 16706, "Vitamin C": 5.9, "Demir": 0.3},
  "kabak": {"Enerji": 17, "Karbonhidrat": 3.1, "Protein": 1.2, "Yağ": 0.3, "Lif": 1.0, "Kolesterol": 0, "Sodyum": 8, "Potasyum": 261, "Kalsiyum": 16, "Vitamin A": 200, "Vitamin C": 17.9, "Demir": 0.37},
  "patates": {"Enerji": 77, "Karbonhidrat": 17.5, "Protein": 2.0, "Yağ": 0.1, "Lif": 2.2, "Kolesterol": 0, "Sodyum": 6, "Potasyum": 425, "Kalsiyum": 12, "Vitamin A": 2, "Vitamin C": 19.7, "Demir": 0.81},
  "balkabağı": {"Enerji": 26, "Karbonhidrat": 6.5, "Protein": 1.0, "Yağ": 0.1, "Lif": 0.5, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 340, "Kalsiyum": 21, "Vitamin A": 8513, "Vitamin C": 9.0, "Demir": 0.8},
  "bezelye": {"Enerji": 81, "Karbonhidrat": 14.5, "Protein": 5.4, "Yağ": 0.4, "Lif": 5.7, "Kolesterol": 0, "Sodyum": 5, "Potasyum": 244, "Kalsiyum": 25, "Vitamin A": 765, "Vitamin C": 40, "Demir": 1.47},
  "ıspanak": {"Enerji": 23, "Karbonhidrat": 3.6, "Protein": 2.9, "Yağ": 0.4, "Lif": 2.2, "Kolesterol": 0, "Sodyum": 79, "Potasyum": 558, "Kalsiyum": 99, "Vitamin A": 9377, "Vitamin C": 28.1, "Demir": 2.71},
  "ispanak": {"Enerji": 23, "Karbonhidrat": 3.6, "Protein": 2.9, "Yağ": 0.4, "Lif": 2.2, "Kolesterol": 0, "Sodyum": 79, "Potasyum": 558, "Kalsiyum": 99, "Vitamin A": 9377, "Vitamin C": 28.1, "Demir": 2.71},
  "karnabahar": {"Enerji": 25, "Karbonhidrat": 5.0, "Protein": 1.9, "Yağ": 0.3, "Lif": 2.0, "Kolesterol": 0, "Sodyum": 30, "Potasyum": 299, "Kalsiyum": 22, "Vitamin A": 0, "Vitamin C": 48.2, "Demir": 0.42},
  "tatlı patates": {"Enerji": 86, "Karbonhidrat": 20.1, "Protein": 1.6, "Yağ": 0.1, "Lif": 3.0, "Kolesterol": 0, "Sodyum": 55, "Potasyum": 337, "Kalsiyum": 30, "Vitamin A": 14187, "Vitamin C": 2.4, "Demir": 0.61},

  // --- MEYVELER ---
  "muz": {"Enerji": 89, "Karbonhidrat": 22.8, "Protein": 1.1, "Yağ": 0.3, "Lif": 2.6, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 358, "Kalsiyum": 5, "Vitamin A": 64, "Vitamin C": 8.7, "Demir": 0.26},
  "avokado": {"Enerji": 160, "Karbonhidrat": 8.5, "Protein": 2.0, "Yağ": 14.7, "Lif": 6.7, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 485, "Kalsiyum": 12, "Vitamin A": 146, "Vitamin C": 10, "Demir": 0.55},
  "elma": {"Enerji": 52, "Karbonhidrat": 13.8, "Protein": 0.3, "Yağ": 0.2, "Lif": 2.4, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 107, "Kalsiyum": 6, "Vitamin A": 54, "Vitamin C": 4.6, "Demir": 0.12},
  "armut": {"Enerji": 57, "Karbonhidrat": 15.2, "Protein": 0.4, "Yağ": 0.1, "Lif": 3.1, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 116, "Kalsiyum": 9, "Vitamin A": 25, "Vitamin C": 4.3, "Demir": 0.18},
  "şeftali": {"Enerji": 39, "Karbonhidrat": 9.5, "Protein": 0.9, "Yağ": 0.25, "Lif": 1.5, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 190, "Kalsiyum": 6, "Vitamin A": 326, "Vitamin C": 6.6, "Demir": 0.25},
  "kayısı": {"Enerji": 48, "Karbonhidrat": 11.1, "Protein": 1.4, "Yağ": 0.4, "Lif": 2.0, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 259, "Kalsiyum": 13, "Vitamin A": 1926, "Vitamin C": 10, "Demir": 0.39},

  // --- TAHILLAR ---
  "yulaf": {"Enerji": 389, "Karbonhidrat": 66.3, "Protein": 16.9, "Yağ": 6.9, "Lif": 10.6, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 429, "Kalsiyum": 54, "Vitamin A": 0, "Vitamin C": 0, "Demir": 4.72},
  "pirinç": {"Enerji": 130, "Karbonhidrat": 28.2, "Protein": 2.7, "Yağ": 0.3, "Lif": 0.4, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 35, "Kalsiyum": 10, "Vitamin A": 0, "Vitamin C": 0, "Demir": 1.2},
  "i̇rmik": {"Enerji": 360, "Karbonhidrat": 72.8, "Protein": 12.7, "Yağ": 1.05, "Lif": 3.9, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 186, "Kalsiyum": 17, "Vitamin A": 0, "Vitamin C": 0, "Demir": 1.23},
  "irmik": {"Enerji": 360, "Karbonhidrat": 72.8, "Protein": 12.7, "Yağ": 1.05, "Lif": 3.9, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 186, "Kalsiyum": 17, "Vitamin A": 0, "Vitamin C": 0, "Demir": 1.23},
  "kinoa": {"Enerji": 120, "Karbonhidrat": 21.3, "Protein": 4.4, "Yağ": 1.9, "Lif": 2.8, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 172, "Kalsiyum": 17, "Vitamin A": 5, "Vitamin C": 0, "Demir": 1.49},

  // --- PROTEİN / SÜT / YAĞ ---
  "yumurta sarısı": {"Enerji": 322, "Karbonhidrat": 3.6, "Protein": 15.9, "Yağ": 26.5, "Lif": 0, "Kolesterol": 1085, "Sodyum": 48, "Potasyum": 109, "Kalsiyum": 129, "Vitamin A": 1442, "Vitamin C": 0, "Demir": 2.73},
  "tavuk göğsü": {"Enerji": 165, "Karbonhidrat": 0, "Protein": 31, "Yağ": 3.6, "Lif": 0, "Kolesterol": 85, "Sodyum": 74, "Potasyum": 256, "Kalsiyum": 15, "Vitamin A": 21, "Vitamin C": 0, "Demir": 1.0},
  "dana kıyma": {"Enerji": 250, "Karbonhidrat": 0, "Protein": 26, "Yağ": 15, "Lif": 0, "Kolesterol": 78, "Sodyum": 72, "Potasyum": 318, "Kalsiyum": 24, "Vitamin A": 0, "Vitamin C": 0, "Demir": 2.7},
  "yoğurt": {"Enerji": 61, "Karbonhidrat": 4.7, "Protein": 3.5, "Yağ": 3.3, "Lif": 0, "Kolesterol": 13, "Sodyum": 46, "Potasyum": 155, "Kalsiyum": 121, "Vitamin A": 99, "Vitamin C": 0.5, "Demir": 0.05},
  "labne": {"Enerji": 150, "Karbonhidrat": 4.0, "Protein": 6.0, "Yağ": 12.0, "Lif": 0, "Kolesterol": 35, "Sodyum": 60, "Potasyum": 100, "Kalsiyum": 100, "Vitamin A": 300, "Vitamin C": 0, "Demir": 0.1},
  "somon": {"Enerji": 206, "Karbonhidrat": 0, "Protein": 22.1, "Yağ": 12.4, "Lif": 0, "Kolesterol": 63, "Sodyum": 61, "Potasyum": 384, "Kalsiyum": 9, "Vitamin A": 58, "Vitamin C": 3.9, "Demir": 0.34},
  "zeytinyağı": {"Enerji": 884, "Karbonhidrat": 0, "Protein": 0, "Yağ": 100, "Lif": 0, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 1, "Kalsiyum": 1, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.56},
};
