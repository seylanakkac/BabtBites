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
  "yumurta akı": {"Enerji": 52, "Karbonhidrat": 0.73, "Protein": 10.9, "Yağ": 0.17, "Lif": 0, "Kolesterol": 0, "Sodyum": 166, "Potasyum": 163, "Kalsiyum": 7, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.08},
  "haşlanmış yumurta": {"Enerji": 155, "Karbonhidrat": 1.1, "Protein": 12.6, "Yağ": 10.6, "Lif": 0, "Kolesterol": 373, "Sodyum": 124, "Potasyum": 126, "Kalsiyum": 50, "Vitamin A": 520, "Vitamin C": 0, "Demir": 1.19},
  "tam yumurta": {"Enerji": 143, "Karbonhidrat": 0.72, "Protein": 12.6, "Yağ": 9.5, "Lif": 0, "Kolesterol": 372, "Sodyum": 142, "Potasyum": 138, "Kalsiyum": 56, "Vitamin A": 540, "Vitamin C": 0, "Demir": 1.75},
  "tavuk göğsü": {"Enerji": 165, "Karbonhidrat": 0, "Protein": 31, "Yağ": 3.6, "Lif": 0, "Kolesterol": 85, "Sodyum": 74, "Potasyum": 256, "Kalsiyum": 15, "Vitamin A": 21, "Vitamin C": 0, "Demir": 1.0},
  "dana kıyma": {"Enerji": 250, "Karbonhidrat": 0, "Protein": 26, "Yağ": 15, "Lif": 0, "Kolesterol": 78, "Sodyum": 72, "Potasyum": 318, "Kalsiyum": 24, "Vitamin A": 0, "Vitamin C": 0, "Demir": 2.7},
  "yoğurt": {"Enerji": 61, "Karbonhidrat": 4.7, "Protein": 3.5, "Yağ": 3.3, "Lif": 0, "Kolesterol": 13, "Sodyum": 46, "Potasyum": 155, "Kalsiyum": 121, "Vitamin A": 99, "Vitamin C": 0.5, "Demir": 0.05},
  "labne": {"Enerji": 150, "Karbonhidrat": 4.0, "Protein": 6.0, "Yağ": 12.0, "Lif": 0, "Kolesterol": 35, "Sodyum": 60, "Potasyum": 100, "Kalsiyum": 100, "Vitamin A": 300, "Vitamin C": 0, "Demir": 0.1},
  "somon": {"Enerji": 206, "Karbonhidrat": 0, "Protein": 22.1, "Yağ": 12.4, "Lif": 0, "Kolesterol": 63, "Sodyum": 61, "Potasyum": 384, "Kalsiyum": 9, "Vitamin A": 58, "Vitamin C": 3.9, "Demir": 0.34},
  "zeytinyağı": {"Enerji": 884, "Karbonhidrat": 0, "Protein": 0, "Yağ": 100, "Lif": 0, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 1, "Kalsiyum": 1, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.56},

  // --- SEBZELER (ek) ---
  "kereviz": {"Enerji": 16, "Karbonhidrat": 3.0, "Protein": 0.7, "Yağ": 0.2, "Lif": 1.6, "Kolesterol": 0, "Sodyum": 80, "Potasyum": 260, "Kalsiyum": 40, "Vitamin A": 449, "Vitamin C": 3.1, "Demir": 0.2},
  "pırasa": {"Enerji": 61, "Karbonhidrat": 14.2, "Protein": 1.5, "Yağ": 0.3, "Lif": 1.8, "Kolesterol": 0, "Sodyum": 20, "Potasyum": 180, "Kalsiyum": 59, "Vitamin A": 1667, "Vitamin C": 12, "Demir": 2.1},
  "kırmızı biber": {"Enerji": 31, "Karbonhidrat": 6.0, "Protein": 1.0, "Yağ": 0.3, "Lif": 2.1, "Kolesterol": 0, "Sodyum": 4, "Potasyum": 211, "Kalsiyum": 7, "Vitamin A": 3131, "Vitamin C": 127.7, "Demir": 0.43},
  "soğan": {"Enerji": 40, "Karbonhidrat": 9.3, "Protein": 1.1, "Yağ": 0.1, "Lif": 1.7, "Kolesterol": 0, "Sodyum": 4, "Potasyum": 146, "Kalsiyum": 23, "Vitamin A": 2, "Vitamin C": 7.4, "Demir": 0.21},
  "taze fasulye": {"Enerji": 31, "Karbonhidrat": 7.0, "Protein": 1.8, "Yağ": 0.1, "Lif": 2.7, "Kolesterol": 0, "Sodyum": 6, "Potasyum": 211, "Kalsiyum": 37, "Vitamin A": 690, "Vitamin C": 12.2, "Demir": 1.03},
  "pazı": {"Enerji": 19, "Karbonhidrat": 3.7, "Protein": 1.8, "Yağ": 0.2, "Lif": 1.6, "Kolesterol": 0, "Sodyum": 213, "Potasyum": 379, "Kalsiyum": 51, "Vitamin A": 6116, "Vitamin C": 30, "Demir": 1.8},
  "sarımsak": {"Enerji": 149, "Karbonhidrat": 33.1, "Protein": 6.4, "Yağ": 0.5, "Lif": 2.1, "Kolesterol": 0, "Sodyum": 17, "Potasyum": 401, "Kalsiyum": 181, "Vitamin A": 9, "Vitamin C": 31.2, "Demir": 1.7},
  "maydanoz": {"Enerji": 36, "Karbonhidrat": 6.3, "Protein": 3.0, "Yağ": 0.8, "Lif": 3.3, "Kolesterol": 0, "Sodyum": 56, "Potasyum": 554, "Kalsiyum": 138, "Vitamin A": 8424, "Vitamin C": 133, "Demir": 6.2},
  "dereotu": {"Enerji": 43, "Karbonhidrat": 7.0, "Protein": 3.5, "Yağ": 1.1, "Lif": 2.1, "Kolesterol": 0, "Sodyum": 61, "Potasyum": 738, "Kalsiyum": 208, "Vitamin A": 7718, "Vitamin C": 85, "Demir": 6.6},
  "kuşkonmaz": {"Enerji": 20, "Karbonhidrat": 3.9, "Protein": 2.2, "Yağ": 0.1, "Lif": 2.1, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 202, "Kalsiyum": 24, "Vitamin A": 756, "Vitamin C": 5.6, "Demir": 2.14},
  "bamya": {"Enerji": 33, "Karbonhidrat": 7.5, "Protein": 1.9, "Yağ": 0.2, "Lif": 3.2, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 299, "Kalsiyum": 82, "Vitamin A": 716, "Vitamin C": 23, "Demir": 0.62},
  "pancar": {"Enerji": 43, "Karbonhidrat": 9.6, "Protein": 1.6, "Yağ": 0.2, "Lif": 2.8, "Kolesterol": 0, "Sodyum": 78, "Potasyum": 325, "Kalsiyum": 16, "Vitamin A": 33, "Vitamin C": 4.9, "Demir": 0.8},
  "enginar": {"Enerji": 47, "Karbonhidrat": 10.5, "Protein": 3.3, "Yağ": 0.2, "Lif": 5.4, "Kolesterol": 0, "Sodyum": 94, "Potasyum": 370, "Kalsiyum": 44, "Vitamin A": 13, "Vitamin C": 11.7, "Demir": 1.28},
  "yer elması": {"Enerji": 73, "Karbonhidrat": 17.4, "Protein": 2.0, "Yağ": 0.0, "Lif": 1.6, "Kolesterol": 0, "Sodyum": 4, "Potasyum": 429, "Kalsiyum": 14, "Vitamin A": 20, "Vitamin C": 4.0, "Demir": 3.4},

  // --- MEYVELER (ek) ---
  "erik": {"Enerji": 46, "Karbonhidrat": 11.4, "Protein": 0.7, "Yağ": 0.3, "Lif": 1.4, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 157, "Kalsiyum": 6, "Vitamin A": 345, "Vitamin C": 9.5, "Demir": 0.17},
  "kavun": {"Enerji": 34, "Karbonhidrat": 8.2, "Protein": 0.8, "Yağ": 0.2, "Lif": 0.9, "Kolesterol": 0, "Sodyum": 16, "Potasyum": 267, "Kalsiyum": 9, "Vitamin A": 3382, "Vitamin C": 36.7, "Demir": 0.21},
  "karpuz": {"Enerji": 30, "Karbonhidrat": 7.6, "Protein": 0.6, "Yağ": 0.2, "Lif": 0.4, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 112, "Kalsiyum": 7, "Vitamin A": 569, "Vitamin C": 8.1, "Demir": 0.24},
  "böğürtlen": {"Enerji": 43, "Karbonhidrat": 9.6, "Protein": 1.4, "Yağ": 0.5, "Lif": 5.3, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 162, "Kalsiyum": 29, "Vitamin A": 214, "Vitamin C": 21, "Demir": 0.62},
  "yaban mersini": {"Enerji": 57, "Karbonhidrat": 14.5, "Protein": 0.7, "Yağ": 0.3, "Lif": 2.4, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 77, "Kalsiyum": 6, "Vitamin A": 54, "Vitamin C": 9.7, "Demir": 0.28},
  "mango": {"Enerji": 60, "Karbonhidrat": 15.0, "Protein": 0.8, "Yağ": 0.4, "Lif": 1.6, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 168, "Kalsiyum": 11, "Vitamin A": 1082, "Vitamin C": 36.4, "Demir": 0.16},
  "ananas": {"Enerji": 50, "Karbonhidrat": 13.1, "Protein": 0.5, "Yağ": 0.1, "Lif": 1.4, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 109, "Kalsiyum": 13, "Vitamin A": 58, "Vitamin C": 47.8, "Demir": 0.29},
  "incir": {"Enerji": 74, "Karbonhidrat": 19.2, "Protein": 0.8, "Yağ": 0.3, "Lif": 2.9, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 232, "Kalsiyum": 35, "Vitamin A": 142, "Vitamin C": 2.0, "Demir": 0.37},
  "hurma": {"Enerji": 282, "Karbonhidrat": 75.0, "Protein": 2.5, "Yağ": 0.4, "Lif": 8.0, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 656, "Kalsiyum": 39, "Vitamin A": 10, "Vitamin C": 0.4, "Demir": 1.0},
  "mandalina": {"Enerji": 53, "Karbonhidrat": 13.3, "Protein": 0.8, "Yağ": 0.3, "Lif": 1.8, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 166, "Kalsiyum": 37, "Vitamin A": 681, "Vitamin C": 26.7, "Demir": 0.15},
  "portakal": {"Enerji": 47, "Karbonhidrat": 11.8, "Protein": 0.9, "Yağ": 0.1, "Lif": 2.4, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 181, "Kalsiyum": 40, "Vitamin A": 225, "Vitamin C": 53.2, "Demir": 0.1},
  "limon": {"Enerji": 29, "Karbonhidrat": 9.3, "Protein": 1.1, "Yağ": 0.3, "Lif": 2.8, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 138, "Kalsiyum": 26, "Vitamin A": 22, "Vitamin C": 53, "Demir": 0.6},
  "çilek": {"Enerji": 32, "Karbonhidrat": 7.7, "Protein": 0.7, "Yağ": 0.3, "Lif": 2.0, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 153, "Kalsiyum": 16, "Vitamin A": 12, "Vitamin C": 58.8, "Demir": 0.41},
  "kivi": {"Enerji": 61, "Karbonhidrat": 14.7, "Protein": 1.1, "Yağ": 0.5, "Lif": 3.0, "Kolesterol": 0, "Sodyum": 3, "Potasyum": 312, "Kalsiyum": 34, "Vitamin A": 87, "Vitamin C": 92.7, "Demir": 0.31},
  "nar": {"Enerji": 83, "Karbonhidrat": 18.7, "Protein": 1.7, "Yağ": 1.2, "Lif": 4.0, "Kolesterol": 0, "Sodyum": 3, "Potasyum": 236, "Kalsiyum": 10, "Vitamin A": 0, "Vitamin C": 10.2, "Demir": 0.3},
  "vişne": {"Enerji": 50, "Karbonhidrat": 12.2, "Protein": 1.0, "Yağ": 0.3, "Lif": 1.6, "Kolesterol": 0, "Sodyum": 3, "Potasyum": 173, "Kalsiyum": 16, "Vitamin A": 1283, "Vitamin C": 10, "Demir": 0.32},
  "kiraz": {"Enerji": 63, "Karbonhidrat": 16.0, "Protein": 1.1, "Yağ": 0.2, "Lif": 2.1, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 222, "Kalsiyum": 13, "Vitamin A": 64, "Vitamin C": 7, "Demir": 0.36},
  "üzüm": {"Enerji": 69, "Karbonhidrat": 18.1, "Protein": 0.7, "Yağ": 0.2, "Lif": 0.9, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 191, "Kalsiyum": 10, "Vitamin A": 66, "Vitamin C": 3.2, "Demir": 0.36},

  // --- PROTEİN / SÜT / YAĞ (ek) ---
  "lor peyniri": {"Enerji": 98, "Karbonhidrat": 3.4, "Protein": 11.1, "Yağ": 4.3, "Lif": 0, "Kolesterol": 17, "Sodyum": 364, "Potasyum": 104, "Kalsiyum": 83, "Vitamin A": 140, "Vitamin C": 0, "Demir": 0.07},
  "hindi göğsü": {"Enerji": 111, "Karbonhidrat": 0, "Protein": 23.0, "Yağ": 1.5, "Lif": 0, "Kolesterol": 60, "Sodyum": 52, "Potasyum": 249, "Kalsiyum": 12, "Vitamin A": 0, "Vitamin C": 0, "Demir": 1.0},
  "kuzu eti": {"Enerji": 201, "Karbonhidrat": 0, "Protein": 20.0, "Yağ": 13.0, "Lif": 0, "Kolesterol": 73, "Sodyum": 65, "Potasyum": 280, "Kalsiyum": 9, "Vitamin A": 0, "Vitamin C": 0, "Demir": 1.8},
  "tereyağı": {"Enerji": 717, "Karbonhidrat": 0.1, "Protein": 0.9, "Yağ": 81.1, "Lif": 0, "Kolesterol": 215, "Sodyum": 11, "Potasyum": 24, "Kalsiyum": 24, "Vitamin A": 2499, "Vitamin C": 0, "Demir": 0.02},
  "süzme peynir": {"Enerji": 220, "Karbonhidrat": 4.0, "Protein": 12.0, "Yağ": 18.0, "Lif": 0, "Kolesterol": 50, "Sodyum": 800, "Potasyum": 90, "Kalsiyum": 300, "Vitamin A": 400, "Vitamin C": 0, "Demir": 0.5},

  // --- BALIK (ek) ---
  "mezgit": {"Enerji": 90, "Karbonhidrat": 0, "Protein": 18.3, "Yağ": 1.3, "Lif": 0, "Kolesterol": 67, "Sodyum": 72, "Potasyum": 405, "Kalsiyum": 18, "Vitamin A": 30, "Vitamin C": 0, "Demir": 0.4},
  "levrek": {"Enerji": 97, "Karbonhidrat": 0, "Protein": 18.4, "Yağ": 2.0, "Lif": 0, "Kolesterol": 41, "Sodyum": 68, "Potasyum": 256, "Kalsiyum": 10, "Vitamin A": 256, "Vitamin C": 0, "Demir": 0.3},
  "çipura": {"Enerji": 96, "Karbonhidrat": 0, "Protein": 19.0, "Yağ": 1.9, "Lif": 0, "Kolesterol": 50, "Sodyum": 70, "Potasyum": 300, "Kalsiyum": 20, "Vitamin A": 30, "Vitamin C": 0, "Demir": 0.4},
  "alabalık": {"Enerji": 148, "Karbonhidrat": 0, "Protein": 20.8, "Yağ": 6.6, "Lif": 0, "Kolesterol": 59, "Sodyum": 51, "Potasyum": 361, "Kalsiyum": 43, "Vitamin A": 60, "Vitamin C": 2.4, "Demir": 1.5},

  // --- TAHIL / BAKLAGİL (ek) ---
  "kırmızı mercimek": {"Enerji": 358, "Karbonhidrat": 63.0, "Protein": 24.6, "Yağ": 1.1, "Lif": 10.8, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 668, "Kalsiyum": 51, "Vitamin A": 39, "Vitamin C": 1.5, "Demir": 7.4},
  "nohut": {"Enerji": 364, "Karbonhidrat": 60.7, "Protein": 19.3, "Yağ": 6.0, "Lif": 17.4, "Kolesterol": 0, "Sodyum": 24, "Potasyum": 718, "Kalsiyum": 105, "Vitamin A": 67, "Vitamin C": 4.0, "Demir": 6.2},
  "bulgur": {"Enerji": 342, "Karbonhidrat": 75.9, "Protein": 12.3, "Yağ": 1.3, "Lif": 18.3, "Kolesterol": 0, "Sodyum": 17, "Potasyum": 410, "Kalsiyum": 35, "Vitamin A": 9, "Vitamin C": 0, "Demir": 2.5},
  "mısır unu": {"Enerji": 361, "Karbonhidrat": 76.9, "Protein": 6.9, "Yağ": 3.9, "Lif": 7.3, "Kolesterol": 0, "Sodyum": 5, "Potasyum": 142, "Kalsiyum": 7, "Vitamin A": 214, "Vitamin C": 0, "Demir": 2.4},
  "tam buğday unu": {"Enerji": 340, "Karbonhidrat": 72.0, "Protein": 13.2, "Yağ": 2.5, "Lif": 10.7, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 405, "Kalsiyum": 34, "Vitamin A": 9, "Vitamin C": 0, "Demir": 3.6},

  // --- DİĞER / KURUYEMİŞ & YAĞ (ek) ---
  "ceviz": {"Enerji": 654, "Karbonhidrat": 13.7, "Protein": 15.2, "Yağ": 65.2, "Lif": 6.7, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 441, "Kalsiyum": 98, "Vitamin A": 20, "Vitamin C": 1.3, "Demir": 2.9},
  "badem": {"Enerji": 579, "Karbonhidrat": 21.6, "Protein": 21.2, "Yağ": 49.9, "Lif": 12.5, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 733, "Kalsiyum": 269, "Vitamin A": 2, "Vitamin C": 0, "Demir": 3.7},
  "fındık": {"Enerji": 628, "Karbonhidrat": 16.7, "Protein": 15.0, "Yağ": 60.8, "Lif": 9.7, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 680, "Kalsiyum": 114, "Vitamin A": 20, "Vitamin C": 6.3, "Demir": 4.7},
  "tahin": {"Enerji": 595, "Karbonhidrat": 21.2, "Protein": 17.0, "Yağ": 53.8, "Lif": 9.3, "Kolesterol": 0, "Sodyum": 35, "Potasyum": 414, "Kalsiyum": 426, "Vitamin A": 67, "Vitamin C": 0, "Demir": 8.95},
  "pekmez": {"Enerji": 290, "Karbonhidrat": 70.0, "Protein": 0.0, "Yağ": 0.0, "Lif": 0, "Kolesterol": 0, "Sodyum": 38, "Potasyum": 730, "Kalsiyum": 150, "Vitamin A": 0, "Vitamin C": 0, "Demir": 4.7},
  "chia tohumu": {"Enerji": 486, "Karbonhidrat": 42.1, "Protein": 16.5, "Yağ": 30.7, "Lif": 34.4, "Kolesterol": 0, "Sodyum": 16, "Potasyum": 407, "Kalsiyum": 631, "Vitamin A": 54, "Vitamin C": 1.6, "Demir": 7.7},

  // --- SEBZE (ek 2) ---
  "bezelye filizi": {"Enerji": 42, "Karbonhidrat": 6.0, "Protein": 4.0, "Yağ": 0.5, "Lif": 2.5, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 200, "Kalsiyum": 40, "Vitamin A": 1000, "Vitamin C": 50, "Demir": 1.5},

  // --- MEYVE / KURU MEYVE (ek 2) ---
  "kurutulmuş üzüm": {"Enerji": 299, "Karbonhidrat": 79.2, "Protein": 3.1, "Yağ": 0.5, "Lif": 3.7, "Kolesterol": 0, "Sodyum": 11, "Potasyum": 749, "Kalsiyum": 50, "Vitamin A": 0, "Vitamin C": 2.3, "Demir": 1.88},
  "kuru kayısı": {"Enerji": 241, "Karbonhidrat": 62.6, "Protein": 3.4, "Yağ": 0.5, "Lif": 7.3, "Kolesterol": 0, "Sodyum": 10, "Potasyum": 1162, "Kalsiyum": 55, "Vitamin A": 3604, "Vitamin C": 1.0, "Demir": 2.66},
  "kuru incir": {"Enerji": 249, "Karbonhidrat": 63.9, "Protein": 3.3, "Yağ": 0.9, "Lif": 9.8, "Kolesterol": 0, "Sodyum": 10, "Potasyum": 680, "Kalsiyum": 162, "Vitamin A": 10, "Vitamin C": 1.2, "Demir": 2.03},
  "kuru erik": {"Enerji": 240, "Karbonhidrat": 63.9, "Protein": 2.2, "Yağ": 0.4, "Lif": 7.1, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 732, "Kalsiyum": 43, "Vitamin A": 781, "Vitamin C": 0.6, "Demir": 0.93},
  "kuru dut": {"Enerji": 350, "Karbonhidrat": 78.0, "Protein": 9.0, "Yağ": 2.0, "Lif": 13.0, "Kolesterol": 0, "Sodyum": 21, "Potasyum": 800, "Kalsiyum": 250, "Vitamin A": 30, "Vitamin C": 5.0, "Demir": 4.0},

  // --- TAHIL / BAKLAGİL (ek 2) ---
  "yeşil mercimek": {"Enerji": 352, "Karbonhidrat": 63.4, "Protein": 24.6, "Yağ": 1.1, "Lif": 10.7, "Kolesterol": 0, "Sodyum": 6, "Potasyum": 677, "Kalsiyum": 35, "Vitamin A": 39, "Vitamin C": 4.4, "Demir": 6.5},
  "ruşeym": {"Enerji": 360, "Karbonhidrat": 51.8, "Protein": 23.2, "Yağ": 9.7, "Lif": 13.2, "Kolesterol": 0, "Sodyum": 12, "Potasyum": 892, "Kalsiyum": 39, "Vitamin A": 0, "Vitamin C": 0, "Demir": 6.3},
  "karabuğday": {"Enerji": 343, "Karbonhidrat": 71.5, "Protein": 13.3, "Yağ": 3.4, "Lif": 10.0, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 460, "Kalsiyum": 18, "Vitamin A": 0, "Vitamin C": 0, "Demir": 2.2},
  "arpa": {"Enerji": 354, "Karbonhidrat": 73.5, "Protein": 12.5, "Yağ": 2.3, "Lif": 17.3, "Kolesterol": 0, "Sodyum": 12, "Potasyum": 452, "Kalsiyum": 33, "Vitamin A": 22, "Vitamin C": 0, "Demir": 3.6},
  "ruşen pirinç": {"Enerji": 365, "Karbonhidrat": 80.0, "Protein": 7.1, "Yağ": 0.7, "Lif": 1.3, "Kolesterol": 0, "Sodyum": 5, "Potasyum": 115, "Kalsiyum": 28, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.8},
  "erişte": {"Enerji": 384, "Karbonhidrat": 71.3, "Protein": 14.2, "Yağ": 4.4, "Lif": 3.3, "Kolesterol": 0, "Sodyum": 21, "Potasyum": 200, "Kalsiyum": 35, "Vitamin A": 0, "Vitamin C": 0, "Demir": 3.3},
  "bebek bisküvisi": {"Enerji": 420, "Karbonhidrat": 75.0, "Protein": 8.0, "Yağ": 10.0, "Lif": 2.5, "Kolesterol": 5, "Sodyum": 200, "Potasyum": 150, "Kalsiyum": 120, "Vitamin A": 100, "Vitamin C": 5, "Demir": 4.0},
  "kuru fasulye": {"Enerji": 333, "Karbonhidrat": 60.0, "Protein": 23.4, "Yağ": 0.8, "Lif": 15.2, "Kolesterol": 0, "Sodyum": 16, "Potasyum": 1185, "Kalsiyum": 240, "Vitamin A": 0, "Vitamin C": 0, "Demir": 5.5},
  "barbunya": {"Enerji": 335, "Karbonhidrat": 60.1, "Protein": 23.0, "Yağ": 1.2, "Lif": 24.7, "Kolesterol": 0, "Sodyum": 6, "Potasyum": 1332, "Kalsiyum": 127, "Vitamin A": 0, "Vitamin C": 0, "Demir": 5.0},
  "kuru börülce": {"Enerji": 336, "Karbonhidrat": 60.0, "Protein": 23.5, "Yağ": 1.3, "Lif": 10.6, "Kolesterol": 0, "Sodyum": 16, "Potasyum": 1112, "Kalsiyum": 110, "Vitamin A": 50, "Vitamin C": 1.5, "Demir": 8.3},
  "teff": {"Enerji": 367, "Karbonhidrat": 73.1, "Protein": 13.3, "Yağ": 2.4, "Lif": 8.0, "Kolesterol": 0, "Sodyum": 12, "Potasyum": 427, "Kalsiyum": 180, "Vitamin A": 9, "Vitamin C": 0, "Demir": 7.6},

  // --- PROTEİN / SÜT (ek 2) ---
  "dana ilikli kemik suyu": {"Enerji": 40, "Karbonhidrat": 0, "Protein": 8.0, "Yağ": 1.0, "Lif": 0, "Kolesterol": 5, "Sodyum": 200, "Potasyum": 90, "Kalsiyum": 10, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.5},
  "tuzsuz keçi peyniri": {"Enerji": 264, "Karbonhidrat": 0.9, "Protein": 18.5, "Yağ": 21.0, "Lif": 0, "Kolesterol": 46, "Sodyum": 100, "Potasyum": 158, "Kalsiyum": 140, "Vitamin A": 1500, "Vitamin C": 0, "Demir": 1.6},
  "kefir": {"Enerji": 55, "Karbonhidrat": 4.5, "Protein": 3.3, "Yağ": 3.0, "Lif": 0, "Kolesterol": 12, "Sodyum": 40, "Potasyum": 164, "Kalsiyum": 120, "Vitamin A": 30, "Vitamin C": 0.5, "Demir": 0.04},
  "kuzu karaciğeri": {"Enerji": 168, "Karbonhidrat": 1.8, "Protein": 20.4, "Yağ": 7.8, "Lif": 0, "Kolesterol": 371, "Sodyum": 70, "Potasyum": 313, "Kalsiyum": 7, "Vitamin A": 23000, "Vitamin C": 4.0, "Demir": 7.4},
  "bıldırcın yumurtası": {"Enerji": 158, "Karbonhidrat": 0.4, "Protein": 13.1, "Yağ": 11.1, "Lif": 0, "Kolesterol": 844, "Sodyum": 141, "Potasyum": 132, "Kalsiyum": 64, "Vitamin A": 543, "Vitamin C": 0, "Demir": 3.65},

  // --- BALIK (ek 2) ---
  "sardalya": {"Enerji": 208, "Karbonhidrat": 0, "Protein": 24.6, "Yağ": 11.5, "Lif": 0, "Kolesterol": 142, "Sodyum": 307, "Potasyum": 397, "Kalsiyum": 382, "Vitamin A": 108, "Vitamin C": 0, "Demir": 2.9},
  "dil balığı": {"Enerji": 91, "Karbonhidrat": 0, "Protein": 18.8, "Yağ": 1.2, "Lif": 0, "Kolesterol": 48, "Sodyum": 81, "Potasyum": 361, "Kalsiyum": 23, "Vitamin A": 33, "Vitamin C": 0, "Demir": 0.35},
  "hamsi": {"Enerji": 131, "Karbonhidrat": 0, "Protein": 20.3, "Yağ": 4.8, "Lif": 0, "Kolesterol": 60, "Sodyum": 104, "Potasyum": 383, "Kalsiyum": 147, "Vitamin A": 50, "Vitamin C": 0, "Demir": 3.25},
  "lüfer": {"Enerji": 124, "Karbonhidrat": 0, "Protein": 20.0, "Yağ": 4.2, "Lif": 0, "Kolesterol": 59, "Sodyum": 60, "Potasyum": 372, "Kalsiyum": 7, "Vitamin A": 397, "Vitamin C": 0, "Demir": 0.48},
  "kalkan balığı": {"Enerji": 95, "Karbonhidrat": 0, "Protein": 16.1, "Yağ": 3.0, "Lif": 0, "Kolesterol": 48, "Sodyum": 150, "Potasyum": 357, "Kalsiyum": 18, "Vitamin A": 11, "Vitamin C": 1.8, "Demir": 0.4},

  // --- YAĞ / KURUYEMİŞ / DİĞER (ek 2) ---
  "avokado yağı": {"Enerji": 884, "Karbonhidrat": 0, "Protein": 0, "Yağ": 100, "Lif": 0, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 0, "Kalsiyum": 0, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0},
  "hindistan cevizi yağı": {"Enerji": 862, "Karbonhidrat": 0, "Protein": 0, "Yağ": 100, "Lif": 0, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 0, "Kalsiyum": 1, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.05},
  "keçiboynuzu unu": {"Enerji": 222, "Karbonhidrat": 88.9, "Protein": 4.6, "Yağ": 0.7, "Lif": 39.8, "Kolesterol": 0, "Sodyum": 35, "Potasyum": 827, "Kalsiyum": 348, "Vitamin A": 14, "Vitamin C": 0.2, "Demir": 2.9},
  "keçiboynuzu özü": {"Enerji": 300, "Karbonhidrat": 73.0, "Protein": 1.0, "Yağ": 0.1, "Lif": 1.5, "Kolesterol": 0, "Sodyum": 40, "Potasyum": 800, "Kalsiyum": 200, "Vitamin A": 0, "Vitamin C": 0, "Demir": 4.5},
  "çam fıstığı": {"Enerji": 673, "Karbonhidrat": 13.1, "Protein": 13.7, "Yağ": 68.4, "Lif": 3.7, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 597, "Kalsiyum": 16, "Vitamin A": 29, "Vitamin C": 0.8, "Demir": 5.53},
  "keten tohumu": {"Enerji": 534, "Karbonhidrat": 28.9, "Protein": 18.3, "Yağ": 42.2, "Lif": 27.3, "Kolesterol": 0, "Sodyum": 30, "Potasyum": 813, "Kalsiyum": 255, "Vitamin A": 0, "Vitamin C": 0.6, "Demir": 5.73},
  "kabak çekirdeği içi": {"Enerji": 559, "Karbonhidrat": 10.7, "Protein": 30.2, "Yağ": 49.0, "Lif": 6.0, "Kolesterol": 0, "Sodyum": 7, "Potasyum": 809, "Kalsiyum": 46, "Vitamin A": 16, "Vitamin C": 1.9, "Demir": 8.82},
  "ruşeymli irmik": {"Enerji": 362, "Karbonhidrat": 70.0, "Protein": 14.5, "Yağ": 2.5, "Lif": 5.0, "Kolesterol": 0, "Sodyum": 1, "Potasyum": 250, "Kalsiyum": 20, "Vitamin A": 0, "Vitamin C": 0, "Demir": 3.0},
  "susam": {"Enerji": 573, "Karbonhidrat": 23.4, "Protein": 17.7, "Yağ": 49.7, "Lif": 11.8, "Kolesterol": 0, "Sodyum": 11, "Potasyum": 468, "Kalsiyum": 975, "Vitamin A": 9, "Vitamin C": 0, "Demir": 14.6},
  "ihlamur çayı": {"Enerji": 1, "Karbonhidrat": 0.2, "Protein": 0, "Yağ": 0, "Lif": 0, "Kolesterol": 0, "Sodyum": 2, "Potasyum": 8, "Kalsiyum": 3, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0.05},
};

/// "1 adet" için ortalama yenilebilir gram ağırlığı (kabuk/çekirdek hariç).
/// Tarif malzemesi "adet/dilim/tane" olarak verildiğinde grama çevirmek için.
/// USDA standart porsiyon ağırlıkları temel alınmıştır. Keyed: küçük harf TR ad.
const Map<String, double> kFoodGramsPerPiece = {
  // Meyveler (yenilebilir kısım)
  "muz": 100, "elma": 150, "armut": 160, "şeftali": 120, "kayısı": 35,
  "erik": 50, "avokado": 100, "kavun": 160, "karpuz": 280, "mango": 140,
  "ananas": 80, "incir": 50, "mandalina": 80, "portakal": 130, "limon": 60,
  "çilek": 12, "kivi": 75, "nar": 110, "vişne": 8, "kiraz": 8, "üzüm": 5,
  "böğürtlen": 2, "yaban mersini": 1.5, "hurma": 24,
  // Sebzeler
  "havuç": 60, "patates": 130, "tatlı patates": 130, "kabak": 200,
  "balkabağı": 200, "soğan": 110, "kırmızı biber": 120, "domates": 120,
  "salatalık": 150, "yer elması": 60, "pancar": 80, "enginar": 120,
  "sarımsak": 5, "kereviz": 200, "pırasa": 90,
  // Protein / yumurta
  "yumurta sarısı": 18, "yumurta akı": 33, "tam yumurta": 50, "haşlanmış yumurta": 50,
  "bıldırcın yumurtası": 9,
};

/// Boğulma riski tablosu: küçük harf ad → [risk seviyesi, güvenli sunum notu].
/// Risk: 'Düşük' | 'Orta' | 'Yüksek'. Tabloda olmayan besinler 'Düşük' sayılır.
const Map<String, List<String>> kFoodChoking = {
  // --- YÜKSEK RİSK: yuvarlak/sert/kuruyemiş ---
  "üzüm": ["Yüksek", "Bütün üzüm tanesi hava yolunu tıkayabilir. 1 yaşından sonra boyuna ikiye veya dörde bölüp çekirdeklerini çıkararak verin; asla bütün vermeyin."],
  "kiraz": ["Yüksek", "Çekirdeği çıkarın ve ikiye bölün. Yuvarlak ve sert olduğundan bütün halde boğulma riski taşır."],
  "vişne": ["Yüksek", "Çekirdeğini mutlaka çıkarın ve ezin/ikiye bölün. Bütün halde verilmez."],
  "nar": ["Yüksek", "Nar taneleri sert çekirdeği nedeniyle yüksek boğulma riskidir. İlk yıl yalnızca süzülmüş suyunu, sonra taneleri ezerek verin."],
  "ceviz": ["Yüksek", "Bütün ve parça kuruyemiş 4 yaşına kadar boğulma riskidir. Yalnızca un gibi öğütülmüş veya pürüzsüz ezme olarak verin."],
  "badem": ["Yüksek", "Bütün badem verilmez. Un haline getirilmiş veya pürüzsüz badem ezmesi olarak sunun."],
  "fındık": ["Yüksek", "Bütün fındık boğulma riskidir. Öğütülmüş toz veya pürüzsüz ezme olarak ekleyin."],
  "çam fıstığı": ["Yüksek", "Küçük ve sert; bütün verilmez. Öğütülmüş halde pesto/harç içinde kullanın."],
  "susam": ["Yüksek", "Bütün taneler yerine tahin (ezme) veya öğütülmüş halde verin."],
  "kabak çekirdeği içi": ["Yüksek", "Bütün verilmez; un gibi öğütülerek sunulur."],
  "fıstık ezmesi": ["Yüksek", "Kalın/yapışkan ezme damağa yapışabilir. İnce tabaka halinde sürün veya püre/yoğurtla inceltin."],
  // --- ORTA RİSK: yuvarlak küçük / yapışkan / lifli ---
  "bezelye": ["Orta", "Bütün taneler küçük ve yuvarlak. İlk aylarda ezerek, ileride iyi gözetim altında verin."],
  "yaban mersini": ["Orta", "Bütün taneler yuvarlaktır. Ezin veya ikiye bölerek sunun."],
  "böğürtlen": ["Orta", "Çatalla ezerek veya ikiye bölerek verin."],
  "çilek": ["Orta", "Bütün çilek boğulabilir. Rendeleyin veya ince dilimleyin."],
  "nohut": ["Orta", "Kabuğu yuvarlak ve serttir. Kabuğunu soyup ezerek (humus gibi) verin."],
  "kuru fasulye": ["Orta", "Kabuğunu soyup iyice ezerek sunun."],
  "barbunya": ["Orta", "İyice haşlayıp kabuğunu soyun ve ezin."],
  "kuru üzüm": ["Orta", "Yapışkan ve küçük; suda yumuşatıp ezerek veya ince doğrayarak verin."],
  "kurutulmuş üzüm": ["Orta", "Suda yumuşatıp ezin; bütün halde yapışarak boğulma riski taşır."],
  "hurma": ["Orta", "Yapışkandır; çekirdeğini çıkarıp suda yumuşatın ve küçük parçalara bölün."],
  "kuru kayısı": ["Orta", "Suda yumuşatıp küçük doğrayın; bütün kuru meyve yapışabilir."],
  "kuru incir": ["Orta", "Çekirdekli ve yapışkandır; suda yumuşatıp ince doğrayın."],
  "kuru erik": ["Orta", "Çekirdeğini çıkarın, yumuşatıp ezin veya küçük doğrayın."],
  "kuru dut": ["Orta", "Öğütülmüş veya suda yumuşatılıp ezilmiş olarak verin."],
  "bebek bisküvisi": ["Orta", "Kırılan sert parçalara dikkat; ıslatarak veya gözetim altında verin."],
  "elma": ["Orta", "Çiğ elma sert ve kaygandır. İlk yıl rendeleyin veya yumuşayana kadar pişirin; çiğ dilim vermeyin."],
  "havuç": ["Orta", "Çiğ havuç serttir. Buharda yumuşatın; çiğ çubuk/dilim boğulma riskidir."],
};
