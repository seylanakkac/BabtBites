import 'nutrition_database.dart';
import 'unit_conversion.dart';

/// Besin/tablo anahtarı normalizasyonu. Türkçe "İ" harfi `toLowerCase()` ile
/// "i" + birleşik nokta (U+0307) üretir; bu noktayı atarak tabloların düz
/// küçük-harf anahtarlarıyla ("incir", "irmik") eşleşmeyi garantiler.
String foodKey(String s) {
  final l = s.toLowerCase().trim();
  // U+0300–U+036F arası birleşik aksan işaretlerini (örn. "İ"→"i̇" noktası) at.
  return String.fromCharCodes(l.runes.where((r) => r < 0x0300 || r > 0x036F));
}

class Food {
  final String name;
  final String emoji;
  final String category; // 'Sebze', 'Meyve', 'Tahıl', 'Et', 'Balık', 'Diğer'
  final int startingMonth;
  final String allergyRisk; // 'Düşük', 'Orta', 'Yüksek'
  final Map<int, String> presentationStyles; // e.g. {6: "Püre...", 9: "...", 12: "..."}
  final Map<String, double> nutritionValues; // Energy(kcal), Protein(g), Fat(g), Iron(mg)
  final String imageUrl; // optional photo (base64 data URI / URL); empty = use emoji
  final String cartUnit; // shopping-list unit: "adet", "kg", "gr", "demet"...
  final double gramsPerPiece; // 1 "adet" kaç gram (0 = bilinmiyor/tabloya bak)
  final String chokingRisk; // boğulma riski: 'Düşük' | 'Orta' | 'Yüksek' ('' = tabloya bak)
  final String chokingNote; // güvenli sunum / boğulma önlemi açıklaması
  final bool needsReview; // true → besin/güvenlik verisi uzman onayı bekliyor
  bool tried;
  bool isFavorite;

  Food({
    required this.name,
    required this.emoji,
    required this.category,
    required this.startingMonth,
    required this.allergyRisk,
    required this.presentationStyles,
    required this.nutritionValues,
    this.imageUrl = "",
    this.cartUnit = "adet",
    this.gramsPerPiece = 0,
    this.chokingRisk = "",
    this.chokingNote = "",
    this.needsReview = false,
    this.tried = false,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "emoji": emoji,
        "category": category,
        "startingMonth": startingMonth,
        "allergyRisk": allergyRisk,
        "presentationStyles": presentationStyles.map((k, v) => MapEntry(k.toString(), v)),
        "nutritionValues": nutritionValues,
        "imageUrl": imageUrl,
        "cartUnit": cartUnit,
        "gramsPerPiece": gramsPerPiece,
        "chokingRisk": chokingRisk,
        "chokingNote": chokingNote,
        "needsReview": needsReview,
      };

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        name: j["name"]?.toString() ?? "",
        emoji: j["emoji"]?.toString() ?? "🍽️",
        category: j["category"]?.toString() ?? "Diğer",
        startingMonth: (j["startingMonth"] as num?)?.toInt() ?? 6,
        allergyRisk: j["allergyRisk"]?.toString() ?? "Düşük",
        presentationStyles: (j["presentationStyles"] as Map?)
                ?.map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 6, v.toString())) ??
            {},
        nutritionValues: (j["nutritionValues"] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
            {},
        imageUrl: j["imageUrl"]?.toString() ?? "",
        cartUnit: j["cartUnit"]?.toString() ?? "adet",
        gramsPerPiece: (j["gramsPerPiece"] as num?)?.toDouble() ?? 0,
        chokingRisk: j["chokingRisk"]?.toString() ?? "",
        chokingNote: j["chokingNote"]?.toString() ?? "",
        needsReview: j["needsReview"] == true,
      );

  /// Resolves the cart/shopping unit for a food name (built-in or custom).
  static String unitFor(String name) {
    final m = globalFoodsDatabase.where((f) => f.name.toLowerCase() == name.toLowerCase()).toList();
    return m.isNotEmpty ? m.first.cartUnit : "adet";
  }
}

/// 1 "adet" için ortalama gram ağırlığı. Önce besinin kendi alanı (admin/özel),
/// yoksa yerleşik [kFoodGramsPerPiece] tablosu, o da yoksa 0 (varsayılan kullanılır).
double gramsPerPieceFor(Food food) {
  if (food.gramsPerPiece > 0) return food.gramsPerPiece;
  return kFoodGramsPerPiece[foodKey(food.name)] ?? 0;
}

/// İsimle 1 adet gram ağırlığı (tarif malzemesi besine bağlanırken kullanılır).
double gramsPerPieceForName(String name) {
  for (final f in globalFoodsDatabase) {
    if (f.name.toLowerCase() == name.toLowerCase()) return gramsPerPieceFor(f);
  }
  return kFoodGramsPerPiece[foodKey(name)] ?? 0;
}

/// Boğulma riski seviyesi: besin alanı → tablo → kategori bazlı makul varsayılan.
String chokingRiskFor(Food food) {
  if (food.chokingRisk.isNotEmpty) return food.chokingRisk;
  final t = kFoodChoking[foodKey(food.name)];
  if (t != null) return t[0];
  return "Orta"; // veri yoksa fail-safe: düşük değil orta (gözetim gerekir)
}

/// Boğulma riskine karşı güvenli sunum açıklaması.
String chokingNoteFor(Food food) {
  if (food.chokingNote.isNotEmpty) return food.chokingNote;
  final t = kFoodChoking[foodKey(food.name)];
  if (t != null) return t[1];
  return "Bebeğin gelişimine uygun kıvamda (püre/yumuşak dilim) ve her zaman gözetim "
      "altında sunun. İlk yıl yuvarlak, sert ve kaygan parçalardan kaçının.";
}

class Recipe {
  final String id;
  final String name;
  final String prepTime;
  final int startingMonth;
  final double kcal;
  final String imageUrl;
  final List<String> ingredients; // list of food names
  final List<String> ingredientAmounts; // e.g. "100 gr", "1 adet"
  final List<String> steps;
  final String allergyWarning;
  final String author; // recipe creator shown as "Hazırlayan: ..."
  final bool sponsored; // admin-flagged sponsored content
  final String sponsorLabel; // brand/sponsor name shown on the "Sponsorlu" badge
  final String category; // tarif kategorisi (kRecipeCategories), boş = "Diğer"
  final String videoUrl; // opsiyonel YouTube linki (normal veya Shorts); boş = yok
  final int servings; // kaç porsiyon (besin değeri buna bölünür); en az 1

  Recipe({
    required this.id,
    required this.name,
    required this.prepTime,
    required this.startingMonth,
    required this.kcal,
    required this.imageUrl,
    required this.ingredients,
    required this.ingredientAmounts,
    required this.steps,
    required this.allergyWarning,
    this.author = "BabyBites",
    this.sponsored = false,
    this.sponsorLabel = "",
    this.category = "Diğer",
    this.videoUrl = "",
    this.servings = 1,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "prepTime": prepTime,
        "startingMonth": startingMonth,
        "kcal": kcal,
        "imageUrl": imageUrl,
        "ingredients": ingredients,
        "ingredientAmounts": ingredientAmounts,
        "steps": steps,
        "allergyWarning": allergyWarning,
        "author": author,
        "sponsored": sponsored,
        "sponsorLabel": sponsorLabel,
        "category": category,
        "videoUrl": videoUrl,
        "servings": servings,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j["id"]?.toString() ?? "",
        name: j["name"]?.toString() ?? "",
        prepTime: j["prepTime"]?.toString() ?? "",
        startingMonth: (j["startingMonth"] as num?)?.toInt() ?? 6,
        kcal: (j["kcal"] as num?)?.toDouble() ?? 0,
        imageUrl: j["imageUrl"]?.toString() ?? "",
        ingredients: (j["ingredients"] as List?)?.map((e) => e.toString()).toList() ?? [],
        ingredientAmounts: (j["ingredientAmounts"] as List?)?.map((e) => e.toString()).toList() ?? [],
        steps: (j["steps"] as List?)?.map((e) => e.toString()).toList() ?? [],
        allergyWarning: j["allergyWarning"]?.toString() ?? "",
        author: j["author"]?.toString() ?? "BabyBites",
        sponsored: j["sponsored"] == true,
        sponsorLabel: j["sponsorLabel"]?.toString() ?? "",
        category: j["category"]?.toString() ?? "Diğer",
        videoUrl: j["videoUrl"]?.toString() ?? "",
        servings: (j["servings"] as num?)?.toInt() ?? 1,
      );
}

/// Tarifin etkin kategorisi: admin/kullanıcı bir kategori atadıysa onu kullanır;
/// "Diğer" ise ada bakarak makul bir kategori çıkarır (mevcut tarifler için).
String effectiveRecipeCategory(Recipe r) {
  if (r.category.isNotEmpty && r.category != "Diğer") return r.category;
  final n = r.name.toLowerCase();
  if (n.contains("çorba")) return "Bebek Çorbaları";
  if (n.contains("köfte")) return "Bebek Köfteleri";
  if (n.contains("muhallebi") || n.contains("mama") || n.contains("puding")) return "Bebek Muhallebisi ve Mama Tarifleri";
  if (n.contains("bisküvi") || n.contains("kurabiye") || n.contains("kraker")) return "Bebek Bisküvileri";
  if (n.contains("pankek") || n.contains("krep") || n.contains("gözleme")) return "Bebek Pankek Tarifleri";
  if (n.contains("ekmek") || n.contains("kek") || n.contains("muffin")) return "Bebek Ekmekleri";
  if (n.contains("çay")) return "Bebek Çayları";
  if (n.contains("kahvalt") || n.contains("omlet") || n.contains("yulaf")) return "Bebek Kahvaltısı";
  if (n.contains("püre") || n.contains("ezme")) return "Bebek Püreleri";
  return "Diğer";
}

/// Tarif kategorileri (admin/kullanıcı tarifleri için).
const List<String> kRecipeCategories = [
  "Bebek Püreleri",
  "Bebek Çorbaları",
  "Bebek Köfteleri",
  "Bebek Kahvaltısı",
  "Bebek Muhallebisi ve Mama Tarifleri",
  "Bebek Bisküvileri",
  "Bebek Pankek Tarifleri",
  "Bebek Ekmekleri",
  "Bebek Çayları",
  "Diğer",
];

/// Admin-added foods/recipes (raw JSON), merged into the databases on startup.
final List<Map<String, dynamic>> globalCustomFoods = [];
final List<Map<String, dynamic>> globalCustomRecipes = [];

/// TR gıda adı (foodKey) → TheMealDB malzeme görseli dosya adı (İngilizce).
/// Web'de fotoğrafı olmayan gıdalar için ücretsiz CDN'den gerçek fotoğraf çekilir;
/// eşleşmeyen ya da 404 olanlar zarif şekilde ikon yer-tutucuya düşer.
const Map<String, String> kMealDbIngredient = {
  // Sebzeler
  "brokoli": "Broccoli", "havuç": "Carrots", "kabak": "Courgettes", "patates": "Potatoes",
  "balkabağı": "Pumpkin", "bezelye": "Peas", "ispanak": "Spinach", "karnabahar": "Cauliflower",
  "tatlı patates": "Sweet Potatoes", "kereviz": "Celery", "pırasa": "Leek", "kırmızı biber": "Red Pepper",
  "pancar": "Beetroot", "kuşkonmaz": "Asparagus", "taze fasulye": "Green Beans", "sarımsak": "Garlic",
  "soğan": "Onion", "dereotu": "Dill", "maydanoz": "Parsley", "bamya": "Okra",
  // Meyveler
  "muz": "Banana", "elma": "Apple", "armut": "Pear", "şeftali": "Peach", "kayısı": "Apricot",
  "erik": "Plum", "kavun": "Melon", "karpuz": "Watermelon", "böğürtlen": "Blackberries",
  "yaban mersini": "Blueberries", "mango": "Mango", "ananas": "Pineapple", "incir": "Figs",
  "hurma": "Dates", "portakal": "Orange", "limon": "Lemon", "çilek": "Strawberries",
  "kivi": "Kiwi", "nar": "Pomegranate", "vişne": "Cherries", "kiraz": "Cherries", "üzüm": "Grapes",
  // Tahıllar & baklagiller
  "yulaf": "Oats", "pirinç": "Rice", "kinoa": "Quinoa", "kırmızı mercimek": "Red Lentils",
  "yeşil mercimek": "Lentils", "nohut": "Chickpeas", "bulgur": "Bulgur Wheat",
  // Protein & süt
  "yumurta sarısı": "Egg Yolks", "haşlanmış yumurta": "Eggs", "yumurta akı": "Egg Whites",
  "tavuk göğsü": "Chicken Breast", "dana kıyma": "Minced Beef", "yoğurt": "Yogurt",
  "kuzu eti": "Lamb", "hindi göğsü": "Turkey Breast", "tereyağı": "Butter",
  // Balık
  "somon": "Salmon", "sardalya": "Sardines", "hamsi": "Anchovies",
  // Diğer
  "zeytinyağı": "Olive Oil", "ceviz": "Walnuts", "badem": "Almonds", "fındık": "Hazelnuts",
  "tahin": "Tahini", "susam": "Sesame Seed", "chia tohumu": "Chia Seeds",
};

/// Web'de gösterilecek CDN fotoğraf URL'i (TheMealDB). Eşleşme yoksa null.
String? cdnFoodPhotoUrl(String name) {
  final n = kMealDbIngredient[foodKey(name)];
  if (n == null) return null;
  return "https://www.themealdb.com/images/ingredients/${n.replaceAll(' ', '%20')}.png";
}

/// Carbohydrate estimate (g) via the Atwater relation from energy/protein/fat:
/// energy(kcal) ≈ 4·protein + 9·fat + 4·carb  →  carb ≈ (energy − 4·protein − 9·fat)/4.
double atwaterCarb(double energy, double protein, double fat) {
  final c = (energy - protein * 4 - fat * 9) / 4;
  return c < 0 ? 0 : c;
}

/// Detailed per-100g nutrition map for a food. Uses the researched
/// [kDetailedNutrition] table when the food is a built-in; otherwise derives a
/// partial map from [Food.nutritionValues] with an Atwater carbohydrate
/// estimate. Always contains at least Enerji/Karbonhidrat/Protein/Yağ.
Map<String, double> nutritionForFood(Food food) {
  final nv = food.nutritionValues;
  // If the food itself carries detailed values (admin-entered / custom), those
  // win; otherwise use the researched USDA table for built-ins.
  final hasOwnDetail = nv.containsKey("Karbonhidrat") || nv.containsKey("Lif") || nv.containsKey("Sodyum");
  if (!hasOwnDetail) {
    final detail = kDetailedNutrition[foodKey(food.name)];
    if (detail != null) {
      return {for (final k in kNutrientKeys) k: detail[k] ?? 0.0};
    }
  }
  final result = <String, double>{};
  // Surface every detailed nutrient the food actually stores (admin-entered).
  for (final k in kNutrientKeys) {
    if (nv.containsKey(k)) result[k] = nv[k]!;
  }
  result["Yağ"] ??= nv["Sağlıklı Yağ"] ?? 0;
  result["Enerji"] ??= nv["Enerji"] ?? 0;
  result["Protein"] ??= nv["Protein"] ?? 0;
  result["Demir"] ??= nv["Demir"] ?? 0;
  result["Karbonhidrat"] ??= atwaterCarb(result["Enerji"]!, result["Protein"]!, result["Yağ"]!);
  return result;
}

/// Tarif malzeme adlarının gıda veritabanındaki karşılıkları (tam ad farklıysa).
const Map<String, String> kIngredientAliases = {
  "tavuk": "Tavuk Göğsü",
  "hindi": "Hindi Göğsü",
  "peynir": "Lor Peyniri",
  "yumurta": "Haşlanmış Yumurta",
  "balık": "Somon",
};

/// Gıda veritabanında Food olarak bulunmayan ama tariflerde geçen sıvı/ek
/// malzemeler için 100 g (≈100 ml) besin değeri.
const Map<String, Map<String, double>> kExtraIngredientNutrition = {
  "anne sütü": {"Enerji": 70, "Karbonhidrat": 6.9, "Protein": 1.0, "Yağ": 4.2, "Lif": 0, "Kolesterol": 14, "Sodyum": 17, "Potasyum": 51, "Kalsiyum": 32, "Vitamin A": 212, "Vitamin C": 5, "Demir": 0.03},
  "formül mama": {"Enerji": 66, "Karbonhidrat": 7.3, "Protein": 1.3, "Yağ": 3.5, "Lif": 0, "Kolesterol": 0, "Sodyum": 18, "Potasyum": 70, "Kalsiyum": 51, "Vitamin A": 200, "Vitamin C": 8, "Demir": 0.7},
  "su": {"Enerji": 0, "Karbonhidrat": 0, "Protein": 0, "Yağ": 0, "Lif": 0, "Kolesterol": 0, "Sodyum": 0, "Potasyum": 0, "Kalsiyum": 0, "Vitamin A": 0, "Vitamin C": 0, "Demir": 0},
};

/// Bir tarif malzeme adını gıda veritabanındaki [Food]'a çözer: tam ad →
/// eşanlamlı → içerik eşleşmesi. Bulamazsa null.
Food? foodForIngredient(String name) {
  final key = name.toLowerCase().trim();
  for (final f in globalFoodsDatabase) {
    if (f.name.toLowerCase() == key) return f;
  }
  final alias = kIngredientAliases[key];
  if (alias != null) {
    for (final f in globalFoodsDatabase) {
      if (f.name.toLowerCase() == alias.toLowerCase()) return f;
    }
  }
  // İçerik eşleşmesi ("Tavuk" → "Tavuk Göğsü"). Çok kısa adlarda atla.
  if (key.length >= 3) {
    for (final f in globalFoodsDatabase) {
      final fn = f.name.toLowerCase();
      if (fn.contains(key) || key.contains(fn)) return f;
    }
  }
  return null;
}

/// Bir malzemenin 100 g besin değeri (Food → [nutritionForFood], yoksa
/// [kExtraIngredientNutrition]). Çözülemezse null.
Map<String, double>? nutritionForIngredient(String name) {
  final f = foodForIngredient(name);
  if (f != null) return nutritionForFood(f);
  final extra = kExtraIngredientNutrition[name.toLowerCase().trim()];
  if (extra != null) return {for (final k in kNutrientKeys) k: extra[k] ?? 0};
  return null;
}

/// Bir malzeme adı için 1 "adet" gram ağırlığı (çözümlemeli).
double _ingredientGramsPerPiece(String name) {
  final f = foodForIngredient(name);
  if (f != null) return gramsPerPieceFor(f);
  return kFoodGramsPerPiece[foodKey(name)] ?? 0;
}

/// Aggregated detailed nutrition for a recipe — her malzemenin GERÇEK miktarına
/// göre ölçeklenerek hesaplanır. Malzeme miktarı ([Recipe.ingredientAmounts])
/// birim→gram dönüşümünden geçer ([amountToGrams]) ve malzemenin 100 g değeri
/// (gram/100) ile çarpılır. Böylece "50 gr soğan" tam 50 g sayılır.
/// Hiçbir malzeme çözülemezse tarifin saklı `kcal` değerine düşülür.
Map<String, double> nutritionForRecipe(Recipe recipe) {
  final sum = {for (final k in kNutrientKeys) k: 0.0};
  bool anyResolved = false;
  for (var i = 0; i < recipe.ingredients.length; i++) {
    final n = nutritionForIngredient(recipe.ingredients[i]);
    if (n == null) continue;
    final amount = i < recipe.ingredientAmounts.length ? recipe.ingredientAmounts[i] : "";
    final grams = amountToGrams(amount, gramsPerPiece: _ingredientGramsPerPiece(recipe.ingredients[i]));
    if (grams == null || grams <= 0) continue; // miktar çözülemedi → atla
    anyResolved = true;
    final factor = grams / 100.0;
    for (final k in kNutrientKeys) {
      sum[k] = sum[k]! + (n[k] ?? 0) * factor;
    }
  }

  if (!anyResolved) {
    // Hiçbir malzeme çözülemedi (özel/eski tarif) → saklı kcal'a düş.
    sum["Enerji"] = recipe.kcal;
    sum["Karbonhidrat"] = atwaterCarb(recipe.kcal, 0, 0);
    return sum;
  }
  if ((sum["Karbonhidrat"] ?? 0) == 0) {
    sum["Karbonhidrat"] = atwaterCarb(sum["Enerji"]!, sum["Protein"]!, sum["Yağ"]!);
  }
  // Porsiyon başına böl (kek/çok porsiyonlu tariflerde tüm-tarif toplamı değil,
  // bir porsiyonun değeri gösterilir). servings=1 ise değişmez.
  final s = recipe.servings < 1 ? 1 : recipe.servings;
  if (s > 1) {
    for (final k in kNutrientKeys) {
      sum[k] = sum[k]! / s;
    }
  }
  return sum;
}

/// Tarifin malzemelerinden hesaplanan toplam kalori (kcal). Hiç malzeme
/// çözülemezse tarifin saklı kcal'ı döner. Kart/detay/admin gösterimi için.
double computedRecipeEnergy(Recipe recipe) {
  final n = nutritionForRecipe(recipe);
  return n["Enerji"] ?? 0;
}

/// JSON tarif verisinden ([Recipe.fromJson] geçmeden) kalori hesaplar — admin
/// formundaki "otomatik" buton için. ingredients + amounts listeleri verilir.
/// Hiç malzeme çözülemezse 0 döner.
double computeEnergyFromIngredients(List<String> ingredients, List<String> amounts) {
  double total = 0;
  for (var i = 0; i < ingredients.length; i++) {
    final n = nutritionForIngredient(ingredients[i]);
    if (n == null) continue;
    final amount = i < amounts.length ? amounts[i] : "";
    final grams = amountToGrams(amount, gramsPerPiece: _ingredientGramsPerPiece(ingredients[i]));
    if (grams == null || grams <= 0) continue;
    total += (n["Enerji"] ?? 0) * grams / 100.0;
  }
  return total;
}

// 100 Foods Database
final List<Food> globalFoodsDatabase = [
  // --- SEBZELER (25 adet) ---
  Food(
    name: "Brokoli",
    emoji: "🥦",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Çiçek kısımlarını buharda iyice haşlayıp çatalla ezerek püre halinde sunabilirsiniz.",
      9: "Buharda haşlanmış, bebeğin eliyle kavrayabileceği büyüklükte küçük dallar halinde verebilirsiniz.",
      12: "Kendi kendine beslenmesi için hafif diri haşlanmış brokoli tanelerini yemeklerin içine katabilirsiniz."
    },
    nutritionValues: {"Enerji": 34, "Protein": 2.8, "Sağlıklı Yağ": 0.4, "Demir": 0.7},
  ),
  Food(
    name: "Avokado",
    emoji: "🥑",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Avokadoyu çatalla iyice ezip anne sütü veya formül mama ile yumuşatarak verebilirsiniz.",
      9: "Bebeğinizin kavrayabileceği büyüklükte (parmak boyu) uzun ve yumuşak dilimler sunabilirsiniz.",
      12: "Kendi kendine beslenmeyi desteklemek için küçük küpler halinde salatalara ekleyebilirsiniz."
    },
    nutritionValues: {"Enerji": 160, "Protein": 2.0, "Sağlıklı Yağ": 15.0, "Demir": 0.6},
  ),
  Food(
    name: "Havuç",
    emoji: "🥕",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Buharda yumuşayana kadar haşlayıp pürüzsüz püre haline getirin.",
      9: "Parmak şeklinde kesilmiş, iyice yumuşatılmış havuç dilimleri sunabilirsiniz.",
      12: "Fırınlanmış veya çorbalara küp küp doğranmış olarak ekleyebilirsiniz."
    },
    nutritionValues: {"Enerji": 41, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.3},
  ),
  Food(
    name: "Kabak",
    emoji: "🥒",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Kabuğu soyulmuş kabağı buharda pişirip püre halinde verin.",
      9: "Halkalar halinde veya parmak boyunda yumuşak dilimler olarak sunun.",
      12: "Mücver şeklinde fırınlayarak veya yemeklerin içinde doğranmış sunabilirsiniz."
    },
    nutritionValues: {"Enerji": 17, "Protein": 1.2, "Sağlıklı Yağ": 0.2, "Demir": 0.4},
  ),
  Food(
    name: "Patates",
    emoji: "🥔",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Haşlayıp ezdikten sonra az miktarda anne sütü ile kıvamını açın.",
      9: "Yumuşak haşlanmış elma dilim patates şeklinde sunun.",
      12: "Fırınlanmış veya diğer sebzelerle sotelenmiş şekilde verebilirsiniz."
    },
    nutritionValues: {"Enerji": 77, "Protein": 2.0, "Sağlıklı Yağ": 0.1, "Demir": 0.8},
  ),
  Food(
    name: "Balkabağı",
    emoji: "🎃",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Buharda pişirip pürüzsüz kıvama gelene kadar ezin.",
      9: "Yumuşak fırınlanmış balkabağı dilimleri (BLW uyumlu) sunabilirsiniz.",
      12: "Çorbalarda veya muhallebilerde tatlandırıcı olarak kullanabilirsiniz."
    },
    nutritionValues: {"Enerji": 26, "Protein": 1.0, "Sağlıklı Yağ": 0.1, "Demir": 0.8},
  ),
  Food(
    name: "Bezelye",
    emoji: "🟢",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Haşlayıp kabuklarını süzgeçten geçirerek püre haline getirin.",
      9: "Taneleri parmakla hafifçe ezerek yumuşak şekilde önüne koyabilirsiniz.",
      12: "Çorbalara ve pilavlara bütün bezelye tanesi olarak ekleyebilirsiniz."
    },
    nutritionValues: {"Enerji": 81, "Protein": 5.4, "Sağlıklı Yağ": 0.4, "Demir": 1.5},
  ),
  Food(
    name: "Ispanak",
    emoji: "🥬",
    category: "Sebze",
    startingMonth: 8,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "İyice yıkanmış yaprakları buharda pişirip püre halinde sunun.",
      9: "İnce kıyılmış ve pişirilmiş ıspanakları çorbalara katın.",
      12: "Ispanaklı krep veya yumurta ile pişirerek sunabilirsiniz."
    },
    nutritionValues: {"Enerji": 23, "Protein": 2.9, "Sağlıklı Yağ": 0.4, "Demir": 2.7},
  ),
  Food(
    name: "Karnabahar",
    emoji: "🥦",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Buharda haşlayıp püre haline getirerek sunun.",
      9: "Yumuşak haşlanmış küçük karnabahar çiçekleri olarak eline verebilirsiniz.",
      12: "Karnabahar tabanlı pizza veya fırınlanmış karnabahar köftesi yapabilirsiniz."
    },
    nutritionValues: {"Enerji": 25, "Protein": 1.9, "Sağlıklı Yağ": 0.3, "Demir": 0.4},
  ),
  Food(
    name: "Tatlı Patates",
    emoji: "🍠",
    category: "Sebze",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Haşlayıp pürüzsüz püre kıvamında sunun.",
      9: "Fırında yumuşayana kadar pişirilmiş şerit dilimler halinde verin.",
      12: "Küp küp doğranmış fırın yemeği olarak sunabilirsiniz."
    },
    nutritionValues: {"Enerji": 86, "Protein": 1.6, "Sağlıklı Yağ": 0.1, "Demir": 0.6},
  ),
  Food(name: "Kereviz", emoji: "🌱", category: "Sebze", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Püre halinde çorbalara ekleyin.", 9: "Haşlanmış kereviz sapı veya yumuşak küpler.", 12: "Rendelenmiş yoğurtlu kereviz salatası."}, nutritionValues: {"Enerji": 16, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.2}),
  Food(name: "Pırasa", emoji: "🧅", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "İnce kıyılmış püre halinde sunun.", 9: "Çorbaların içine katılmış pişmiş halkalar.", 12: "Pırasalı börek veya zeytinyağlı yemek."}, nutritionValues: {"Enerji": 61, "Protein": 1.5, "Sağlıklı Yağ": 0.3, "Demir": 2.1}),
  Food(name: "Enginar", emoji: "🥗", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlayıp püre şeklinde verin.", 9: "Küçük yumuşak enginar kalbi dilimleri.", 12: "Zeytinyağlı pirinçli enginar yemeği."}, nutritionValues: {"Enerji": 47, "Protein": 3.3, "Sağlıklı Yağ": 0.2, "Demir": 1.3}),
  Food(name: "Kırmızı Biber", emoji: "🫑", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulup közlenmiş püre halinde.", 9: "Közlenmiş, soyulmuş uzun şerit dilimler.", 12: "Yemeklere ve omletlere ince doğranmış olarak ekleyin."}, nutritionValues: {"Enerji": 31, "Protein": 1.0, "Sağlıklı Yağ": 0.3, "Demir": 0.4}),
  Food(name: "Yer Elması", emoji: "🥔", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlayıp püre halinde sunun.", 9: "Yumuşak pişirilmiş küçük dilimler.", 12: "Zeytinyağlı sebze yemeğinde küpler halinde."}, nutritionValues: {"Enerji": 73, "Protein": 2.0, "Sağlıklı Yağ": 0.0, "Demir": 3.4}),
  Food(name: "Pancar", emoji: "🍠", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlayıp veya fırınlayıp pürüzsüz püre yapın.", 9: "Küçük yumuşak haşlanmış küpler.", 12: "Rendelenmiş fırın mücverinde tatlandırıcı olarak."}, nutritionValues: {"Enerji": 43, "Protein": 1.6, "Sağlıklı Yağ": 0.2, "Demir": 0.8}),
  Food(name: "Kuşkonmaz", emoji: "🎋", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Buharda haşlayıp püre yapın.", 9: "Buharda haşlanmış yumuşak üst kısımlar.", 12: "Omletlerin yanında parmak gıda olarak sunun."}, nutritionValues: {"Enerji": 20, "Protein": 2.2, "Sağlıklı Yağ": 0.1, "Demir": 2.1}),
  Food(name: "Taze Fasulye", emoji: "🌱", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Kılçıksız fasulyeleri haşlayıp pürüzsüz püre yapın.", 9: "İyice yumuşatılmış uzun fasulye taneleri.", 12: "Zeytinyağlı taze fasulye yemeğinde dilimler."}, nutritionValues: {"Enerji": 31, "Protein": 1.8, "Sağlıklı Yağ": 0.1, "Demir": 1.0}),
  Food(name: "Bezelye Filizi", emoji: "🌿", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "İnce kıyılmış çorbaların içinde sunun.", 9: "Yumuşak sote edilmiş yeşillikler.", 12: "Pürelerin ve çorbaların üzerine çiğ/pişmiş süsleme."}, nutritionValues: {"Enerji": 30, "Protein": 2.0, "Sağlıklı Yağ": 0.2, "Demir": 1.2}),
  Food(name: "Pazı", emoji: "🥬", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlayıp sap kısımlarını ayırarak püre yapın.", 9: "İnce kıyılmış pazı yaprakları yemeklerin içinde.", 12: "Pazı sarma veya pazılı pirinçli çorbalar."}, nutritionValues: {"Enerji": 19, "Protein": 1.8, "Sağlıklı Yağ": 0.2, "Demir": 1.8}),
  Food(name: "Bamya", emoji: "🥒", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Püre halinde çorbalara kıvam verici olarak.", 9: "İyice pişmiş salyasız bamya dilimleri.", 12: "Limonlu zeytinyağlı bamya yemeği taneleri."}, nutritionValues: {"Enerji": 33, "Protein": 1.9, "Sağlıklı Yağ": 0.2, "Demir": 0.6}),
  Food(name: "Sarımsak", emoji: "🧄", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Fırınlanmış veya çorbalarda pişmiş yarım diş.", 9: "Yemeklerin içine lezzet vermesi için ezilmiş çeyrek diş.", 12: "Yoğurtlu soslarda veya köftelerde çiğ/pişmiş rendelenmiş."}, nutritionValues: {"Enerji": 149, "Protein": 6.4, "Sağlıklı Yağ": 0.5, "Demir": 1.7}),
  Food(name: "Soğan", emoji: "🧅", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çorbalarla birlikte pişirilip süzülmüş aromatik.", 9: "Yemeklerin içinde iyice pişmiş şeffaf halkalar.", 12: "Omletlerde ve köftelerde sote edilmiş küçük küpler."}, nutritionValues: {"Enerji": 40, "Protein": 1.1, "Sağlıklı Yağ": 0.1, "Demir": 0.2}),
  Food(name: "Dereotu", emoji: "🌿", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çorbalara pişerken aroma vermesi için ekleyin.", 9: "İnce kıyılmış şekilde çorba ve pürelerin üzerinde.", 12: "Yoğurt, peynir ve mücverlerin içinde taze kıyılmış."}, nutritionValues: {"Enerji": 43, "Protein": 3.4, "Sağlıklı Yağ": 1.1, "Demir": 6.6}),
  Food(name: "Maydanoz", emoji: "🌿", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Pişirme suyuna koku vermesi için dal halinde ekleyin.", 9: "Taze kıyılmış olarak pürelerin ve yemeklerin içinde.", 12: "Krep, omlet ve bebek köftelerinin içinde taze kıyılmış."}, nutritionValues: {"Enerji": 36, "Protein": 3.0, "Sağlıklı Yağ": 0.8, "Demir": 6.2}),

  // --- MEYVELER (25 adet) ---
  Food(
    name: "Muz",
    emoji: "🍌",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Çatalla ezerek püre halinde sunabilir veya sütle kıvamını açabilirsiniz.",
      9: "Kabuğunun yarısını soyup eline vererek kendi kendine yemesini sağlayabilirsiniz.",
      12: "Küçük halkalar halinde veya pancake harcının içinde ezerek verebilirsiniz."
    },
    nutritionValues: {"Enerji": 89, "Protein": 1.1, "Sağlıklı Yağ": 0.3, "Demir": 0.3},
  ),
  Food(
    name: "Elma",
    emoji: "🍎",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Kabuğu soyulup buharda pişirildikten sonra püre halinde sunun.",
      9: "Cam rendede rendelenmiş taze elma püresi şeklinde verebilirsiniz.",
      12: "Yumuşak fırınlanmış tarçınlı elma dilimleri halinde sunabilirsiniz."
    },
    nutritionValues: {"Enerji": 52, "Protein": 0.3, "Sağlıklı Yağ": 0.2, "Demir": 0.1},
  ),
  Food(
    name: "Armut",
    emoji: "🍐",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Buharda yumuşatıp süzgeçten geçirin ve püre halinde verin.",
      9: "Olgun, yumuşak armudu ince şerit dilimler halinde sunun.",
      12: "Küp küp doğranmış olgun armut taneleri şeklinde verin."
    },
    nutritionValues: {"Enerji": 57, "Protein": 0.4, "Sağlıklı Yağ": 0.1, "Demir": 0.2},
  ),
  Food(
    name: "Şeftali",
    emoji: "🍑",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Kabuğunu soyup çatalla ezerek taze püre halinde verin.",
      9: "Yumuşak, soyulmuş şeftali dilimleri (BLW uyumlu) sunun.",
      12: "Yoğurdun içine küçük küçük doğrayarak meyveli yoğurt yapın."
    },
    nutritionValues: {"Enerji": 39, "Protein": 0.9, "Sağlıklı Yağ": 0.3, "Demir": 0.3},
  ),
  Food(
    name: "Kayısı",
    emoji: "🍑",
    category: "Meyve",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Haşlayıp çekirdeğini çıkardıktan sonra püre halinde verin.",
      9: "Ortadan ikiye bölünmüş çekirdeksiz yumuşak kayısı parçaları.",
      12: "Minik küpler halinde muhallebilere veya yoğurtlara katarak."
    },
    nutritionValues: {"Enerji": 48, "Protein": 1.4, "Sağlıklı Yağ": 0.4, "Demir": 0.4},
  ),
  Food(name: "Erik", emoji: "🫐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Haşlayıp kabuklarını soyarak püre halinde verin.", 9: "Çekirdeksiz yumuşak tatlı mürdüm erik dilimleri.", 12: "Kurutulmuş gün kurusu erik kompostosu taneleri."}, nutritionValues: {"Enerji": 46, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.2}),
  Food(name: "Kavun", emoji: "🍈", category: "Meyve", startingMonth: 7, allergyRisk: "Düşük", presentationStyles: {6: "Püre halinde süzülmüş suyla birlikte.", 9: "Çok yumuşak parmak boyunda kavun dilimleri.", 12: "Minik küpler halinde meyve salatası olarak."}, nutritionValues: {"Enerji": 34, "Protein": 0.8, "Sağlıklı Yağ": 0.2, "Demir": 0.2}),
  Food(name: "Karpuz", emoji: "🍉", category: "Meyve", startingMonth: 7, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdeksiz suyu ezilerek kaşıkla verilebilir.", 9: "Çekirdekleri tamamen ayıklanmış yumuşak üçgen dilimler.", 12: "Kendi kendine yiyebileceği küp şeklinde çekirdeksiz karpuz."}, nutritionValues: {"Enerji": 30, "Protein": 0.6, "Sağlıklı Yağ": 0.2, "Demir": 0.2}),
  Food(name: "Böğürtlen", emoji: "🫐", category: "Meyve", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Ezilip süzgeçten geçirilmiş çekirdeksiz püre.", 9: "Çatalla ezilmiş püre, yoğurdun içine.", 12: "Bütün halinde parmak meyve olarak gözetim altında."}, nutritionValues: {"Enerji": 43, "Protein": 1.4, "Sağlıklı Yağ": 0.5, "Demir": 0.6}),
  Food(name: "Yaban Mersini", emoji: "🫐", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çatalla ezilip püre kıvamında.", 9: "Yarıya bölünmüş veya ezilmiş yaban mersini taneleri.", 12: "Bütün olarak yoğurdun içine karıştırılmış şekilde."}, nutritionValues: {"Enerji": 57, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.3}),
  Food(name: "Mango", emoji: "🥭", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Olgun mango ezilerek püre kıvamında.", 9: "Yumuşak uzun mango şerit dilimleri.", 12: "Küp şeklinde kesilmiş yoğurtlu meyve tabağı."}, nutritionValues: {"Enerji": 60, "Protein": 0.8, "Sağlıklı Yağ": 0.4, "Demir": 0.2}),
  Food(name: "Ananas", emoji: "🍍", category: "Meyve", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Pişirilip ezilmiş asidi hafifletilmiş püre.", 9: "Çok ince yumuşak halkalar halinde fırınlanmış.", 12: "Minik küpler halinde muhallebilerin içinde tatlandırıcı."}, nutritionValues: {"Enerji": 50, "Protein": 0.5, "Sağlıklı Yağ": 0.1, "Demir": 0.3}),
  Food(name: "İncir", emoji: "🫒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulmuş taze incir çatalla ezilerek.", 9: "Yumuşak taze incir dilimleri.", 12: "Suda yumuşatılmış kuru incir püresi bebek muhallebisine."}, nutritionValues: {"Enerji": 74, "Protein": 0.8, "Sağlıklı Yağ": 0.3, "Demir": 0.4}),
  Food(name: "Hurma", emoji: "🌴", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sıcak suda bekletilip kabuğu soyulmuş püre halinde.", 9: "Çorba veya muhallebilerin içine doğal tatlandırıcı püre.", 12: "Çekirdeği çıkarılmış, suda yumuşatılmış hurma parçaları."}, nutritionValues: {"Enerji": 282, "Protein": 2.5, "Sağlıklı Yağ": 0.4, "Demir": 1.0}),
  Food(name: "Mandalina", emoji: "🍊", category: "Meyve", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Çekirdeksiz ve zarsız sıkılmış taze meyve suyu.", 9: "Zarları tamamen soyulmuş çekirdeksiz mandalina dilimleri.", 12: "Zarsız minik mandalina parçacıkları yoğurdun içinde."}, nutritionValues: {"Enerji": 53, "Protein": 0.8, "Sağlıklı Yağ": 0.3, "Demir": 0.1}),
  Food(name: "Portakal", emoji: "🍊", category: "Meyve", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Asidi nedeniyle çorbalara birkaç damla sıkılarak.", 9: "Zarları soyulmuş, çekirdeksiz küçük portakal etleri.", 12: "Zarsız portakal dilimleri fırın keklerinde tatlandırıcı."}, nutritionValues: {"Enerji": 47, "Protein": 0.9, "Sağlıklı Yağ": 0.1, "Demir": 0.1}),
  Food(name: "Limon", emoji: "🍋", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çorbalara ve pürelerin kararmasını önlemek için 1-2 damla.", 9: "Balık yemeklerinin üzerine lezzet vermesi için sıkılarak.", 12: "Salata soslarında zeytinyağı ile karıştırılarak kaşıkla."}, nutritionValues: {"Enerji": 29, "Protein": 1.1, "Sağlıklı Yağ": 0.3, "Demir": 0.6}),
  Food(name: "Çilek", emoji: "🍓", category: "Meyve", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "1 yaş öncesi alerji riski nedeniyle verilmez.", 9: "1 yaş öncesi alerji riski nedeniyle önerilmez.", 12: "Rendelenmiş veya minik doğranmış taze çilek dilimleri."}, nutritionValues: {"Enerji": 32, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.4}),
  Food(name: "Kivi", emoji: "🥝", category: "Meyve", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "1 yaş öncesi yüksek asit ve alerji riski.", 9: "1 yaş öncesi önerilmez.", 12: "Siyah çekirdekli kısımları az olacak şekilde yumuşak kivi küpleri."}, nutritionValues: {"Enerji": 61, "Protein": 1.1, "Sağlıklı Yağ": 0.5, "Demir": 0.3}),
  Food(name: "Nar", emoji: "🍅", category: "Meyve", startingMonth: 12, allergyRisk: "Düşük", presentationStyles: {6: "Boğulma riski nedeniyle nar tanesi verilmez.", 9: "Sadece taze sıkılmış nar suyu birkaç kaşık.", 12: "Boğulma riski devam ettiğinden nar taneleri ezilerek suyu verilir."}, nutritionValues: {"Enerji": 83, "Protein": 1.7, "Sağlıklı Yağ": 1.2, "Demir": 0.3}),
  Food(name: "Vişne", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdeksiz haşlanmış süzülmüş vişne suyu.", 9: "Çekirdeği çıkarılmış, ezilmiş vişne taneleri muhallebide.", 12: "Çekirdeksiz vişnelerle yapılmış şekersiz bebek tartlarında."}, nutritionValues: {"Enerji": 50, "Protein": 1.0, "Sağlıklı Yağ": 0.3, "Demir": 0.3}),
  Food(name: "Kiraz", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Kabuksuz ve çekirdeksiz ezilmiş kiraz püresi.", 9: "İkiye bölünmüş çekirdeksiz etli kiraz dilimleri.", 12: "Bütün çekirdeksiz kiraz taneleri ebeveyn gözetiminde."}, nutritionValues: {"Enerji": 50, "Protein": 1.0, "Sağlıklı Yağ": 0.3, "Demir": 0.4}),
  Food(name: "Üzüm", emoji: "🍇", category: "Meyve", startingMonth: 10, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulmuş, çekirdeksiz ezilmiş üzüm suyu.", 9: "Boyuna dörde bölünmüş çekirdeksiz yumuşak üzüm parçaları.", 12: "Boyuna ikiye bölünmüş çekirdeksiz taze üzümler (BLW)."}, nutritionValues: {"Enerji": 69, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.3}),
  Food(name: "Kurutulmuş Üzüm", emoji: "🍇", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Sıcak suda bekletilip ezilmiş kuru üzüm püresi.", 9: "Keklerin ve muhallebilerin içine suda yumuşatılıp ezilerek.", 12: "Suda yumuşatılmış bütün kuru üzüm taneleri gözetim altında."}, nutritionValues: {"Enerji": 299, "Protein": 3.1, "Sağlıklı Yağ": 0.5, "Demir": 1.9}),
  Food(name: "Kuru Kayısı", emoji: "🍑", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sıcak suda yumuşatılıp püre halinde.", 9: "Minik küpler halinde kesilmiş ve suda yumuşatılmış kuru kayısı.", 12: "Kendi kendine çiğnemesi için suda haşlanmış yumuşak kuru kayısı."}, nutritionValues: {"Enerji": 241, "Protein": 3.4, "Sağlıklı Yağ": 0.5, "Demir": 2.7}),

  // --- TAHILLAR & BAKLAGİLLER (20 adet) ---
  Food(
    name: "Yulaf",
    emoji: "🌾",
    category: "Tahıl",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Yulaf ununu anne sütü veya su ile pişirerek pürüzsüz muhallebi yapın.",
      9: "Yulaf ezmesini meyve püresiyle pişirip bebek lapası şeklinde sunun.",
      12: "Yulaflı bebek kurabiyeleri veya yulaf unlu pancake yapabilirsiniz."
    },
    nutritionValues: {"Enerji": 389, "Protein": 16.9, "Sağlıklı Yağ": 6.9, "Demir": 4.7},
  ),
  Food(
    name: "Pirinç",
    emoji: "🍚",
    category: "Tahıl",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Pirinç ununu suyla pişirip ilk ek gıda tadımlarında sunun.",
      9: "Lapa şeklinde pişirilmiş pirinç pilavı taneleri sunabilirsiniz.",
      12: "Sütlaç şeklinde şekersiz bebek tatlılarında kullanabilirsiniz."
    },
    nutritionValues: {"Enerji": 365, "Protein": 7.1, "Sağlıklı Yağ": 0.7, "Demir": 0.8},
  ),
  Food(
    name: "İrmik",
    emoji: "🌾",
    category: "Tahıl",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Meyve pürelerini koyulaştırmak için irmik ekleyip pişirin.",
      9: "İrmikli bebek muhallebileri hazırlayıp üzerine pekmez ekleyin.",
      12: "Sebzeli irmikli çorbalar ve irmik unlu bebek kekleri."
    },
    nutritionValues: {"Enerji": 360, "Protein": 12.0, "Sağlıklı Yağ": 1.0, "Demir": 1.2},
  ),
  Food(
    name: "Kinoa",
    emoji: "🌾",
    category: "Tahıl",
    startingMonth: 8,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "İyice yıkanmış kinoayı haşlayıp püre çorbalarına katın.",
      9: "Haşlanmış yumuşak kinoaları sebze yemeklerine ekleyin.",
      12: "Kinoalı sebze köfteleri veya salatalar yapabilirsiniz."
    },
    nutritionValues: {"Enerji": 368, "Protein": 14.1, "Sağlıklı Yağ": 6.1, "Demir": 4.6},
  ),
  Food(name: "Kırmızı Mercimek", emoji: "🥣", category: "Tahıl", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Gaz yapmaması için kabuksuz kırmızı mercimek çorbası.", 9: "Sebzeli mercimek püresi veya çorbalar.", 12: "Mercimekli bebek köftesi (baharatsız)."}, nutritionValues: {"Enerji": 353, "Protein": 25.8, "Sağlıklı Yağ": 1.1, "Demir": 7.5}),
  Food(name: "Yeşil Mercimek", emoji: "🥣", category: "Tahıl", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlanıp kabuğu süzülmüş mercimek suyu çorbada.", 9: "Erişteli yeşil mercimek çorbası taneleri.", 12: "Haşlanmış yeşil mercimekli bebek salataları."}, nutritionValues: {"Enerji": 353, "Protein": 25.0, "Sağlıklı Yağ": 1.0, "Demir": 7.0}),
  Food(name: "Nohut", emoji: "🧆", category: "Tahıl", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Gaz yapıcı olduğundan 6. ayda önerilmez.", 9: "Haşlanmış, kabukları soyulmuş nohut taneleri ezilerek.", 12: "Ev yapımı kimyonsuz humus şeklinde ekmeğe sürülerek."}, nutritionValues: {"Enerji": 364, "Protein": 19.3, "Sağlıklı Yağ": 6.0, "Demir": 6.2}),
  Food(name: "Ruşeym", emoji: "🌾", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Gluten içerdiğinden çorbalara 1 çay kaşığı eklenerek pişirilir.", 9: "Yoğurdun içine pişirmeden 1 tatlı kaşığı karıştırılır.", 12: "Kek, kurabiye ve pancake harçlarının içine besin desteği."}, nutritionValues: {"Enerji": 360, "Protein": 23.0, "Sağlıklı Yağ": 10.0, "Demir": 6.0}),
  Food(name: "Karabuğday", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Karabuğday unundan pürüzsüz bebek muhallebisi.", 9: "Haşlanmış yumuşak karabuğday taneleri sebze çorbasında.", 12: "Karabuğdaylı bebek ekmeği veya tuzlu kekler."}, nutritionValues: {"Enerji": 343, "Protein": 13.3, "Sağlıklı Yağ": 3.4, "Demir": 2.2}),
  Food(name: "Arpa", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Arpa unlu sebze çorbaları.", 9: "Haşlanmış yumuşak arpa taneleri ezilerek püreye.", 12: "Arpa şehriyeli bebek çorbaları."}, nutritionValues: {"Enerji": 354, "Protein": 12.5, "Sağlıklı Yağ": 2.3, "Demir": 3.6}),
  Food(name: "Ruşen Pirinç", emoji: "🍚", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pirinç sübyesi şeklinde çorba kıvamlaştırma.", 9: "Sütlü pirinç unlu tatlı muhallebi.", 12: "Çorbalara eklenmiş pirinç taneleri."}, nutritionValues: {"Enerji": 360, "Protein": 7.0, "Sağlıklı Yağ": 0.6, "Demir": 0.8}),
  Food(name: "Erişte", emoji: "🍝", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Gluten ve yumurta içeriği nedeniyle 6. ayda önerilmez.", 9: "İyice haşlanmış yumuşak bebek eriştesi taneleri.", 12: "Peynirli bebek eriştesi tereyağlı sote."}, nutritionValues: {"Enerji": 370, "Protein": 12.0, "Sağlıklı Yağ": 1.5, "Demir": 1.5}),
  Food(name: "Bebek Bisküvisi", emoji: "🍪", category: "Tahıl", startingMonth: 7, allergyRisk: "Orta", presentationStyles: {6: "Ev yapımı şekersiz bisküvi ıhlamurda ezilerek.", 9: "Meyve pürelerinin içine ufalanmış ev yapımı bisküvi.", 12: "Eline bütün verilerek kendi kendine kemirmesi için (gözetimli)."}, nutritionValues: {"Enerji": 420, "Protein": 8.0, "Sağlıklı Yağ": 10.0, "Demir": 2.0}),
  Food(name: "Tam Buğday Unu", emoji: "🌾", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Gluten riski nedeniyle 6. ayda sade unlar tercih edilir.", 9: "Çorbalarda meyaneli sos bağlayıcı un olarak.", 12: "Tam buğday unlu bebek ekmeği ve pankekler."}, nutritionValues: {"Enerji": 339, "Protein": 13.2, "Sağlıklı Yağ": 2.5, "Demir": 3.8}),
  Food(name: "Mısır Unu", emoji: "🌽", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Glutensiz mısır unundan suyla pişmiş püre.", 9: "Mısır unlu bebek maması / kuymak (tuzsuz).", 12: "Balık panelemede veya mısır ekmeğinde kullanılabilir."}, nutritionValues: {"Enerji": 361, "Protein": 6.9, "Sağlıklı Yağ": 3.9, "Demir": 2.4}),
  Food(name: "Kuru Fasulye", emoji: "🥣", category: "Tahıl", startingMonth: 10, allergyRisk: "Düşük", presentationStyles: {6: "Gaz yapıcı yapısı nedeniyle verilmez.", 9: "İyice haşlanıp kabuğu soyulmuş ve ezilmiş fasulye.", 12: "Bebek usulü zeytinyağlı kuru fasulye ezmesi."}, nutritionValues: {"Enerji": 340, "Protein": 22.0, "Sağlıklı Yağ": 1.2, "Demir": 5.0}),
  Food(name: "Barbunya", emoji: "🥣", category: "Tahıl", startingMonth: 10, allergyRisk: "Düşük", presentationStyles: {6: "Yüksek gaz yapma özelliği nedeniyle verilmez.", 9: "Haşlanıp kabuğu soyulmuş çatalla ezilmiş barbunya.", 12: "Zeytinyağlı havuçlu barbunya yemeği ezilerek."}, nutritionValues: {"Enerji": 345, "Protein": 21.0, "Sağlıklı Yağ": 1.1, "Demir": 5.1}),
  Food(name: "Kuru Börülce", emoji: "🥣", category: "Tahıl", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Ağır gaz yapabileceği için verilmez.", 9: "Haşlanıp ezilmiş börülce çorbalara katılarak.", 12: "Zeytinyağlı börülce salatası ezilmiş taneler."}, nutritionValues: {"Enerji": 336, "Protein": 23.5, "Sağlıklı Yağ": 1.3, "Demir": 8.0}),
  Food(name: "Bulgur", emoji: "🌾", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Sindirimi zor ve glutenli olduğundan verilmez.", 9: "İyice pişmiş yumuşak bebek bulgur pilavı kaşıkla.", 12: "Sebzeli sulu bulgur köftesi yemekleri."}, nutritionValues: {"Enerji": 342, "Protein": 12.3, "Sağlıklı Yağ": 1.3, "Demir": 3.0}),
  Food(name: "Teff", emoji: "🌾", category: "Tahıl", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Glutensiz demir deposu un çorbalara eklenir.", 9: "Teff unlu elmalı bebek muhallebisi.", 12: "Teff unlu fırın kurabiyeleri."}, nutritionValues: {"Enerji": 367, "Protein": 13.3, "Sağlıklı Yağ": 2.4, "Demir": 7.6}),

  // --- ET & PROTEİN (15 adet) ---
  Food(
    name: "Yumurta Sarısı",
    emoji: "🥚",
    category: "Et",
    startingMonth: 7,
    allergyRisk: "Yüksek",
    presentationStyles: {
      6: "Yumurta akı kesinlikle verilmez, sarısı 8. aydan önce çok az (1/8 oranında) ezilerek başlanır.",
      9: "Katı haşlanmış yumurta sarısını anne sütü veya zeytinyağı ile ezerek mama kıvamında sunun.",
      12: "Tam haşlanmış yumurta sarısını dilimler halinde kendi kendine yemesi için tabağına koyun."
    },
    nutritionValues: {"Enerji": 322, "Protein": 16.0, "Sağlıklı Yağ": 26.0, "Demir": 5.5},
  ),
  Food(
    name: "Yumurta Akı",
    emoji: "🥚",
    category: "Et",
    startingMonth: 8,
    allergyRisk: "Yüksek",
    presentationStyles: {
      6: "6. ayda yumurta akı önerilmez; önce sarısı tek başına denenir.",
      9: "İyice pişmiş (haşlanmış/omlet) yumurta akını çok küçük parçalar halinde sunun. Alerjenler arasındadır, 3 gün kuralını uygulayın.",
      12: "Tam pişmiş yumurta akını dilimler halinde parmak gıda olarak verebilirsiniz."
    },
    nutritionValues: {"Enerji": 52, "Protein": 10.9, "Sağlıklı Yağ": 0.2, "Demir": 0.1},
  ),
  Food(
    name: "Haşlanmış Yumurta",
    emoji: "🥚",
    category: "Et",
    startingMonth: 8,
    allergyRisk: "Yüksek",
    presentationStyles: {
      6: "6. ayda tam yumurta yerine önce sarısı ayrı denenir.",
      9: "İyice haşlanmış (katı) tam yumurtayı ezerek veya küçük parçalar halinde sunun. Yumurta yaygın bir alerjendir.",
      12: "Katı haşlanmış yumurtayı dilimler/dörtgenler halinde kendi kendine yemesi için verin."
    },
    nutritionValues: {"Enerji": 155, "Protein": 12.6, "Sağlıklı Yağ": 10.6, "Demir": 1.2},
  ),
  Food(
    name: "Tavuk Göğsü",
    emoji: "🍗",
    category: "Et",
    startingMonth: 8,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Haşlanmış tavuk göğsünü sebze pürelerinin içine blenderdan geçirerek ekleyin.",
      9: "Didiklenmiş çok küçük, yumuşak tavuk parçalarını eline verebilirsiniz.",
      12: "Bebek köftesinin içine tavuk kıyması katarak fırında pişirebilirsiniz."
    },
    nutritionValues: {"Enerji": 120, "Protein": 22.5, "Sağlıklı Yağ": 2.6, "Demir": 0.7},
  ),
  Food(
    name: "Dana Kıyma",
    emoji: "🥩",
    category: "Et",
    startingMonth: 7,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Çift çekim dana kıymayı sebze yemeklerinin içinde iyice pişirip ezin.",
      9: "Baharat içermeyen yumuşak bebek köftesi şeklinde fırınlayıp verin.",
      12: "Kıymalı makarna sosu veya kıymalı sebze dolması taneleri."
    },
    nutritionValues: {"Enerji": 250, "Protein": 18.0, "Sağlıklı Yağ": 19.0, "Demir": 2.1},
  ),
  Food(
    name: "Yoğurt",
    emoji: "🥛",
    category: "Et",
    startingMonth: 6,
    allergyRisk: "Orta",
    presentationStyles: {
      6: "Ev mayalanmış taze bebek yoğurdunu kaşık kaşık tek başına sunun.",
      9: "Meyve pürelerinin üzerine ekleyerek veya cacık kıvamında sunabilirsiniz.",
      12: "Süzme yoğurt şeklinde bebek ekmeklerinin üzerine sürerek verin."
    },
    nutritionValues: {"Enerji": 61, "Protein": 3.5, "Sağlıklı Yağ": 3.3, "Demir": 0.1},
  ),
  Food(
    name: "Labne",
    emoji: "🧀",
    category: "Et",
    startingMonth: 6,
    allergyRisk: "Orta",
    presentationStyles: {
      6: "Tuzu alınmış ev yapımı labne peynirini pürelerle karıştırın.",
      9: "Bebek ekmeğinin üzerine sürülmüş labne peyniri dilimi.",
      12: "Sebze diyetlerine sos olarak ekleyebilirsiniz."
    },
    nutritionValues: {"Enerji": 200, "Protein": 6.0, "Sağlıklı Yağ": 18.0, "Demir": 0.2},
  ),
  Food(name: "Lor Peyniri", emoji: "🧀", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Tuzsuz ev yapımı lor peyniri çorba veya püreye karıştırılarak.", 9: "Omletlerin ve krep harçlarının içine eklenerek pişirilir.", 12: "Kahvaltı tabağında zeytinyağı ile ezilmiş lor peyniri."}, nutritionValues: {"Enerji": 100, "Protein": 11.0, "Sağlıklı Yağ": 4.5, "Demir": 0.2}),
  Food(name: "Kuzu Eti", emoji: "🥩", category: "Et", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Haşlanmış kuzu eti sebze püresiyle blender yapılarak.", 9: "İyice pişmiş fırın kuzu eti didiklenmiş halde yumuşak.", 12: "Kuzu kıymalı sebzeli sulu bebek yemekleri."}, nutritionValues: {"Enerji": 200, "Protein": 20.0, "Sağlıklı Yağ": 13.0, "Demir": 1.8}),
  Food(name: "Hindi Göğsü", emoji: "🦃", category: "Et", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Buharda pişip püre haline getirilmiş hindi eti sebzelerle.", 9: "Ufak didilmiş haşlama hindi göğsü taneleri.", 12: "Hindi kıymalı fırın köfteleri."}, nutritionValues: {"Enerji": 110, "Protein": 23.0, "Sağlıklı Yağ": 1.5, "Demir": 1.0}),
  Food(name: "Dana İlikli Kemik Suyu", emoji: "🥣", category: "Et", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Tüm sebze pürelerine ve çorbalara 1-2 yemek kaşığı katılarak.", 9: "Bebek muhallebi ve çorbalarının pişirme suyu olarak.", 12: "Pilav ve eriştelerin haşlama suyuna eklenerek."}, nutritionValues: {"Enerji": 40, "Protein": 8.0, "Sağlıklı Yağ": 1.0, "Demir": 0.5}),
  Food(name: "Tuzsuz Keçi Peyniri", emoji: "🧀", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Tuzu iyice alınmış peynir pürelerin içinde ezilerek.", 9: "Minik küpler halinde kahvaltı tabağında.", 12: "Keçi peynirli bebek poğaçaları."}, nutritionValues: {"Enerji": 260, "Protein": 18.0, "Sağlıklı Yağ": 21.0, "Demir": 1.5}),
  Food(name: "Kefir", emoji: "🥛", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Sindirimi ağır gelebileceği için 6. ayda kaşıkla önerilmez.", 9: "Bebek bardağı ile günde 2-3 tatlı kaşığı başlanarak.", 12: "Meyve püreleriyle karıştırılmış meyveli kefir içeceği."}, nutritionValues: {"Enerji": 55, "Protein": 3.2, "Sağlıklı Yağ": 3.0, "Demir": 0.1}),
  Food(name: "Kuzu Karaciğeri", emoji: "🥩", category: "Et", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Ağır metal riski ve yoğun vitamin nedeniyle verilmez.", 9: "Haftada en fazla 1 kez haşlanmış ezilmiş karaciğer (fındık büyüklüğünde).", 12: "İyice pişmiş rendelenmiş kuzu ciğeri çorbaların içinde."}, nutritionValues: {"Enerji": 140, "Protein": 21.0, "Sağlıklı Yağ": 5.0, "Demir": 6.4}),
  Food(name: "Bıldırcın Yumurtası", emoji: "🥚", category: "Et", startingMonth: 10, allergyRisk: "Yüksek", presentationStyles: {6: "Ağır protein yükü nedeniyle 6. ayda verilmez.", 9: "Sadece haşlanmış sarısı 1/4 oranında ezilerek.", 12: "Tam haşlanmış bıldırcın yumurtası sarısı tereyağında ezilmiş."}, nutritionValues: {"Enerji": 158, "Protein": 13.0, "Sağlıklı Yağ": 11.0, "Demir": 3.7}),
  Food(name: "Süzme Peynir", emoji: "🧀", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Tuzu tamamen arındırılmış peynir püreye ezilerek.", 9: "Yumuşak şeritler halinde BLW kahvaltı tabağında.", 12: "Domatesli peynirli bebek makarnası sosunda."}, nutritionValues: {"Enerji": 220, "Protein": 12.0, "Sağlıklı Yağ": 18.0, "Demir": 0.5}),
  Food(name: "Tereyağı", emoji: "🧈", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Çorba ve pürelerin içine piştikten sonra 1 çay kaşığı eklenir.", 9: "Bebek omletlerini pişirirken tavayı yağlamak için kullanılır.", 12: "Bebek makarnaları ve pilavlarına lezzet verici sos olarak."}, nutritionValues: {"Enerji": 717, "Protein": 0.9, "Sağlıklı Yağ": 81.0, "Demir": 0.0}),

  // --- BALIK & DENİZ ÜRÜNLERİ (10 adet) ---
  Food(
    name: "Somon",
    emoji: "🐟",
    category: "Balık",
    startingMonth: 8,
    allergyRisk: "Orta",
    presentationStyles: {
      6: "Balık alerji riski taşır, 8. aydan önce püre olarak verilmesi önerilmez.",
      9: "Fırınlanmış kılçıksız somon etini çatalla ezerek sebze püresiyle karıştırın.",
      12: "Kılçıkları tamamen temizlenmiş ızgara somon parçalarını eline verin."
    },
    nutritionValues: {"Enerji": 208, "Protein": 20.0, "Sağlıklı Yağ": 13.0, "Demir": 0.3},
  ),
  Food(name: "Mezgit", emoji: "🐟", category: "Balık", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Alerji riski nedeniyle 6. ayda önerilmez.", 9: "Buharda pişmiş kılçıksız beyaz mezgit eti ezilerek sebzelerle.", 12: "Kılçıksız mezgit çorbası sebzeli."}, nutritionValues: {"Enerji": 82, "Protein": 18.0, "Sağlıklı Yağ": 0.7, "Demir": 0.4}),
  Food(name: "Levrek", emoji: "🐟", category: "Balık", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Alerjen grupta yer aldığından tadımlarda verilmez.", 9: "Fırında pişmiş kılçıksız levrek eti didiklenmiş.", 12: "Levrekli bebek çorbası dereotlu."}, nutritionValues: {"Enerji": 97, "Protein": 18.4, "Sağlıklı Yağ": 2.0, "Demir": 0.3}),
  Food(name: "Çipura", emoji: "🐟", category: "Balık", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Erken aylarda balık çeşitleri önerilmez.", 9: "Izgara veya fırın kılçıksız çipura et parçaları sote sebzeyle.", 12: "Çipura köftesi (kılçıksız unlu fırın)."}, nutritionValues: {"Enerji": 96, "Protein": 19.0, "Sağlıklı Yağ": 1.9, "Demir": 0.4}),
  Food(name: "Sardalya", emoji: "🐟", category: "Balık", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Ağır kokusu ve tuzu nedeniyle verilmez.", 9: "Kılçıksız temizlenmiş taze sardalya buğulaması ezilerek.", 12: "Kılçıksız taze fırınlanmış sardalya parmak gıda."}, nutritionValues: {"Enerji": 208, "Protein": 25.0, "Sağlıklı Yağ": 11.0, "Demir": 2.9}),
  Food(name: "Dil Balığı", emoji: "🐟", category: "Balık", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "İlk gıda döneminde balık tercih edilmez.", 9: "Buharda pişmiş çok yumuşak kılçıksız dil balığı filetoları.", 12: "Dil balığı çorbası tereyağlı patatesli."}, nutritionValues: {"Enerji": 91, "Protein": 18.8, "Sağlıklı Yağ": 1.2, "Demir": 0.3}),
  Food(name: "Hamsi", emoji: "🐟", category: "Balık", startingMonth: 10, allergyRisk: "Orta", presentationStyles: {6: "Kılçık temizleme zorluğu ve ağır yapısı nedeniyle önerilmez.", 9: "Kılçığı, kafası, siyah eti tamamen ayıklanmış buğulama hamsi.", 12: "Fırınlanmış kılçıksız mısır unlu bebek hamsi (tuzsuz)."}, nutritionValues: {"Enerji": 131, "Protein": 20.0, "Sağlıklı Yağ": 4.8, "Demir": 3.2}),
  Food(name: "Lüfer", emoji: "🐟", category: "Balık", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Dip balığı/büyük balık kategorisinde ağır metal riski.", 9: "Çok temiz kılçıksız ızgara lüfer eti küçük lokmalar halinde.", 12: "Kılçıksız lüfer püresi patatesle karıştırılıp fırın."}, nutritionValues: {"Enerji": 117, "Protein": 21.0, "Sağlıklı Yağ": 3.0, "Demir": 0.4}),
  Food(name: "Alabalık", emoji: "🐟", category: "Balık", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Tatlı su balıkları da alerji riski taşır.", 9: "Fırın kılçıksız alabalık didiklenerek sebzelere eklenir.", 12: "Alabalıklı bebek eriştesi zeytinyağlı."}, nutritionValues: {"Enerji": 148, "Protein": 20.8, "Sağlıklı Yağ": 6.6, "Demir": 1.5}),
  Food(name: "Kalkan Balığı", emoji: "🐟", category: "Balık", startingMonth: 12, allergyRisk: "Orta", presentationStyles: {6: "1 yaş öncesi dip balığı cıva riski nedeniyle verilmez.", 9: "1 yaş öncesi önerilmez.", 12: "Kılçığı tamamen temizlenmiş çok az fırın kalkan eti."}, nutritionValues: {"Enerji": 95, "Protein": 16.0, "Sağlıklı Yağ": 3.0, "Demir": 0.8}),

  // --- DİĞER / SAĞLIKLI YAĞLAR & KURU YEMİŞ (20 adet) ---
  Food(
    name: "Zeytinyağı",
    emoji: "🫒",
    category: "Diğer",
    startingMonth: 6,
    allergyRisk: "Düşük",
    presentationStyles: {
      6: "Tüm sebze pürelerine piştikten sonra kabızlığı önlemek için 1 tatlı kaşığı ekleyin.",
      9: "Bebek yemeklerini hazırlarken soğuk sıkım sızma zeytinyağı tercih edin.",
      12: "Salata soslarında ve krep harçlarında güvenle kullanabilirsiniz."
    },
    nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.6},
  ),
  Food(name: "Pekmez", emoji: "🍯", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Yoğun şeker yükü nedeniyle 6. ayda verilmesi önerilmez.", 9: "Muhallebilerin üzerine ocaktan indirildikten sonra 1 tatlı kaşığı ekleyin (kaynatılmamalıdır).", 12: "Pancake ve kurabiyelerde doğal tatlandırıcı olarak harca katın."}, nutritionValues: {"Enerji": 290, "Protein": 0.0, "Sağlıklı Yağ": 0.0, "Demir": 4.7}),
  Food(name: "Ceviz", emoji: "🫘", category: "Diğer", startingMonth: 8, allergyRisk: "Yüksek", presentationStyles: {6: "Boğulma riski nedeniyle bütün kuruyemişler yasaktır.", 9: "Un gibi öğütülmüş 1 çay kaşığı cevizi muhallebiye ekleyin.", 12: "İnce kıyılmış ceviz parçacıklarını bebek keklerinin içinde sunabilirsiniz."}, nutritionValues: {"Enerji": 654, "Protein": 15.2, "Sağlıklı Yağ": 65.2, "Demir": 2.9}),
  Food(name: "Badem", emoji: "🫘", category: "Diğer", startingMonth: 9, allergyRisk: "Yüksek", presentationStyles: {6: "Boğulma riski vardır, verilmez.", 9: "Un haline getirilmiş 1 çay kaşığı bademi mamalara ekleyin.", 12: "Çorbalara kıvam vermesi için badem unu ekleyip pişirin."}, nutritionValues: {"Enerji": 579, "Protein": 21.2, "Sağlıklı Yağ": 49.9, "Demir": 3.7}),
  Food(name: "Fındık", emoji: "🫘", category: "Diğer", startingMonth: 9, allergyRisk: "Yüksek", presentationStyles: {6: "Alerji ve boğulma riski taşır.", 9: "Ev yapımı şekersiz fındık ezmesini (pürüzsüz) ekmeğe sürün.", 12: "Öğütülmüş fındık tozunu bebek pancake harcına katın."}, nutritionValues: {"Enerji": 628, "Protein": 15.0, "Sağlıklı Yağ": 60.8, "Demir": 4.7}),
  Food(name: "Tahin", emoji: "🍯", category: "Diğer", startingMonth: 10, allergyRisk: "Yüksek", presentationStyles: {6: "Alerjen susam içeriği nedeniyle önerilmez.", 9: "Çorba ve muhallebilere 1 çay kaşığı katılarak alerji testi yapılır.", 12: "Pekmezle karıştırılmış tahin sosunu pankeklerin üzerine sürün."}, nutritionValues: {"Enerji": 595, "Protein": 17.0, "Sağlıklı Yağ": 53.0, "Demir": 9.0}),
  Food(name: "Avokado Yağı", emoji: "🥑", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pürelerin üzerine piştikten sonra yarım çay kaşığı.", 9: "Sebze sotelerinde sağlıklı yağ desteği.", 12: "Bebek salatalarında sos malzemesi."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}),
  Food(name: "Hindistan Cevizi Yağı", emoji: "🥥", category: "Diğer", startingMonth: 7, allergyRisk: "Düşük", presentationStyles: {6: "Bebek mamalarına tat vermesi için piştikten sonra çeyrek çay kaşığı.", 9: "Bebek kek ve kurabiyelerinde tereyağı alternatifi yağ.", 12: "Sütlü şekersiz bebek tatlılarında aroma verici."}, nutritionValues: {"Enerji": 862, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}),
  Food(name: "Keçiboynuzu Unu", emoji: "🌾", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Muhallebileri tatlandırmak için pişen süte eklenir.", 9: "Kakao yerine bebek pudinglerinde doğal tatlandırıcı toz.", 12: "Bebek kurabiye harçlarında kakaosuz çikolata aroması için."}, nutritionValues: {"Enerji": 222, "Protein": 4.6, "Sağlıklı Yağ": 0.7, "Demir": 2.9}),
  Food(name: "Keçiboynuzu Özü", emoji: "🍯", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Ağır şeker içeriği nedeniyle 6. ayda verilmez.", 9: "Pişmeyen meyveli yoğurtların üzerine 1 çay kaşığı sızdırılarak.", 12: "Bebek pankeklerinin içine doğal şurup olarak eklenir."}, nutritionValues: {"Enerji": 300, "Protein": 1.0, "Sağlıklı Yağ": 0.1, "Demir": 4.5}),
  Food(name: "Kuru İncir", emoji: "🫒", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sıcak suda bekletilip kabuğu soyulmuş kuru incir püresi.", 9: "Bebek keklerinin içine minik küpler halinde suda yumuşatılmış.", 12: "Bütün olarak suda haşlanmış yumuşak kuru incir parçaları."}, nutritionValues: {"Enerji": 249, "Protein": 3.3, "Sağlıklı Yağ": 0.9, "Demir": 2.0}),
  Food(name: "Kuru Erik", emoji: "🫐", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kabızlık önleyici olarak sıcak suda haşlanıp ezilmiş püresi.", 9: "Mamalara tat ve kıvam vermesi için kuru erik sosu.", 12: "Yumuşak kuru erik parçaları gözetim altında yedirilerek."}, nutritionValues: {"Enerji": 240, "Protein": 2.2, "Sağlıklı Yağ": 0.4, "Demir": 0.9}),
  Food(name: "Kuru Dut", emoji: "🌾", category: "Diğer", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Boğulma riski nedeniyle tanesi verilmez.", 9: "Kuru dutlar rondodan geçirilip toz tatlandırıcı olarak un yerine.", 12: "Suda yumuşatılmış kuru dut taneleri ezilmiş şekilde yoğurda."}, nutritionValues: {"Enerji": 300, "Protein": 2.5, "Sağlıklı Yağ": 1.0, "Demir": 9.0}),
  Food(name: "Çam Fıstığı", emoji: "🫘", category: "Diğer", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "1 yaş öncesi verilmez.", 9: "1 yaş öncesi önerilmez.", 12: "Öğütülmüş toz halinde ev yapımı bebek pestolarının içinde."}, nutritionValues: {"Enerji": 673, "Protein": 13.7, "Sağlıklı Yağ": 68.4, "Demir": 5.5}),
  Food(name: "Chia Tohumu", emoji: "🧉", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Şişme özelliği nedeniyle sıvı pürelerde 6. ayda önerilmez.", 9: "Süt veya meyve suyuyla jelleleştirilmiş chia pudingi.", 12: "Yoğurt veya pürelerin içine pişirmeden yarım çay kaşığı."}, nutritionValues: {"Enerji": 486, "Protein": 16.5, "Sağlıklı Yağ": 30.7, "Demir": 7.7}),
  Food(name: "Keten Tohumu", emoji: "🧉", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sindirimi zor olduğundan erken aylarda verilmez.", 9: "Taze öğütülmüş keten tohumu çorbalara 1/4 çay kaşığı eklenir.", 12: "Bebek ekmeklerinin hamur hamur harcına öğütülmüş olarak eklenir."}, nutritionValues: {"Enerji": 534, "Protein": 18.3, "Sağlıklı Yağ": 42.2, "Demir": 5.7}),
  Food(name: "Kabak Çekirdeği İçi", emoji: "🫘", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Bütün verilmesi çok tehlikelidir.", 9: "Un gibi öğütülmüş 1 çay kaşığı kabak çekirdeği çorbalara.", 12: "Toz halinde sebzeli bebek pürelerinin üzerine serpilir."}, nutritionValues: {"Enerji": 559, "Protein": 30.2, "Sağlıklı Yağ": 49.0, "Demir": 8.8}),
  Food(name: "Ruşeymli İrmik", emoji: "🌾", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Gluten hassasiyeti nedeniyle 6. ayda sade irmik tercih edilir.", 9: "Muhallebileri pişirirken ruşeymli irmik kullanarak demir desteği.", 12: "Sebze çorbalarının içine 1 tatlı kaşığı ekleyip pişirerek."}, nutritionValues: {"Enerji": 362, "Protein": 14.5, "Sağlıklı Yağ": 2.5, "Demir": 3.0}),
  Food(name: "Susam", emoji: "🧉", category: "Diğer", startingMonth: 10, allergyRisk: "Yüksek", presentationStyles: {6: "Alerji riski yüksektir, verilmez.", 9: "Toz haline getirilmiş çok az susam ev yapımı krakerlerde.", 12: "Bebek simitlerinin üzerine serpilmiş sote susam taneleri."}, nutritionValues: {"Enerji": 573, "Protein": 17.7, "Sağlıklı Yağ": 49.7, "Demir": 14.6}),
  Food(name: "Ihlamur Çayı", emoji: "🍵", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bebek bisküvisini ıslatmak veya kabızlıkta 1-2 tatlı kaşığı ılık çay.", 9: "Kahvaltılarda içecek olarak 2-3 yemek kaşığı ılık ıhlamur.", 12: "Şekersiz ev yapımı bitki çayları bebek bardağında."}, nutritionValues: {"Enerji": 1, "Protein": 0.0, "Sağlıklı Yağ": 0.0, "Demir": 0.0}),

  // ===== Parti 1: Solid Starts tarzı genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Ahududu", emoji: "🍇", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yumuşak, ezilebilir; ezilmiş püre halinde.", 9: "Bütün taneler parmak gıdası olarak.", 12: "Yoğurt veya yulafa karıştırılmış bütün taneler."}, nutritionValues: {"Enerji": 52, "Protein": 1.2, "Sağlıklı Yağ": 0.7, "Demir": 0.7}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve ezilebilir; düşük risk.", needsReview: true),
  Food(name: "Greyfurt", emoji: "🍊", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Asitli; 8 aydan önce önerilmez.", 9: "Zarları ve çekirdekleri ayıklanıp küçük parçalar.", 12: "Zarsız bölümler küçük doğranmış olarak."}, nutritionValues: {"Enerji": 42, "Protein": 0.8, "Sağlıklı Yağ": 0.1, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Zar ve çekirdekler ayıklanır; küçük parçalara bölünür.", needsReview: true),
  Food(name: "Nektarin", emoji: "🍑", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulup çekirdeği çıkarılır; püre.", 9: "Yumuşak, soyulmuş ince dilimler.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 44, "Protein": 1.1, "Sağlıklı Yağ": 0.3, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çekirdek çıkarılır; sert/ham olanı pişirilir.", needsReview: true),
  Food(name: "Ayva", emoji: "🍐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ serttir; pişirilip püre/komposto.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 57, "Protein": 0.4, "Sağlıklı Yağ": 0.1, "Demir": 0.7}, chokingRisk: "Orta", chokingNote: "Çiğ sert olduğundan pişirilerek yumuşatılır.", needsReview: true),
  Food(name: "Trabzon Hurması", emoji: "🍊", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok olgun ve yumuşak olanı; kabuk ve çekirdek ayıklanıp püre.", 9: "Yumuşak ince dilimler.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 70, "Protein": 0.6, "Sağlıklı Yağ": 0.2, "Demir": 0.2}, chokingRisk: "Orta", chokingNote: "Sadece tam olgun/yumuşak olanı; sert olanı verilmez.", needsReview: true),
  Food(name: "Papaya", emoji: "🍈", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; çekirdekleri ayıklanıp püre.", 9: "Çubuk şeklinde parmak gıdası.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 43, "Protein": 0.5, "Sağlıklı Yağ": 0.3, "Demir": 0.3}, chokingRisk: "Düşük", chokingNote: "Olgun ve yumuşak; düşük risk.", needsReview: true),
  Food(name: "Hindistan Cevizi", emoji: "🥥", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sert; bütün parça verilmez.", 9: "Taze iç rendelenip yemeğe karıştırılır.", 12: "İnce rendelenmiş olarak."}, nutritionValues: {"Enerji": 354, "Protein": 3.3, "Sağlıklı Yağ": 33.0, "Demir": 2.4}, chokingRisk: "Yüksek", chokingNote: "Sert iç bütün/parça VERİLMEZ; ince rendelenir.", needsReview: true),
  Food(name: "Kestane", emoji: "🌰", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Bütün/yarım verilmez.", 9: "Haşlanıp püre haline getirilir.", 12: "İyice ezilmiş püre olarak."}, nutritionValues: {"Enerji": 196, "Protein": 1.6, "Sağlıklı Yağ": 1.3, "Demir": 0.9}, chokingRisk: "Yüksek", chokingNote: "Sert; yalnızca haşlanıp püre — bütün/parça VERİLMEZ.", needsReview: true),
  Food(name: "Kızılcık", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdekli ve sert; verilmez.", 9: "Çekirdeği çıkarılıp pişirilerek ezilir.", 12: "Çekirdeksiz, çeyreklenmiş olarak."}, nutritionValues: {"Enerji": 46, "Protein": 0.4, "Sağlıklı Yağ": 0.1, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Çekirdeği çıkarılır; yuvarlak/sert tane çeyreklenir.", needsReview: true),
  Food(name: "Çarkıfelek Meyvesi", emoji: "🍈", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İç jel/püre; sert çekirdekler ezilir.", 9: "Yoğurda karıştırılmış iç kısım.", 12: "Kaşıkla iç kısmı."}, nutritionValues: {"Enerji": 97, "Protein": 2.2, "Sağlıklı Yağ": 0.7, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "Sert çekirdekler ezilir/ayıklanır.", needsReview: true),
  // Sebzeler
  Food(name: "Patlıcan", emoji: "🍆", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulup pişirilir; püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Közlenmiş/pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 25, "Protein": 1.0, "Sağlıklı Yağ": 0.2, "Demir": 0.2}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Salatalık", emoji: "🥒", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Soyulmuş kalın çubuk (diş kaşıma).", 9: "Soyulmuş küçük parçalar.", 12: "Küçük doğranmış olarak."}, nutritionValues: {"Enerji": 15, "Protein": 0.7, "Sağlıklı Yağ": 0.1, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Soyulur; yuvarlak dilim verilmez, çubuk/küçük parça.", needsReview: true),
  Food(name: "Yeşil Biber", emoji: "🫑", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu soyulup iyice pişirilir; püre.", 9: "Pişmiş ince şeritler.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 20, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Kabuğu soyulur veya iyice pişirilir.", needsReview: true),
  Food(name: "Lahana", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip yumuşatılır; ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 25, "Protein": 1.3, "Sağlıklı Yağ": 0.1, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Brüksel Lahanası", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip ezilir.", 9: "Pişmiş, dörde bölünmüş.", 12: "Pişmiş çeyrekler."}, nutritionValues: {"Enerji": 43, "Protein": 3.4, "Sağlıklı Yağ": 0.3, "Demir": 1.4}, chokingRisk: "Orta", chokingNote: "Bütün top verilmez; pişirilip çeyreklenir.", needsReview: true),
  Food(name: "Marul", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce şeritler."}, nutritionValues: {"Enerji": 15, "Protein": 1.4, "Sağlıklı Yağ": 0.2, "Demir": 0.9}, chokingRisk: "Orta", chokingNote: "Çiğ yaprak ince kıyılır.", needsReview: true),
  Food(name: "Turp", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ serttir; önerilmez.", 9: "Rendelenir veya pişirilip yumuşatılır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 16, "Protein": 0.7, "Sağlıklı Yağ": 0.1, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çiğ sert; rendelenir/pişirilir.", needsReview: true),
  Food(name: "Mantar", emoji: "🍄", category: "Sebze", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 22, "Protein": 3.1, "Sağlıklı Yağ": 0.3, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Çiğ verilmez; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Rezene", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip yumuşatılır; püre.", 9: "Pişmiş ince dilimler.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 1.2, "Sağlıklı Yağ": 0.2, "Demir": 0.7}, chokingRisk: "Orta", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Taze Soğan", emoji: "🧅", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Yeşil kısmı ince kıyılıp pişirilir.", 12: "İnce kıyılmış olarak yemekte."}, nutritionValues: {"Enerji": 32, "Protein": 1.8, "Sağlıklı Yağ": 0.2, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "İnce kıyılıp pişirilerek yemeğe karıştırılır.", needsReview: true),
  Food(name: "Semizotu", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yıkanıp pişirilir; ezilir.", 9: "Pişmiş, ince kıyılmış.", 12: "Zeytinyağlı yemekte ince kıyılmış."}, nutritionValues: {"Enerji": 20, "Protein": 2.0, "Sağlıklı Yağ": 0.4, "Demir": 2.0}, chokingRisk: "Düşük", chokingNote: "Pişirilip ince kıyılır.", needsReview: true),
  Food(name: "Mısır", emoji: "🌽", category: "Sebze", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Bütün tane ve koçan verilmez.", 9: "Taneler ezilip püre.", 12: "İyice ezilmiş taneler."}, nutritionValues: {"Enerji": 86, "Protein": 3.2, "Sağlıklı Yağ": 1.2, "Demir": 0.5}, chokingRisk: "Yüksek", chokingNote: "Bütün tane/koçan VERİLMEZ; taneler ezilir.", needsReview: true),
  // Et / Balık / Protein
  Food(name: "Tavuk But", emoji: "🍗", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kemiksiz, iyi pişmiş; lif lif didiklenir/püre.", 9: "Suyuyla yumuşatılmış didik parçalar.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 209, "Protein": 26.0, "Sağlıklı Yağ": 10.9, "Demir": 1.3}, chokingRisk: "Orta", chokingNote: "Kemiksiz; lif lif didiklenir, kuru kalmasın diye suyuyla.", needsReview: true),
  Food(name: "Hindi But", emoji: "🍗", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kemiksiz, iyi pişmiş; didiklenir/püre.", 9: "Suyuyla yumuşatılmış didik parçalar.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 170, "Protein": 28.0, "Sağlıklı Yağ": 6.0, "Demir": 1.4}, chokingRisk: "Orta", chokingNote: "Kemiksiz; didiklenir, suyuyla nemli verilir.", needsReview: true),
  Food(name: "Ton Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir; az ve seyrek.", 9: "Ezilmiş, sebzeyle karıştırılmış.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 132, "Protein": 28.0, "Sağlıklı Yağ": 1.0, "Demir": 1.3}, chokingRisk: "Orta", chokingNote: "Cıva nedeniyle az/seyrek; kılçık ayıklanır.", needsReview: true),
  Food(name: "Uskumru", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçıkları dikkatle ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 205, "Protein": 19.0, "Sağlıklı Yağ": 13.9, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "Tüm kılçıklar dikkatle ayıklanır.", needsReview: true),
  Food(name: "Karides", emoji: "🦐", category: "Balık", startingMonth: 24, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip çok ince doğranır (alerjen).", 12: "İnce doğranmış olarak."}, nutritionValues: {"Enerji": 99, "Protein": 24.0, "Sağlıklı Yağ": 0.3, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Alerjen; iyice pişirilip çok ince doğranır.", needsReview: true),
  Food(name: "Yer Fıstığı", emoji: "🥜", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Sulandırılmış yer fıstığı ezmesi (erken tanıştırma).", 9: "Yoğurda/pürelere karıştırılmış ezme.", 12: "İnce sürülmüş ezme; bütün fıstık verilmez."}, nutritionValues: {"Enerji": 567, "Protein": 25.8, "Sağlıklı Yağ": 49.2, "Demir": 4.6}, chokingRisk: "Yüksek", chokingNote: "Bütün/parça ASLA — yalnız sulandırılmış ezme.", needsReview: true),
  Food(name: "Antep Fıstığı", emoji: "🥜", category: "Diğer", startingMonth: 8, allergyRisk: "Yüksek", presentationStyles: {6: "Bütün verilmez.", 9: "Toz/ezme olarak çok az.", 12: "İnce ezme olarak."}, nutritionValues: {"Enerji": 560, "Protein": 20.0, "Sağlıklı Yağ": 45.0, "Demir": 3.9}, chokingRisk: "Yüksek", chokingNote: "Bütün VERİLMEZ; toz/ezme.", needsReview: true),
  Food(name: "Kaju", emoji: "🥜", category: "Diğer", startingMonth: 8, allergyRisk: "Yüksek", presentationStyles: {6: "Bütün verilmez.", 9: "Ezme/toz olarak çok az.", 12: "İnce ezme olarak."}, nutritionValues: {"Enerji": 553, "Protein": 18.0, "Sağlıklı Yağ": 44.0, "Demir": 6.7}, chokingRisk: "Yüksek", chokingNote: "Bütün VERİLMEZ; ezme/toz.", needsReview: true),
  Food(name: "Beyaz Peynir", emoji: "🧀", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzsuz/az tuzlu; küçük yumuşak parçalar.", 12: "Küçük doğranmış olarak."}, nutritionValues: {"Enerji": 264, "Protein": 18.0, "Sağlıklı Yağ": 21.0, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Tuzu azaltmak için ılık suda bekletilir; küçük parça.", needsReview: true),
  Food(name: "Kaşar Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Rendelenir veya ince çubuk.", 12: "İnce çubuk/küçük parça."}, nutritionValues: {"Enerji": 350, "Protein": 25.0, "Sağlıklı Yağ": 27.0, "Demir": 0.7}, chokingRisk: "Orta", chokingNote: "Rendelenir; tuz içeriğine dikkat.", needsReview: true),
  // Tahıllar
  Food(name: "Makarna", emoji: "🍝", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Yumuşak haşlanmış büyük makarna parmak gıdası.", 9: "Küçük doğranmış/ezilmiş.", 12: "Sosla karıştırılmış küçük parçalar."}, nutritionValues: {"Enerji": 158, "Protein": 5.8, "Sağlıklı Yağ": 0.9, "Demir": 1.3}, chokingRisk: "Orta", chokingNote: "Çok yumuşak haşlanır; küçük şehriye püre.", needsReview: true),
  Food(name: "Ekmek", emoji: "🍞", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Hafif kızartılmış (tost) ince dilim.", 9: "Üzerine ince ezme sürülmüş tost.", 12: "Küçük lokmalar."}, nutritionValues: {"Enerji": 265, "Protein": 9.0, "Sağlıklı Yağ": 3.2, "Demir": 3.6}, chokingRisk: "Orta", chokingNote: "Taze yumuşak ekmek topaklanır; hafif bayat/tost verilir.", needsReview: true),
  Food(name: "Darı", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip lapa.", 9: "Yumuşak lapa, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 378, "Protein": 11.0, "Sağlıklı Yağ": 4.2, "Demir": 3.0}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Kuskus", emoji: "🌾", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Yumuşak pişirilip yemeğe karıştırılır.", 12: "Sebzeli olarak."}, nutritionValues: {"Enerji": 112, "Protein": 3.8, "Sağlıklı Yağ": 0.2, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Yumuşak pişirilir; topaklanmaması için suyuyla.", needsReview: true),
  Food(name: "Şehriye", emoji: "🍜", category: "Tahıl", startingMonth: 7, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Çorbada yumuşayana kadar pişirilir.", 12: "Sebzeli pilav içinde."}, nutritionValues: {"Enerji": 160, "Protein": 5.4, "Sağlıklı Yağ": 0.6, "Demir": 1.2}, chokingRisk: "Düşük", chokingNote: "İyice yumuşayana kadar pişirilir.", needsReview: true),
  // Otlar / Baharatlar
  Food(name: "Fesleğen", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Taze, çok az ince kıyılıp yemeğe.", 9: "Sebze/makarnaya kıyılmış.", 12: "Sos ve yemeklerde aroma."}, nutritionValues: {"Enerji": 23, "Protein": 3.2, "Sağlıklı Yağ": 0.6, "Demir": 3.2}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır; az miktar.", needsReview: true),
  Food(name: "Nane", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok az ince kıyılıp yoğurda/yemeğe.", 9: "Cacık/çorbada az miktar.", 12: "Yemeklerde aroma."}, nutritionValues: {"Enerji": 70, "Protein": 3.8, "Sağlıklı Yağ": 0.9, "Demir": 5.1}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır; az miktar.", needsReview: true),
  Food(name: "Kekik", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok az, ufalanmış olarak yemeğe.", 9: "Sebze/et yemeklerinde az.", 12: "Aroma için bir tutam."}, nutritionValues: {"Enerji": 101, "Protein": 5.6, "Sağlıklı Yağ": 1.7, "Demir": 17.0}, chokingRisk: "Düşük", chokingNote: "Ufalanmış, çok az miktar.", needsReview: true),
  Food(name: "Tarçın", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bir tutam; pürelere tatlandırmak için.", 9: "Yulaf/muhallebide bir tutam.", 12: "Tatlandırmak için az miktar."}, nutritionValues: {"Enerji": 247, "Protein": 4.0, "Sağlıklı Yağ": 1.2, "Demir": 8.3}, chokingRisk: "Düşük", chokingNote: "Sadece bir tutam (aşırısı boğazı tahriş edebilir).", needsReview: true),
  Food(name: "Zerdeçal", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok az; yemeklere renk/aroma.", 9: "Sebze yemeklerinde bir tutam.", 12: "Az miktar baharat olarak."}, nutritionValues: {"Enerji": 312, "Protein": 9.7, "Sağlıklı Yağ": 3.3, "Demir": 55.0}, chokingRisk: "Düşük", chokingNote: "Çok az miktar.", needsReview: true),
  Food(name: "Kişniş", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Taze, ince kıyılıp az miktar.", 9: "Çorba/sebzede kıyılmış.", 12: "Yemeklerde aroma."}, nutritionValues: {"Enerji": 23, "Protein": 2.1, "Sağlıklı Yağ": 0.5, "Demir": 1.8}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır; az miktar.", needsReview: true),

  // ===== Parti 2: genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Yeniden eklendi (temiz): Domates
  Food(name: "Domates", emoji: "🍅", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kabuğu ve çekirdekleri ayıklanıp ezilir.", 9: "Küçük yumuşak parçalar.", 12: "Cherry domates boyuna dört parçaya bölünür."}, nutritionValues: {"Enerji": 18, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Cherry/küçük domates ASLA bütün verilmez — boyuna ÇEYREKLENİR.", needsReview: true),
  // Meyveler
  Food(name: "Frenk Üzümü", emoji: "🍇", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Ezilmiş veya çeyreklenmiş.", 12: "Çeyreklenmiş taneler."}, nutritionValues: {"Enerji": 56, "Protein": 1.4, "Sağlıklı Yağ": 0.2, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Küçük yuvarlak tane; ezilir veya çeyreklenir.", needsReview: true),
  Food(name: "Dut", emoji: "🫐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; ezilmiş.", 9: "Bütün yumuşak taneler.", 12: "Yoğurda karıştırılmış."}, nutritionValues: {"Enerji": 43, "Protein": 1.4, "Sağlıklı Yağ": 0.4, "Demir": 1.9}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve ezilebilir.", needsReview: true),
  Food(name: "Guava", emoji: "🍐", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Sert çekirdekli; önerilmez.", 9: "Çekirdekleri ayıklanıp püre.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 68, "Protein": 2.6, "Sağlıklı Yağ": 1.0, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Sert çekirdekleri ayıklanır.", needsReview: true),
  Food(name: "Liçi", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çekirdeği çıkarılıp küçük parçalara bölünür.", 12: "Çekirdeksiz, dörde bölünmüş."}, nutritionValues: {"Enerji": 66, "Protein": 0.8, "Sağlıklı Yağ": 0.4, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; yuvarlak — küçük parçalara bölünür.", needsReview: true),
  Food(name: "Yenidünya", emoji: "🍊", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdekleri ve kabuğu ayıklanıp püre.", 9: "Yumuşak küçük parçalar.", 12: "Çekirdeksiz dilimler."}, nutritionValues: {"Enerji": 47, "Protein": 0.4, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Büyük çekirdekleri mutlaka ayıklanır.", needsReview: true),
  Food(name: "Ejder Meyvesi", emoji: "🍈", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yumuşak iç kısmı ezilir.", 9: "Çubuk/küçük parçalar.", 12: "Küçük doğranmış."}, nutritionValues: {"Enerji": 60, "Protein": 1.2, "Sağlıklı Yağ": 0.4, "Demir": 0.7}, chokingRisk: "Düşük", chokingNote: "Yumuşak iç kısım; düşük risk.", needsReview: true),
  Food(name: "Karambola", emoji: "⭐", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce dilimlenip yumuşak olanı.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 1.0, "Sağlıklı Yağ": 0.3, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Olgun ve yumuşak olanı; ince dilim.", needsReview: true),
  Food(name: "Kumkuat", emoji: "🍊", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çekirdekleri ayıklanıp dörde bölünür.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 71, "Protein": 1.9, "Sağlıklı Yağ": 0.9, "Demir": 0.9}, chokingRisk: "Yüksek", chokingNote: "Küçük ve yuvarlak; çekirdeksiz, boyuna çeyreklenir.", needsReview: true),
  Food(name: "Kuşburnu", emoji: "🌹", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdekli/tüylü; çiğ verilmez.", 9: "Pişirilip süzülmüş marmelat/püre.", 12: "Şekersiz kuşburnu püresi."}, nutritionValues: {"Enerji": 162, "Protein": 1.6, "Sağlıklı Yağ": 0.3, "Demir": 1.1}, chokingRisk: "Orta", chokingNote: "İçindeki sert çekirdek/tüyler ayıklanır; süzülür.", needsReview: true),
  Food(name: "Bektaşi Üzümü", emoji: "🍏", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Pişirilip ezilir.", 12: "Çeyreklenmiş taneler."}, nutritionValues: {"Enerji": 44, "Protein": 0.9, "Sağlıklı Yağ": 0.6, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Yuvarlak tane; ezilir veya çeyreklenir.", needsReview: true),
  // Sebzeler
  Food(name: "Kırmızı Lahana", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 1.4, "Sağlıklı Yağ": 0.2, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Roka", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce şeritler."}, nutritionValues: {"Enerji": 25, "Protein": 2.6, "Sağlıklı Yağ": 0.7, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır.", needsReview: true),
  Food(name: "Şalgam", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 28, "Protein": 0.9, "Sağlıklı Yağ": 0.1, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çiğ sert; pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Karalahana", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Sapları ayıklanıp iyice pişirilir; ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 32, "Protein": 3.0, "Sağlıklı Yağ": 0.6, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Sert sapları çıkarılır; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Kabak Çiçeği", emoji: "🌼", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İçi temizlenip pişirilir; ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Zeytinyağlı/pişmiş olarak."}, nutritionValues: {"Enerji": 27, "Protein": 3.0, "Sağlıklı Yağ": 0.4, "Demir": 0.9}, chokingRisk: "Düşük", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Acur", emoji: "🥒", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Soyulmuş kalın çubuk (diş kaşıma).", 9: "Soyulmuş küçük parçalar.", 12: "Küçük doğranmış."}, nutritionValues: {"Enerji": 14, "Protein": 0.6, "Sağlıklı Yağ": 0.1, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Soyulur; yuvarlak dilim verilmez.", needsReview: true),
  Food(name: "Frenk Soğanı", emoji: "🌿", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce kıyılmış olarak."}, nutritionValues: {"Enerji": 30, "Protein": 3.3, "Sağlıklı Yağ": 0.7, "Demir": 1.6}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır.", needsReview: true),
  Food(name: "Bakla", emoji: "🫛", category: "Sebze", startingMonth: 24, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kabuğu soyulup pişirilir; ezilir.", 12: "Pişmiş, kabuğu alınmış taneler."}, nutritionValues: {"Enerji": 88, "Protein": 7.9, "Sağlıklı Yağ": 0.7, "Demir": 1.9}, chokingRisk: "Orta", chokingNote: "Dış kabuk soyulur, ezilir. Favizm öyküsü varsa doktora danışın.", needsReview: true),
  Food(name: "Su Teresi", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce kıyılmış."}, nutritionValues: {"Enerji": 11, "Protein": 2.3, "Sağlıklı Yağ": 0.1, "Demir": 0.2}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır.", needsReview: true),
  Food(name: "Brokoli Filizi", emoji: "🥦", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp pişmiş yemeğe karıştırılır.", 12: "Yemeğe karıştırılmış."}, nutritionValues: {"Enerji": 35, "Protein": 3.0, "Sağlıklı Yağ": 0.5, "Demir": 1.0}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır.", needsReview: true),
  // Et / Balık / Protein
  Food(name: "Palamut", emoji: "🐟", category: "Balık", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kılçığı ayıklanıp iyi pişirilir; ezilir.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 168, "Protein": 23.0, "Sağlıklı Yağ": 8.0, "Demir": 1.3}, chokingRisk: "Orta", chokingNote: "Tüm kılçıklar dikkatle ayıklanır.", needsReview: true),
  Food(name: "Midye", emoji: "🦪", category: "Balık", startingMonth: 24, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip çok ince doğranır (alerjen).", 12: "İnce doğranmış."}, nutritionValues: {"Enerji": 86, "Protein": 12.0, "Sağlıklı Yağ": 2.2, "Demir": 3.9}, chokingRisk: "Orta", chokingNote: "Alerjen; iyice pişirilip çok ince doğranır.", needsReview: true),
  Food(name: "Dana Ciğeri", emoji: "🥩", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş, püre (demir/A vitamini; haftada 1).", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 135, "Protein": 20.0, "Sağlıklı Yağ": 3.6, "Demir": 6.5}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ezilir; A vitamini yüksek, haftada 1-2 kez.", needsReview: true),
  Food(name: "Tavuk Ciğeri", emoji: "🍗", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş, püre (demir kaynağı).", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 167, "Protein": 24.0, "Sağlıklı Yağ": 6.5, "Demir": 9.0}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ezilir; A vitamini yüksek, haftada 1-2 kez.", needsReview: true),
  Food(name: "Hindi Kıyma", emoji: "🍖", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş, nemli; ezilir.", 9: "Köfte/ufalanmış nemli parçalar.", 12: "Küçük köfteler."}, nutritionValues: {"Enerji": 170, "Protein": 27.0, "Sağlıklı Yağ": 7.0, "Demir": 1.4}, chokingRisk: "Orta", chokingNote: "Kuru kalmaması için suyuyla; ufalanır.", needsReview: true),
  Food(name: "Maş Fasulyesi", emoji: "🫘", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş, hafif ezilmiş.", 12: "Pişmiş taneler."}, nutritionValues: {"Enerji": 347, "Protein": 24.0, "Sağlıklı Yağ": 1.2, "Demir": 6.7}, chokingRisk: "Orta", chokingNote: "İyice pişirilip yumuşatılır, ezilir.", needsReview: true),
  Food(name: "Edamame", emoji: "🫛", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Kabuğu alınıp ezilir (soya alerjeni).", 9: "Kabuğu alınmış, hafif ezilmiş.", 12: "Kabuksuz taneler."}, nutritionValues: {"Enerji": 121, "Protein": 11.0, "Sağlıklı Yağ": 5.0, "Demir": 2.3}, chokingRisk: "Yüksek", chokingNote: "Yuvarlak; dış kabuk alınıp ezilir.", needsReview: true),
  Food(name: "Tofu", emoji: "🧈", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Yumuşak tofu ezilir (soya alerjeni).", 9: "Yumuşak çubuk/küçük küp.", 12: "Küçük küpler."}, nutritionValues: {"Enerji": 76, "Protein": 8.0, "Sağlıklı Yağ": 4.8, "Demir": 5.4}, chokingRisk: "Düşük", chokingNote: "Yumuşak; düşük risk.", needsReview: true),
  Food(name: "Çökelek", emoji: "🧀", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Az tuzlu, yumuşak; ezilmiş.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 98, "Protein": 11.0, "Sağlıklı Yağ": 4.0, "Demir": 0.2}, chokingRisk: "Düşük", chokingNote: "Yumuşak; tuzu az olanı tercih edilir.", needsReview: true),
  Food(name: "Tulum Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Çok az (tuzlu); küçük yumuşak parça.", 12: "Az miktar, küçük parça."}, nutritionValues: {"Enerji": 330, "Protein": 22.0, "Sağlıklı Yağ": 26.0, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Tuzu yüksek; az miktarda küçük parça.", needsReview: true),
  Food(name: "Sazan", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı dikkatle ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 127, "Protein": 17.8, "Sağlıklı Yağ": 5.6, "Demir": 1.2}, chokingRisk: "Orta", chokingNote: "Kılçıkları çok dikkatle ayıklanır.", needsReview: true),
  Food(name: "Kefal", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 117, "Protein": 19.0, "Sağlıklı Yağ": 3.8, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  // Bakliyat / Tahıl / Tohum
  Food(name: "Sarı Mercimek", emoji: "🫘", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip püre (çorba).", 9: "Pişmiş, hafif ezilmiş.", 12: "Pişmiş taneler/çorba."}, nutritionValues: {"Enerji": 352, "Protein": 24.0, "Sağlıklı Yağ": 1.5, "Demir": 6.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Kuru Bezelye", emoji: "🫛", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş, hafif ezilmiş.", 12: "Pişmiş taneler."}, nutritionValues: {"Enerji": 341, "Protein": 25.0, "Sağlıklı Yağ": 1.2, "Demir": 4.4}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ezilir; yuvarlak tane ezilir.", needsReview: true),
  Food(name: "Amarant", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip lapa.", 9: "Yumuşak lapa, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 371, "Protein": 14.0, "Sağlıklı Yağ": 7.0, "Demir": 7.6}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Çavdar", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Lapa veya ince tost (gluten).", 9: "Çavdar ekmeği tost olarak.", 12: "Küçük lokmalar."}, nutritionValues: {"Enerji": 338, "Protein": 10.0, "Sağlıklı Yağ": 1.6, "Demir": 2.6}, chokingRisk: "Orta", chokingNote: "Taze yumuşak ekmek topaklanır; tost verilir.", needsReview: true),
  Food(name: "Ay Çekirdeği İçi", emoji: "🌻", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Bütün verilmez.", 9: "Un gibi öğütülmüş çok az.", 12: "Toz/ezme olarak."}, nutritionValues: {"Enerji": 584, "Protein": 21.0, "Sağlıklı Yağ": 51.0, "Demir": 5.2}, chokingRisk: "Yüksek", chokingNote: "Bütün VERİLMEZ; öğütülmüş/ezme olarak.", needsReview: true),
  Food(name: "Haşhaş", emoji: "🌰", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Öğütülmüş çok az olarak hamur işinde.", 12: "Ezme/toz olarak."}, nutritionValues: {"Enerji": 525, "Protein": 18.0, "Sağlıklı Yağ": 42.0, "Demir": 9.8}, chokingRisk: "Orta", chokingNote: "Öğütülmüş olarak az miktar.", needsReview: true),
  // Otlar / Baharatlar
  Food(name: "Kimyon", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bir tutam; yemeklere aroma.", 9: "Sebze/et yemeklerinde az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 375, "Protein": 18.0, "Sağlıklı Yağ": 22.0, "Demir": 66.0}, chokingRisk: "Düşük", chokingNote: "Çok az miktar.", needsReview: true),
  Food(name: "Karabiber", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çok az (bir tutam) yemeğe.", 12: "Az miktar."}, nutritionValues: {"Enerji": 251, "Protein": 10.0, "Sağlıklı Yağ": 3.3, "Demir": 9.7}, chokingRisk: "Düşük", chokingNote: "Sadece bir tutam (aşırısı tahriş edebilir).", needsReview: true),
  Food(name: "Vanilya", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Alkolsüz vanilya; bir tutam tatlandırmak için.", 9: "Yulaf/muhallebide az.", 12: "Tatlandırmak için az."}, nutritionValues: {"Enerji": 288, "Protein": 0.1, "Sağlıklı Yağ": 0.1, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Alkolsüz olanı; çok az miktar.", needsReview: true),
  Food(name: "Defne Yaprağı", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yemeğe aroma için eklenir, SERVİSTEN ÖNCE çıkarılır.", 9: "Pişirmede kullanılır, yaprak çıkarılır.", 12: "Yaprak yenilmez, çıkarılır."}, nutritionValues: {"Enerji": 313, "Protein": 7.6, "Sağlıklı Yağ": 8.4, "Demir": 43.0}, chokingRisk: "Yüksek", chokingNote: "Yaprak YENMEZ — pişirmeden sonra mutlaka çıkarılır (boğulma).", needsReview: true),

  // ===== Parti 3: genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Hünnap", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdekli ve sert; önerilmez.", 9: "Çekirdeği çıkarılıp ezilir.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 79, "Protein": 1.2, "Sağlıklı Yağ": 0.2, "Demir": 0.5}, chokingRisk: "Yüksek", chokingNote: "Sert çekirdeği çıkarılır; yuvarlak — küçük parçalara bölünür.", needsReview: true),
  Food(name: "Muşmula", emoji: "🍊", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; çekirdekleri ayıklanıp püre.", 9: "Yumuşak küçük parçalar.", 12: "Çekirdeksiz parçalar."}, nutritionValues: {"Enerji": 47, "Protein": 0.4, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Büyük çekirdekleri ayıklanır; olgun olanı verilir.", needsReview: true),
  Food(name: "Pomelo", emoji: "🍊", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Zar ve çekirdekleri ayıklanıp küçük parçalar.", 12: "Zarsız bölümler."}, nutritionValues: {"Enerji": 38, "Protein": 0.8, "Sağlıklı Yağ": 0.0, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Zar ve çekirdekler ayıklanır.", needsReview: true),
  Food(name: "Kan Portakalı", emoji: "🍊", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Zarları ve çekirdekleri ayıklanıp püre.", 9: "Zarsız küçük parçalar.", 12: "Zarsız bölümler."}, nutritionValues: {"Enerji": 50, "Protein": 0.9, "Sağlıklı Yağ": 0.1, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Zar ve çekirdekler ayıklanır.", needsReview: true),
  Food(name: "Can Eriği", emoji: "🍑", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdeği çıkarılıp kabuğu soyularak ezilir.", 9: "Çekirdeksiz, yumuşak küçük parçalar.", 12: "Çekirdeksiz, dörde bölünmüş."}, nutritionValues: {"Enerji": 46, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.2}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; yuvarlak — çeyreklenir.", needsReview: true),
  Food(name: "Mürdüm Eriği", emoji: "🍑", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdeği çıkarılıp ezilir.", 9: "Çekirdeksiz küçük parçalar.", 12: "Çekirdeksiz, dörde bölünmüş."}, nutritionValues: {"Enerji": 60, "Protein": 0.8, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; çeyreklenir.", needsReview: true),
  Food(name: "Frenk İnciri", emoji: "🌵", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Dikenleri/kabuğu nedeniyle önerilmez.", 9: "Kabuğu/dikenleri temizlenip sert çekirdekleri ayıklanır; püre.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 41, "Protein": 0.7, "Sağlıklı Yağ": 0.5, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Dikenler ve sert çekirdekler mutlaka temizlenir.", needsReview: true),
  Food(name: "Bergamot", emoji: "🍋", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çok ekşi; önerilmez.", 9: "Çok az suyu yemeğe aroma için.", 12: "Reçel/aroma olarak az miktar."}, nutritionValues: {"Enerji": 37, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Düşük", chokingNote: "Genelde aroma; zar ve çekirdek ayıklanır.", needsReview: true),
  Food(name: "Demirhindi", emoji: "🫘", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çekirdekleri ayıklanmış ezme/püre çok az.", 12: "Yemeklere ekşilik için az ezme."}, nutritionValues: {"Enerji": 239, "Protein": 2.8, "Sağlıklı Yağ": 0.6, "Demir": 2.8}, chokingRisk: "Orta", chokingNote: "Sert çekirdekler ayıklanır; ezme olarak.", needsReview: true),
  // Sebzeler
  Food(name: "Siyah Zeytin", emoji: "🫒", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdek ve tuz nedeniyle önerilmez.", 9: "Çekirdeği çıkarılıp tuzu giderilmiş, ince doğranmış.", 12: "Çekirdeksiz, ince doğranmış az miktar."}, nutritionValues: {"Enerji": 115, "Protein": 0.8, "Sağlıklı Yağ": 11.0, "Demir": 3.3}, chokingRisk: "Yüksek", chokingNote: "Çekirdek ÇIKARILIR; yuvarlak — ince doğranır; tuzu azaltılır.", needsReview: true),
  Food(name: "Yeşil Zeytin", emoji: "🫒", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdek ve tuz nedeniyle önerilmez.", 9: "Çekirdeği çıkarılıp tuzu giderilmiş, ince doğranmış.", 12: "Çekirdeksiz, ince doğranmış az miktar."}, nutritionValues: {"Enerji": 145, "Protein": 1.0, "Sağlıklı Yağ": 15.0, "Demir": 0.5}, chokingRisk: "Yüksek", chokingNote: "Çekirdek ÇIKARILIR; ince doğranır; tuzu azaltılır.", needsReview: true),
  Food(name: "Kıvırcık", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce şeritler."}, nutritionValues: {"Enerji": 15, "Protein": 1.4, "Sağlıklı Yağ": 0.2, "Demir": 0.9}, chokingRisk: "Orta", chokingNote: "Çiğ yaprak ince kıyılır.", needsReview: true),
  Food(name: "Ebegümeci", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yıkanıp pişirilir; ezilir.", 9: "Pişmiş, ince kıyılmış.", 12: "Zeytinyağlı yemekte ince kıyılmış."}, nutritionValues: {"Enerji": 37, "Protein": 3.0, "Sağlıklı Yağ": 0.6, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "Pişirilip ince kıyılır.", needsReview: true),
  Food(name: "Isırgan Otu", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "MUTLAKA pişirilir (çiğ yakar); ezilir.", 9: "Pişmiş, ince kıyılmış.", 12: "Pişmiş yemekte ince kıyılmış."}, nutritionValues: {"Enerji": 42, "Protein": 2.7, "Sağlıklı Yağ": 0.1, "Demir": 1.6}, chokingRisk: "Düşük", chokingNote: "Çiğ verilmez (yakıcı); mutlaka pişirilip kıyılır.", needsReview: true),
  Food(name: "Madımak", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yıkanıp pişirilir; ezilir.", 9: "Pişmiş, ince kıyılmış.", 12: "Pişmiş yemekte."}, nutritionValues: {"Enerji": 40, "Protein": 3.0, "Sağlıklı Yağ": 0.5, "Demir": 2.0}, chokingRisk: "Düşük", chokingNote: "Pişirilip ince kıyılır.", needsReview: true),
  Food(name: "Hardal Otu", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 27, "Protein": 2.9, "Sağlıklı Yağ": 0.4, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Radika", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Acımsı; önerilmez.", 9: "Haşlanıp ince kıyılır.", 12: "Pişmiş, ince doğranmış."}, nutritionValues: {"Enerji": 23, "Protein": 1.7, "Sağlıklı Yağ": 0.3, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "Haşlanıp ince kıyılır.", needsReview: true),
  Food(name: "Kuzukulağı", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Az miktar, ince kıyılıp pişmiş yemeğe.", 12: "Az miktar (okzalik asit)."}, nutritionValues: {"Enerji": 22, "Protein": 2.0, "Sağlıklı Yağ": 0.7, "Demir": 2.4}, chokingRisk: "Düşük", chokingNote: "Az miktar; okzalik asit nedeniyle sık verilmez.", needsReview: true),
  Food(name: "Tere", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce kıyılıp yemeğe karıştırılır.", 12: "İnce kıyılmış."}, nutritionValues: {"Enerji": 32, "Protein": 2.6, "Sağlıklı Yağ": 0.7, "Demir": 1.3}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır.", needsReview: true),
  // Et / Balık / Süt / Kuruyemiş
  Food(name: "Bonfile", emoji: "🥩", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş; lif lif didiklenir/püre.", 9: "Didiklenmiş, suyuyla nemli.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 158, "Protein": 26.0, "Sağlıklı Yağ": 5.0, "Demir": 1.9}, chokingRisk: "Orta", chokingNote: "Lif lif didiklenir; kuru kalmasın diye suyuyla.", needsReview: true),
  Food(name: "Bıldırcın Eti", emoji: "🍗", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kemiksiz, iyi pişmiş; didiklenir.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 227, "Protein": 25.0, "Sağlıklı Yağ": 14.0, "Demir": 4.5}, chokingRisk: "Orta", chokingNote: "Küçük kemikleri dikkatle ayıklanır; didiklenir.", needsReview: true),
  Food(name: "Hindi Ciğeri", emoji: "🍗", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş, püre (demir/A vitamini; haftada 1).", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 228, "Protein": 21.0, "Sağlıklı Yağ": 16.0, "Demir": 7.0}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ezilir; A vitamini yüksek, haftada 1-2 kez.", needsReview: true),
  Food(name: "Barbun Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 123, "Protein": 19.0, "Sağlıklı Yağ": 4.4, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "İstavrit", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı dikkatle ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 140, "Protein": 20.0, "Sağlıklı Yağ": 6.0, "Demir": 1.4}, chokingRisk: "Orta", chokingNote: "Tüm kılçıklar dikkatle ayıklanır.", needsReview: true),
  Food(name: "Mercan Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 105, "Protein": 18.0, "Sağlıklı Yağ": 3.5, "Demir": 0.9}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Mozzarella", emoji: "🧀", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Az tuzlu; küçük yumuşak parçalar.", 12: "İnce şerit/küçük parça."}, nutritionValues: {"Enerji": 280, "Protein": 22.0, "Sağlıklı Yağ": 22.0, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Yapışkan/elastik olabilir; çok küçük yumuşak parçalar.", needsReview: true),
  Food(name: "Ricotta Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Yumuşak; ezme gibi sürülür.", 12: "Küçük parçalar/sürme."}, nutritionValues: {"Enerji": 174, "Protein": 11.0, "Sağlıklı Yağ": 13.0, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve sürülebilir; düşük risk.", needsReview: true),
  Food(name: "Soya Fasulyesi", emoji: "🫘", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "İyice pişirilip ezilir (soya alerjeni).", 9: "Kabuğu alınmış, hafif ezilmiş.", 12: "Pişmiş taneler."}, nutritionValues: {"Enerji": 446, "Protein": 36.0, "Sağlıklı Yağ": 20.0, "Demir": 15.7}, chokingRisk: "Orta", chokingNote: "İyice pişirilir; yuvarlak tane ezilir.", needsReview: true),
  Food(name: "Taze Börülce", emoji: "🫛", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 97, "Protein": 3.0, "Sağlıklı Yağ": 0.3, "Demir": 1.1}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Pekan Cevizi", emoji: "🌰", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Bütün verilmez; öğütülmüş/ezme.", 9: "Toz/ezme olarak.", 12: "İnce ezme olarak."}, nutritionValues: {"Enerji": 691, "Protein": 9.0, "Sağlıklı Yağ": 72.0, "Demir": 2.5}, chokingRisk: "Yüksek", chokingNote: "Bütün/parça VERİLMEZ; öğütülmüş/ezme.", needsReview: true),
  Food(name: "Makadamya", emoji: "🌰", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Bütün verilmez; öğütülmüş/ezme.", 9: "Toz/ezme olarak.", 12: "İnce ezme olarak."}, nutritionValues: {"Enerji": 718, "Protein": 8.0, "Sağlıklı Yağ": 76.0, "Demir": 3.7}, chokingRisk: "Yüksek", chokingNote: "Bütün/parça VERİLMEZ; öğütülmüş/ezme.", needsReview: true),
  // Tahıllar
  Food(name: "Siyez Buğdayı", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyice pişirilip lapa (gluten).", 9: "Yumuşak lapa/çorba.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 338, "Protein": 18.0, "Sağlıklı Yağ": 2.5, "Demir": 3.9}, chokingRisk: "Orta", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Yarma", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyice pişirilip ezilir (gluten).", 9: "Yumuşak pişmiş, çorbada.", 12: "Aşure/çorba kıvamında."}, nutritionValues: {"Enerji": 342, "Protein": 12.0, "Sağlıklı Yağ": 1.5, "Demir": 3.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Pirinç Unu", emoji: "🍚", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Muhallebi/lapa olarak pişirilir.", 9: "Meyveli muhallebi.", 12: "Tatlı/çorba kıvam vericisi."}, nutritionValues: {"Enerji": 366, "Protein": 5.9, "Sağlıklı Yağ": 1.4, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Pişirilerek lapa/muhallebi yapılır.", needsReview: true),
  Food(name: "Galeta Unu", emoji: "🍞", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Köfte/sebze bağlayıcı olarak az.", 12: "Kaplamalarda."}, nutritionValues: {"Enerji": 395, "Protein": 13.0, "Sağlıklı Yağ": 5.3, "Demir": 4.2}, chokingRisk: "Düşük", chokingNote: "Yemeğe bağlayıcı olarak; tek başına kuru verilmez.", needsReview: true),
  // Diğer / Baharat / Yağ
  Food(name: "Bal", emoji: "🍯", category: "Diğer", startingMonth: 12, allergyRisk: "Düşük", presentationStyles: {6: "12 aydan önce ASLA verilmez (bebek botulizmi riski).", 9: "12 aydan önce verilmez.", 12: "12 aydan sonra az miktarda."}, nutritionValues: {"Enerji": 304, "Protein": 0.3, "Sağlıklı Yağ": 0.0, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "1 YAŞINDAN ÖNCE BAL VERİLMEZ — bebek botulizmi riski.", needsReview: true),
  Food(name: "Zencefil", emoji: "🫚", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok az rendelenmiş, yemeğe aroma.", 9: "Sebze/et yemeklerinde az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 80, "Protein": 1.8, "Sağlıklı Yağ": 0.8, "Demir": 0.6}, chokingRisk: "Düşük", chokingNote: "Çok az rendelenmiş olarak.", needsReview: true),
  Food(name: "Sumak", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çok az ekşilik için yemeğe.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 300, "Protein": 4.0, "Sağlıklı Yağ": 7.0, "Demir": 3.0}, chokingRisk: "Düşük", chokingNote: "Çok az miktar.", needsReview: true),
  Food(name: "Köri", emoji: "🍛", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bir tutam (acısız/yumuşak) yemeğe.", 9: "Sebze/et yemeklerinde az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 325, "Protein": 14.0, "Sağlıklı Yağ": 14.0, "Demir": 19.0}, chokingRisk: "Düşük", chokingNote: "Acısız karışım; çok az miktar.", needsReview: true),
  Food(name: "Fındık Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Pişmiş yemeğe birkaç damla.", 9: "Sebze/et yemeğinde az.", 12: "Yemeklerde sıvı yağ olarak az."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Sıvı yağ; az miktar (fındık alerjisi öyküsünde dikkat).", needsReview: true),
  Food(name: "Kakao", emoji: "🍫", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Şekersiz çok az, muhallebi/yulafa.", 12: "Az miktar şekersiz kakao."}, nutritionValues: {"Enerji": 228, "Protein": 19.6, "Sağlıklı Yağ": 13.7, "Demir": 13.9}, chokingRisk: "Düşük", chokingNote: "Şekersiz ve az miktar; kafein içerir, sınırlı verilir.", needsReview: true),

  // ===== Parti 4: genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Misket Limonu", emoji: "🍋", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çok ekşi; önerilmez.", 9: "Çok az suyu yemeğe aroma için.", 12: "Aroma olarak az miktar."}, nutritionValues: {"Enerji": 30, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.6}, chokingRisk: "Düşük", chokingNote: "Genelde aroma; çekirdek ayıklanır.", needsReview: true),
  Food(name: "Alıç", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdekli ve sert; önerilmez.", 9: "Çekirdeği çıkarılıp ezilir.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 52, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Sert çekirdek çıkarılır; yuvarlak — küçük parçalara bölünür.", needsReview: true),
  Food(name: "İğde", emoji: "🫘", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Sert çekirdekli ve unlu; önerilmez.", 9: "Çekirdeği çıkarılıp ezilir/ıslatılır.", 12: "Çekirdeksiz püre."}, nutritionValues: {"Enerji": 330, "Protein": 3.8, "Sağlıklı Yağ": 1.0, "Demir": 3.0}, chokingRisk: "Yüksek", chokingNote: "Sert çekirdek çıkarılır; unlu yapısı su/süt ile yumuşatılır.", needsReview: true),
  Food(name: "Üvez", emoji: "🍒", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İyice olgun/pişmiş, çekirdekleri ayıklanıp ezilir.", 12: "Çekirdeksiz püre."}, nutritionValues: {"Enerji": 50, "Protein": 1.4, "Sağlıklı Yağ": 0.5, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Yalnız iyice olgun/pişmiş; çekirdekleri ayıklanır.", needsReview: true),
  Food(name: "Mürver", emoji: "🫐", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ verilmez (toksik).", 9: "MUTLAKA pişirilir; çekirdek/sap ayıklanıp süzülür.", 12: "Pişmiş şurup/püre az miktar."}, nutritionValues: {"Enerji": 73, "Protein": 0.7, "Sağlıklı Yağ": 0.5, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "ÇİĞ TÜKETİLMEZ — mutlaka pişirilir; sap/çekirdek ayıklanır.", needsReview: true),
  Food(name: "Aronya", emoji: "🫐", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Buruk; önerilmez.", 9: "Pişirilip ezilir/süzülür.", 12: "Az miktar püre."}, nutritionValues: {"Enerji": 47, "Protein": 0.7, "Sağlıklı Yağ": 0.5, "Demir": 0.9}, chokingRisk: "Orta", chokingNote: "Buruk; pişirilip ezilir, yuvarlak tane ezilir.", needsReview: true),
  Food(name: "Kara Frenk Üzümü", emoji: "🍇", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Ezilmiş veya çeyreklenmiş.", 12: "Çeyreklenmiş taneler."}, nutritionValues: {"Enerji": 63, "Protein": 1.4, "Sağlıklı Yağ": 0.4, "Demir": 1.5}, chokingRisk: "Orta", chokingNote: "Küçük yuvarlak tane; ezilir veya çeyreklenir.", needsReview: true),
  Food(name: "Beyaz Dut", emoji: "🫐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; ezilmiş.", 9: "Bütün yumuşak taneler.", 12: "Yoğurda karıştırılmış."}, nutritionValues: {"Enerji": 43, "Protein": 1.4, "Sağlıklı Yağ": 0.4, "Demir": 1.9}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve ezilebilir.", needsReview: true),
  Food(name: "Gilaburu", emoji: "🍒", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Ekşi/çekirdekli; önerilmez.", 9: "Pişirilip süzülmüş, çekirdeksiz püre.", 12: "Az miktar püre."}, nutritionValues: {"Enerji": 40, "Protein": 0.6, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çekirdekleri ayıklanır; pişirilip süzülür.", needsReview: true),
  Food(name: "Kızamık", emoji: "🍒", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Ekşi; önerilmez.", 9: "Pişirilip ezilir/süzülür.", 12: "Az miktar püre."}, nutritionValues: {"Enerji": 45, "Protein": 1.0, "Sağlıklı Yağ": 0.3, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Küçük tane; ezilir/süzülür.", needsReview: true),
  // Sebzeler
  Food(name: "Kara Turp", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ serttir; önerilmez.", 9: "Rendelenir veya pişirilip yumuşatılır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 20, "Protein": 0.7, "Sağlıklı Yağ": 0.1, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Çiğ sert; rendelenir/pişirilir.", needsReview: true),
  Food(name: "Pak Çoy", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 13, "Protein": 1.5, "Sağlıklı Yağ": 0.2, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Çin Lahanası", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 16, "Protein": 1.2, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Yaprak Lahana", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Sert sapları ayıklanıp iyice pişirilir; ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 49, "Protein": 4.3, "Sağlıklı Yağ": 0.9, "Demir": 1.5}, chokingRisk: "Orta", chokingNote: "Sert sapları çıkarılır; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Deniz Börülcesi", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Tuzlu; önerilmez.", 9: "Bolca yıkanıp/haşlanıp tuzu giderilir, ince kıyılır.", 12: "Pişmiş ince doğranmış."}, nutritionValues: {"Enerji": 25, "Protein": 1.5, "Sağlıklı Yağ": 0.3, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Doğal tuzu yıkanarak azaltılır; ince kıyılır.", needsReview: true),
  Food(name: "Karahindiba", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yıkanıp pişirilir; ezilir.", 9: "Pişmiş, ince kıyılmış.", 12: "Pişmiş yemekte."}, nutritionValues: {"Enerji": 45, "Protein": 2.7, "Sağlıklı Yağ": 0.7, "Demir": 3.1}, chokingRisk: "Orta", chokingNote: "Pişirilip ince kıyılır.", needsReview: true),
  Food(name: "Mor Havuç", emoji: "🥕", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip püre veya kalın çubuk (diş kaşıma).", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar; çiğ rendelenmiş."}, nutritionValues: {"Enerji": 41, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çiğ sert (boğulma); pişirilir veya rendelenir.", needsReview: true),
  Food(name: "Su Kabağı", emoji: "🥒", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Soyulup pişirilir; püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 14, "Protein": 0.6, "Sağlıklı Yağ": 0.0, "Demir": 0.2}, chokingRisk: "Düşük", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  // Et / Balık / Süt / Kuruyemiş
  Food(name: "Tavşan Eti", emoji: "🍖", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kemiksiz, iyi pişmiş; didiklenir.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 173, "Protein": 21.8, "Sağlıklı Yağ": 8.8, "Demir": 4.0}, chokingRisk: "Orta", chokingNote: "Küçük kemikleri dikkatle ayıklanır; didiklenir.", needsReview: true),
  Food(name: "Kuzu Ciğeri", emoji: "🥩", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyi pişmiş, püre (demir/A vitamini; haftada 1).", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 137, "Protein": 20.0, "Sağlıklı Yağ": 5.0, "Demir": 7.4}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ezilir; A vitamini yüksek, haftada 1-2 kez.", needsReview: true),
  Food(name: "Tirsi Balığı", emoji: "🐟", category: "Balık", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Çok kılçıklı; tüm kılçıklar dikkatle ayıklanıp ezilir.", 12: "Kılçıksız küçük parçalar."}, nutritionValues: {"Enerji": 197, "Protein": 20.0, "Sağlıklı Yağ": 12.0, "Demir": 1.1}, chokingRisk: "Yüksek", chokingNote: "Çok kılçıklı — kılçıklar çok dikkatle ayıklanır.", needsReview: true),
  Food(name: "Gümüş Balığı", emoji: "🐟", category: "Balık", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kılçıkları ayıklanıp ezilir.", 12: "Kılçıksız küçük parçalar."}, nutritionValues: {"Enerji": 110, "Protein": 19.0, "Sağlıklı Yağ": 3.0, "Demir": 1.0}, chokingRisk: "Yüksek", chokingNote: "Küçük balık; tüm kılçıklar dikkatle ayıklanır.", needsReview: true),
  Food(name: "Kalamar", emoji: "🦑", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip çok ince doğranır (alerjen + sert)."}, nutritionValues: {"Enerji": 92, "Protein": 15.6, "Sağlıklı Yağ": 1.4, "Demir": 0.7}, chokingRisk: "Yüksek", chokingNote: "Lastiksi/sert; alerjen — 12 ay+, çok ince doğranır.", needsReview: true),
  Food(name: "Yengeç", emoji: "🦀", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip didiklenir (alerjen)."}, nutritionValues: {"Enerji": 97, "Protein": 19.0, "Sağlıklı Yağ": 1.5, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "Alerjen; iyice pişirilip kabuk/kıkırdak ayıklanır.", needsReview: true),
  Food(name: "Kaymak", emoji: "🥛", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Çok az; ekmeğe ince sürülür.", 12: "Az miktar (yağ yüksek)."}, nutritionValues: {"Enerji": 300, "Protein": 3.0, "Sağlıklı Yağ": 30.0, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Yumuşak; az miktarda (yüksek yağ).", needsReview: true),
  Food(name: "Ayran", emoji: "🥛", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzsuz/az tuzlu ev yapımı, bardakla az.", 12: "Tuzsuz ayran bardakla."}, nutritionValues: {"Enerji": 36, "Protein": 1.7, "Sağlıklı Yağ": 1.5, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Tuzsuz/az tuzlu olanı; ana öğün yerine geçmemeli.", needsReview: true),
  Food(name: "Dil Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İnce tellere ayrılıp küçük parça.", 12: "İnce teller halinde."}, nutritionValues: {"Enerji": 330, "Protein": 25.0, "Sağlıklı Yağ": 25.0, "Demir": 0.5}, chokingRisk: "Yüksek", chokingNote: "Elastik/tel tel; ince tellere ayrılır (yapışma/boğulma).", needsReview: true),
  Food(name: "Cheddar Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Rendelenir veya ince çubuk.", 12: "İnce çubuk/küçük parça."}, nutritionValues: {"Enerji": 403, "Protein": 25.0, "Sağlıklı Yağ": 33.0, "Demir": 0.7}, chokingRisk: "Orta", chokingNote: "Rendelenir; tuz içeriğine dikkat.", needsReview: true),
  Food(name: "Brezilya Cevizi", emoji: "🌰", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Bütün verilmez; öğütülmüş/ezme.", 9: "Toz/ezme olarak.", 12: "İnce ezme olarak."}, nutritionValues: {"Enerji": 659, "Protein": 14.0, "Sağlıklı Yağ": 67.0, "Demir": 2.4}, chokingRisk: "Yüksek", chokingNote: "Bütün VERİLMEZ; öğütülmüş. Selenyum yüksek — günde 1'den fazla verilmez.", needsReview: true),
  // Tahıllar
  Food(name: "Mısır Nişastası", emoji: "🌽", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Muhallebi/lapa kıvam vericisi olarak pişirilir.", 9: "Meyveli muhallebi.", 12: "Tatlı/çorba kıvam vericisi."}, nutritionValues: {"Enerji": 381, "Protein": 0.3, "Sağlıklı Yağ": 0.1, "Demir": 0.5}, chokingRisk: "Düşük", chokingNote: "Pişirilerek kıvam verici olarak kullanılır.", needsReview: true),
  Food(name: "Yulaf Kepeği", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip lapa.", 9: "Yoğurt/pürelere karıştırılmış.", 12: "Yulaf lapası içinde."}, nutritionValues: {"Enerji": 246, "Protein": 17.0, "Sağlıklı Yağ": 7.0, "Demir": 5.4}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Aşurelik Buğday", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyice pişirilip ezilir (gluten).", 9: "Çok yumuşak pişmiş, çorbada.", 12: "Aşure kıvamında."}, nutritionValues: {"Enerji": 342, "Protein": 12.0, "Sağlıklı Yağ": 1.5, "Demir": 3.5}, chokingRisk: "Orta", chokingNote: "Tane sert kalmasın diye çok iyi pişirilir.", needsReview: true),
  // Yağlar / Baharatlar
  Food(name: "Ayçiçek Yağı", emoji: "🌻", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişmiş yemeğe birkaç damla.", 9: "Sebze/et yemeğinde az.", 12: "Yemeklerde sıvı yağ olarak az."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Sıvı yağ; az miktar.", needsReview: true),
  Food(name: "Susam Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Pişmiş yemeğe birkaç damla (susam alerjeni).", 9: "Yemeğe az.", 12: "Az miktar aroma/yağ."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Susam alerjeni; az miktar.", needsReview: true),
  Food(name: "Ceviz Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Pişmiş yemeğe birkaç damla (ceviz alerjeni).", 9: "Yemeğe az.", 12: "Az miktar sıvı yağ."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Ceviz alerjeni; az miktar.", needsReview: true),
  Food(name: "Çörek Otu", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Öğütülmüş çok az, hamur işinde.", 12: "Az miktar (tane/öğütülmüş)."}, nutritionValues: {"Enerji": 400, "Protein": 18.0, "Sağlıklı Yağ": 22.0, "Demir": 10.0}, chokingRisk: "Orta", chokingNote: "Küçük tane; öğütülmüş olarak daha güvenli.", needsReview: true),
  Food(name: "Yenibahar", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bir tutam öğütülmüş, yemeğe aroma.", 9: "Et/sebze yemeklerinde az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 263, "Protein": 6.0, "Sağlıklı Yağ": 8.7, "Demir": 7.0}, chokingRisk: "Düşük", chokingNote: "Öğütülmüş, çok az miktar.", needsReview: true),
  Food(name: "Rezene Tohumu", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çay/öğütülmüş olarak gaz için az.", 9: "Öğütülmüş yemeğe aroma.", 12: "Az miktar."}, nutritionValues: {"Enerji": 345, "Protein": 16.0, "Sağlıklı Yağ": 15.0, "Demir": 18.0}, chokingRisk: "Orta", chokingNote: "Bütün tane verilmez; öğütülmüş/çay olarak.", needsReview: true),
  Food(name: "Anason", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Öğütülmüş çok az, hamur işinde.", 12: "Az miktar."}, nutritionValues: {"Enerji": 337, "Protein": 18.0, "Sağlıklı Yağ": 16.0, "Demir": 37.0}, chokingRisk: "Orta", chokingNote: "Bütün tane verilmez; öğütülmüş olarak.", needsReview: true),
  Food(name: "Mahlep", emoji: "🌰", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Öğütülmüş çok az, hamur işinde.", 12: "Az miktar aroma."}, nutritionValues: {"Enerji": 300, "Protein": 6.0, "Sağlıklı Yağ": 10.0, "Demir": 3.0}, chokingRisk: "Düşük", chokingNote: "Öğütülmüş, çok az miktar.", needsReview: true),

  // ===== Parti 5: genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Karadut", emoji: "🫐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; ezilmiş.", 9: "Bütün yumuşak taneler.", 12: "Yoğurda karıştırılmış."}, nutritionValues: {"Enerji": 43, "Protein": 1.4, "Sağlıklı Yağ": 0.4, "Demir": 1.9}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve ezilebilir.", needsReview: true),
  Food(name: "Hindistan Cevizi Suyu", emoji: "🥥", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Bardakla çok az; ana öğün/süt yerine geçmez.", 12: "Şekersiz, az miktar."}, nutritionValues: {"Enerji": 19, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.3}, chokingRisk: "Düşük", chokingNote: "İçecek; az miktarda, ana öğünün yerini almamalı.", needsReview: true),
  Food(name: "Rambutan", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çekirdeği çıkarılıp küçük parçalara bölünür.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 82, "Protein": 0.7, "Sağlıklı Yağ": 0.2, "Demir": 0.4}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; kaygan/yuvarlak — küçük parçalara bölünür.", needsReview: true),
  Food(name: "Mangostan", emoji: "🍇", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Dilimleri ayrılıp çekirdekleri ayıklanır.", 12: "Çekirdeksiz dilimler."}, nutritionValues: {"Enerji": 73, "Protein": 0.4, "Sağlıklı Yağ": 0.6, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Sert çekirdekleri ayıklanır.", needsReview: true),
  Food(name: "Açai", emoji: "🫐", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Şekersiz püre olarak az.", 12: "Şekersiz açai püresi."}, nutritionValues: {"Enerji": 70, "Protein": 1.0, "Sağlıklı Yağ": 5.0, "Demir": 1.0}, chokingRisk: "Düşük", chokingNote: "Genelde şekersiz püre; düşük risk.", needsReview: true),
  Food(name: "Goji Berry", emoji: "🍒", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Kuru ve sert; önerilmez.", 9: "Suda yumuşatılıp ezilir.", 12: "Yumuşatılmış, ince doğranmış."}, nutritionValues: {"Enerji": 349, "Protein": 14.0, "Sağlıklı Yağ": 0.4, "Demir": 6.8}, chokingRisk: "Orta", chokingNote: "Kuru/çiğneme zor; suda yumuşatılıp ezilir.", needsReview: true),
  Food(name: "Physalis", emoji: "🍊", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Boyuna çeyreklenir.", 12: "Çeyreklenmiş taneler."}, nutritionValues: {"Enerji": 53, "Protein": 1.9, "Sağlıklı Yağ": 0.7, "Demir": 1.0}, chokingRisk: "Yüksek", chokingNote: "Küçük yuvarlak — bütün verilmez, boyuna çeyreklenir.", needsReview: true),
  Food(name: "Kara Erik", emoji: "🍑", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çekirdeği çıkarılıp kabuğu soyularak ezilir.", 9: "Çekirdeksiz yumuşak parçalar.", 12: "Çekirdeksiz, dörde bölünmüş."}, nutritionValues: {"Enerji": 46, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.2}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; çeyreklenir.", needsReview: true),
  Food(name: "Yaban Çileği", emoji: "🍓", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Olgun, yumuşak; ezilmiş.", 9: "Bütün yumuşak taneler.", 12: "Doğranmış olarak."}, nutritionValues: {"Enerji": 32, "Protein": 0.7, "Sağlıklı Yağ": 0.3, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Yumuşak ve ezilebilir.", needsReview: true),
  // Sebzeler
  Food(name: "Alabaş", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Soyulup pişirilir; püre.", 9: "Pişmiş yumuşak çubuklar veya rendelenmiş.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 27, "Protein": 1.7, "Sağlıklı Yağ": 0.1, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Soyulup pişirilir; çiğ verilirse rendelenir.", needsReview: true),
  Food(name: "Yaban Turpu", emoji: "🥬", category: "Sebze", startingMonth: 12, allergyRisk: "Düşük", presentationStyles: {6: "Çok keskin; önerilmez.", 9: "Önerilmez.", 12: "Çok az rendelenmiş, yemeğe aroma."}, nutritionValues: {"Enerji": 48, "Protein": 1.2, "Sağlıklı Yağ": 0.7, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Çok keskin; 12 ay+ uç miktar aroma olarak.", needsReview: true),
  Food(name: "Mor Patates", emoji: "🥔", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip ezilir (çiğ asla).", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 77, "Protein": 2.0, "Sağlıklı Yağ": 0.1, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "Çiğ ASLA; iyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Sarı Kabak", emoji: "🥒", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 16, "Protein": 1.2, "Sağlıklı Yağ": 0.2, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Hindiba", emoji: "🥬", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Acımsı; önerilmez.", 9: "Haşlanıp ince kıyılır.", 12: "Pişmiş ince doğranmış."}, nutritionValues: {"Enerji": 17, "Protein": 1.3, "Sağlıklı Yağ": 0.2, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "Haşlanıp ince kıyılır.", needsReview: true),
  Food(name: "Kestane Kabağı", emoji: "🎃", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip püre.", 9: "Pişmiş yumuşak küpler.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 45, "Protein": 1.0, "Sağlıklı Yağ": 0.1, "Demir": 0.7}, chokingRisk: "Düşük", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Spagetti Kabağı", emoji: "🎃", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip ezilir.", 9: "Pişmiş tel tel, ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 0.6, "Sağlıklı Yağ": 0.6, "Demir": 0.3}, chokingRisk: "Düşük", chokingNote: "Pişmiş telleri ince doğranır.", needsReview: true),
  Food(name: "Frenk Maydanozu", emoji: "🌿", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Kök pişirilip püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 55, "Protein": 2.0, "Sağlıklı Yağ": 0.6, "Demir": 0.8}, chokingRisk: "Orta", chokingNote: "Kök iyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Turp Filizi", emoji: "🌱", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İyice yıkanıp ince kıyılarak yemeğe.", 12: "İnce kıyılmış."}, nutritionValues: {"Enerji": 43, "Protein": 3.8, "Sağlıklı Yağ": 2.5, "Demir": 0.9}, chokingRisk: "Düşük", chokingNote: "İyice yıkanır; ince kıyılır.", needsReview: true),
  // Et / Balık / Süt
  Food(name: "Dana Dili", emoji: "🥩", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İyi pişmiş, ince dilimlenip ezilir.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 224, "Protein": 16.0, "Sağlıklı Yağ": 17.0, "Demir": 2.9}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ince doğranır/ezilir.", needsReview: true),
  Food(name: "Keklik", emoji: "🍗", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kemiksiz, iyi pişmiş; didiklenir.", 12: "Küçük doğranmış."}, nutritionValues: {"Enerji": 212, "Protein": 25.0, "Sağlıklı Yağ": 12.0, "Demir": 7.7}, chokingRisk: "Orta", chokingNote: "Küçük kemikleri dikkatle ayıklanır; didiklenir.", needsReview: true),
  Food(name: "Sülün", emoji: "🍗", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Kemiksiz, iyi pişmiş; didiklenir.", 12: "Küçük doğranmış."}, nutritionValues: {"Enerji": 181, "Protein": 25.0, "Sağlıklı Yağ": 9.0, "Demir": 1.4}, chokingRisk: "Orta", chokingNote: "Kemiksiz; didiklenir, suyuyla nemli.", needsReview: true),
  Food(name: "Tekir Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 123, "Protein": 19.0, "Sağlıklı Yağ": 4.4, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Sinarit Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 96, "Protein": 20.0, "Sağlıklı Yağ": 1.5, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "İstiridye", emoji: "🦪", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip çok ince doğranır (alerjen)."}, nutritionValues: {"Enerji": 81, "Protein": 9.0, "Sağlıklı Yağ": 2.3, "Demir": 5.1}, chokingRisk: "Orta", chokingNote: "Çiğ ASLA; alerjen — 12 ay+, iyi pişmiş ve ince doğranmış.", needsReview: true),
  Food(name: "Krem Peynir", emoji: "🧀", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Az tuzlu; ekmeğe ince sürülür.", 12: "Sürme olarak."}, nutritionValues: {"Enerji": 342, "Protein": 6.0, "Sağlıklı Yağ": 34.0, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Yumuşak/sürülebilir; düşük risk.", needsReview: true),
  Food(name: "Manda Yoğurdu", emoji: "🥛", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Tam yağlı, sade; kaşıkla.", 9: "Meyveyle karıştırılmış.", 12: "Sade/meyveli."}, nutritionValues: {"Enerji": 110, "Protein": 3.8, "Sağlıklı Yağ": 8.0, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Sade, şekersiz; düşük risk.", needsReview: true),
  Food(name: "Keçi Yoğurdu", emoji: "🥛", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Tam yağlı, sade; kaşıkla.", 9: "Meyveyle karıştırılmış.", 12: "Sade/meyveli."}, nutritionValues: {"Enerji": 70, "Protein": 3.6, "Sağlıklı Yağ": 4.0, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Sade, şekersiz; düşük risk.", needsReview: true),
  Food(name: "İnek Sütü", emoji: "🥛", category: "Diğer", startingMonth: 12, allergyRisk: "Orta", presentationStyles: {6: "İÇECEK olarak verilmez; yemekte az kullanılabilir.", 9: "İçecek olarak verilmez.", 12: "12 aydan sonra içecek olarak tam yağlı süt."}, nutritionValues: {"Enerji": 61, "Protein": 3.2, "Sağlıklı Yağ": 3.3, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "1 yaşından önce ANA İÇECEK olarak verilmez (yemekte az kullanılabilir).", needsReview: true),
  Food(name: "Kenevir Tohumu", emoji: "🌰", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kabuksuz iç (hemp hearts) pürelere serpilir.", 9: "Yoğurt/yulafa karıştırılmış.", 12: "Yemeklere serpiştirilmiş."}, nutritionValues: {"Enerji": 553, "Protein": 32.0, "Sağlıklı Yağ": 49.0, "Demir": 8.0}, chokingRisk: "Düşük", chokingNote: "Kabuksuz yumuşak iç; pürelere karıştırılır.", needsReview: true),
  // Tahıllar
  Food(name: "Esmer Pirinç", emoji: "🍚", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip lapa.", 9: "Yumuşak pişmiş, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 370, "Protein": 7.9, "Sağlıklı Yağ": 2.9, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilir; arsenik için tahıl çeşitlendirilir.", needsReview: true),
  Food(name: "Sorgum", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip lapa.", 9: "Yumuşak lapa, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 329, "Protein": 11.0, "Sağlıklı Yağ": 3.5, "Demir": 4.4}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  // Yağlar / Baharatlar
  Food(name: "Mısır Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişmiş yemeğe birkaç damla.", 9: "Yemeğe az.", 12: "Sıvı yağ olarak az."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Sıvı yağ; az miktar.", needsReview: true),
  Food(name: "Karanfil", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Bütün verilmez.", 9: "Öğütülmüş çok az, yemeğe.", 12: "Az miktar (öğütülmüş)."}, nutritionValues: {"Enerji": 274, "Protein": 6.0, "Sağlıklı Yağ": 13.0, "Demir": 11.8}, chokingRisk: "Yüksek", chokingNote: "Bütün karanfil VERİLMEZ (boğulma); öğütülmüş, az.", needsReview: true),
  Food(name: "Safran", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Birkaç tel; renk/aroma için.", 9: "Pilav/tatlıda birkaç tel.", 12: "Az miktar."}, nutritionValues: {"Enerji": 310, "Protein": 11.0, "Sağlıklı Yağ": 6.0, "Demir": 11.0}, chokingRisk: "Düşük", chokingNote: "Birkaç tel; çok az miktar.", needsReview: true),
  Food(name: "Biberiye", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İnce kıyılmış çok az, yemeğe.", 9: "Et/sebze yemeklerinde az.", 12: "Az miktar aroma."}, nutritionValues: {"Enerji": 131, "Protein": 3.3, "Sağlıklı Yağ": 5.9, "Demir": 6.6}, chokingRisk: "Orta", chokingNote: "Odunsu dalları çıkarılır; ince kıyılır.", needsReview: true),
  Food(name: "Adaçayı", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Çok az ince kıyılmış, yemeğe.", 9: "Yemeklerde az.", 12: "Az miktar aroma."}, nutritionValues: {"Enerji": 315, "Protein": 11.0, "Sağlıklı Yağ": 13.0, "Demir": 28.0}, chokingRisk: "Düşük", chokingNote: "Çok az; yoğun adaçayı çayından kaçınılır.", needsReview: true),
  Food(name: "Mercanköşk", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Bir tutam ufalanmış, yemeğe.", 9: "Yemeklerde az.", 12: "Az miktar aroma."}, nutritionValues: {"Enerji": 265, "Protein": 9.0, "Sağlıklı Yağ": 4.0, "Demir": 37.0}, chokingRisk: "Düşük", chokingNote: "Ufalanmış, çok az miktar.", needsReview: true),
  Food(name: "Hardal", emoji: "🌿", category: "Diğer", startingMonth: 9, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Çok az (hardal alerjeni), yemeğe.", 12: "Az miktar."}, nutritionValues: {"Enerji": 66, "Protein": 3.7, "Sağlıklı Yağ": 3.3, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "Hardal alerjeni; çok az miktar.", needsReview: true),
  Food(name: "Toz Tatlı Biber", emoji: "🌶️", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Acısız tatlı toz biber bir tutam.", 9: "Yemeklerde az.", 12: "Az miktar (acısız)."}, nutritionValues: {"Enerji": 282, "Protein": 14.0, "Sağlıklı Yağ": 13.0, "Demir": 21.0}, chokingRisk: "Düşük", chokingNote: "Acısız tatlı biber; çok az miktar.", needsReview: true),

  // ===== Parti 6: genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Turunç", emoji: "🍊", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çok ekşi/acı; önerilmez.", 9: "Genelde reçel; zar ve çekirdek ayıklanır.", 12: "Az miktar reçel/aroma."}, nutritionValues: {"Enerji": 50, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Zar ve çekirdekler ayıklanır.", needsReview: true),
  Food(name: "Klemantin", emoji: "🍊", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Zar ve çekirdekleri ayıklanıp ezilir.", 9: "Zarsız küçük parçalar.", 12: "Zarsız bölümler."}, nutritionValues: {"Enerji": 47, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.1}, chokingRisk: "Orta", chokingNote: "Zar ve çekirdekler ayıklanır.", needsReview: true),
  Food(name: "Longan", emoji: "🍒", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Çekirdeği çıkarılıp küçük parçalara bölünür.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 60, "Protein": 1.3, "Sağlıklı Yağ": 0.1, "Demir": 0.1}, chokingRisk: "Yüksek", chokingNote: "Çekirdek çıkarılır; kaygan/yuvarlak — küçük parçalara bölünür.", needsReview: true),
  Food(name: "Durian", emoji: "🍈", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Yumuşak iç ezilir; iri çekirdeği ayıklanır.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 147, "Protein": 1.5, "Sağlıklı Yağ": 5.3, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Büyük çekirdeği ayıklanır; yumuşak iç verilir.", needsReview: true),
  Food(name: "Salak", emoji: "🍈", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Kabuğu/çekirdeği ayıklanıp küçük parçalar.", 12: "Çekirdeksiz dilimler."}, nutritionValues: {"Enerji": 82, "Protein": 0.8, "Sağlıklı Yağ": 0.4, "Demir": 3.9}, chokingRisk: "Orta", chokingNote: "Sert çekirdek ayıklanır; küçük parçalara bölünür.", needsReview: true),
  Food(name: "Ravent", emoji: "🌿", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez; YAPRAKLARI TOKSİK.", 9: "Yalnız SAPI pişirilip ezilir (yaprak yenmez).", 12: "Pişmiş sap, az miktar."}, nutritionValues: {"Enerji": 21, "Protein": 0.9, "Sağlıklı Yağ": 0.2, "Demir": 0.2}, chokingRisk: "Orta", chokingNote: "YAPRAKLARI TOKSİK — yalnız sapı pişirilerek verilir.", needsReview: true),
  Food(name: "Nashi Armudu", emoji: "🍐", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Sert; pişirilip püre veya çok ince dilim.", 9: "Yumuşak ince dilimler/rendelenmiş.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 42, "Protein": 0.5, "Sağlıklı Yağ": 0.2, "Demir": 0.0}, chokingRisk: "Orta", chokingNote: "Sert/sulu; çiğse rendelenir veya pişirilir.", needsReview: true),
  // Sebzeler
  Food(name: "Arpacık Soğan", emoji: "🧅", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce doğranıp pişirilerek yemeğe.", 12: "Pişmiş, ince doğranmış."}, nutritionValues: {"Enerji": 72, "Protein": 2.5, "Sağlıklı Yağ": 0.1, "Demir": 1.2}, chokingRisk: "Düşük", chokingNote: "İnce doğranıp pişirilir.", needsReview: true),
  Food(name: "İstiridye Mantarı", emoji: "🍄", category: "Sebze", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 33, "Protein": 3.3, "Sağlıklı Yağ": 0.4, "Demir": 1.3}, chokingRisk: "Orta", chokingNote: "Çiğ verilmez; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Shiitake Mantarı", emoji: "🍄", category: "Sebze", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Sert sapı çıkarılıp iyice pişirilir, ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 34, "Protein": 2.2, "Sağlıklı Yağ": 0.5, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Sert sapı çıkarılır; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Bambu Filizi", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ verilmez (toksik).", 9: "MUTLAKA pişirilir; ince doğranır.", 12: "Pişmiş ince doğranmış."}, nutritionValues: {"Enerji": 27, "Protein": 2.6, "Sağlıklı Yağ": 0.3, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "ÇİĞ TOKSİK — mutlaka iyice pişirilir; ince doğranır.", needsReview: true),
  Food(name: "Su Kestanesi", emoji: "🌰", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Sert; önerilmez.", 9: "Pişirilip çok ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 97, "Protein": 1.4, "Sağlıklı Yağ": 0.1, "Demir": 0.1}, chokingRisk: "Yüksek", chokingNote: "Sert/yuvarlak; pişirilip çok ince doğranır.", needsReview: true),
  Food(name: "Brokolini", emoji: "🥦", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilip ezilir veya yumuşak başçık (parmak gıdası).", 9: "Pişmiş, ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 35, "Protein": 3.7, "Sağlıklı Yağ": 0.4, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "İyice pişirilip yumuşatılır; sap ince doğranır.", needsReview: true),
  Food(name: "Pancar Yaprağı", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 22, "Protein": 2.2, "Sağlıklı Yağ": 0.1, "Demir": 2.6}, chokingRisk: "Orta", chokingNote: "İyice pişirilip ince doğranır (nitrat — ölçülü).", needsReview: true),
  // Et / Balık / Yumurta / Süt
  Food(name: "Ördek Eti", emoji: "🍗", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Derisiz, iyi pişmiş; didiklenir/püre.", 9: "Didiklenmiş, suyuyla nemli.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 337, "Protein": 19.0, "Sağlıklı Yağ": 28.0, "Demir": 2.7}, chokingRisk: "Orta", chokingNote: "Derisi alınır; lif lif didiklenir.", needsReview: true),
  Food(name: "Kaz Eti", emoji: "🍗", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Derisiz, iyi pişmiş; didiklenir.", 12: "Küçük doğranmış."}, nutritionValues: {"Enerji": 305, "Protein": 25.0, "Sağlıklı Yağ": 22.0, "Demir": 2.8}, chokingRisk: "Orta", chokingNote: "Derisi alınır; didiklenir.", needsReview: true),
  Food(name: "Ördek Yumurtası", emoji: "🥚", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "TAM PİŞMİŞ; ezilmiş (yumurta alerjeni).", 9: "Tam pişmiş, küçük parçalar.", 12: "Omlet/haşlama küçük parçalar."}, nutritionValues: {"Enerji": 185, "Protein": 13.0, "Sağlıklı Yağ": 14.0, "Demir": 3.9}, chokingRisk: "Düşük", chokingNote: "Tam pişmiş verilir; alerjen olarak erken tanıştırılır.", needsReview: true),
  Food(name: "Kaz Yumurtası", emoji: "🥚", category: "Diğer", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "TAM PİŞMİŞ; ezilmiş (yumurta alerjeni).", 9: "Tam pişmiş, küçük parçalar.", 12: "Omlet/haşlama küçük parçalar."}, nutritionValues: {"Enerji": 185, "Protein": 14.0, "Sağlıklı Yağ": 13.0, "Demir": 3.6}, chokingRisk: "Düşük", chokingNote: "Tam pişmiş verilir; alerjen.", needsReview: true),
  Food(name: "Kolyoz", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 158, "Protein": 19.0, "Sağlıklı Yağ": 9.0, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Karagöz Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 96, "Protein": 20.0, "Sağlıklı Yağ": 1.5, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Ahtapot", emoji: "🐙", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip çok ince doğranır (sert + alerjen)."}, nutritionValues: {"Enerji": 82, "Protein": 15.0, "Sağlıklı Yağ": 1.0, "Demir": 5.3}, chokingRisk: "Yüksek", chokingNote: "Lastiksi/sert; alerjen — 12 ay+, çok ince doğranır.", needsReview: true),
  Food(name: "Deniz Tarağı", emoji: "🦪", category: "Balık", startingMonth: 24, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip çok ince doğranır (alerjen)."}, nutritionValues: {"Enerji": 86, "Protein": 15.0, "Sağlıklı Yağ": 1.0, "Demir": 14.0}, chokingRisk: "Orta", chokingNote: "Çiğ ASLA; alerjen — 12 ay+, iyi pişmiş, ince doğranmış.", needsReview: true),
  Food(name: "Keçi Sütü", emoji: "🥛", category: "Diğer", startingMonth: 12, allergyRisk: "Orta", presentationStyles: {6: "İçecek olarak verilmez; yemekte az.", 9: "İçecek olarak verilmez.", 12: "12 aydan sonra içecek olarak."}, nutritionValues: {"Enerji": 69, "Protein": 3.6, "Sağlıklı Yağ": 4.1, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "1 yaşından önce ana içecek olarak verilmez.", needsReview: true),
  Food(name: "Koyun Sütü", emoji: "🥛", category: "Diğer", startingMonth: 12, allergyRisk: "Orta", presentationStyles: {6: "İçecek olarak verilmez; yemekte az.", 9: "İçecek olarak verilmez.", 12: "12 aydan sonra içecek olarak."}, nutritionValues: {"Enerji": 108, "Protein": 5.4, "Sağlıklı Yağ": 7.0, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "1 yaşından önce ana içecek olarak verilmez.", needsReview: true),
  Food(name: "Hellim", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzu giderilip (haşlama) küçük yumuşak parça.", 12: "Az tuzlu, küçük parça."}, nutritionValues: {"Enerji": 321, "Protein": 22.0, "Sağlıklı Yağ": 25.0, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Çok tuzlu; haşlanarak tuzu azaltılır, küçük parça.", needsReview: true),
  Food(name: "Mihaliç Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzu giderilmiş, rendelenmiş/küçük parça.", 12: "Az tuzlu, küçük parça."}, nutritionValues: {"Enerji": 330, "Protein": 24.0, "Sağlıklı Yağ": 26.0, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Tuzlu/sert; rendelenir, tuzu azaltılır.", needsReview: true),
  Food(name: "Lüpen", emoji: "🫘", category: "Diğer", startingMonth: 9, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "İyice ıslatılıp pişirilmiş, kabuğu alınıp ezilir (alerjen).", 12: "Kabuksuz, ezilmiş."}, nutritionValues: {"Enerji": 371, "Protein": 36.0, "Sağlıklı Yağ": 9.7, "Demir": 4.4}, chokingRisk: "Orta", chokingNote: "Lüpen alerjeni; iyice işlenmiş, kabuğu alınıp ezilir.", needsReview: true),
  Food(name: "Yer Fıstığı Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Pişmiş yemeğe birkaç damla.", 9: "Yemeğe az.", 12: "Sıvı yağ olarak az."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Sıvı yağ; az miktar (fıstık alerjisi öyküsünde dikkat).", needsReview: true),
  Food(name: "Karpuz Çekirdeği", emoji: "🍉", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Bütün verilmez.", 9: "Öğütülmüş/kavrulmuş iç çok az.", 12: "Toz/ezme olarak."}, nutritionValues: {"Enerji": 557, "Protein": 28.0, "Sağlıklı Yağ": 47.0, "Demir": 7.3}, chokingRisk: "Yüksek", chokingNote: "Bütün VERİLMEZ; öğütülmüş/ezme olarak.", needsReview: true),
  // Un / Tahıl
  Food(name: "Nohut Unu", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişirilerek (çiğ verilmez) çorba/krepte.", 9: "Sebzeli kreplerde.", 12: "Köfte/börekte."}, nutritionValues: {"Enerji": 387, "Protein": 22.0, "Sağlıklı Yağ": 6.7, "Demir": 4.9}, chokingRisk: "Düşük", chokingNote: "Çiğ verilmez; mutlaka pişirilir.", needsReview: true),
  Food(name: "Badem Unu", emoji: "🌰", category: "Tahıl", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Hamur işlerinde pişirilerek (ağaç yemişi alerjeni).", 9: "Kek/krepte.", 12: "Tatlı/hamur işinde."}, nutritionValues: {"Enerji": 571, "Protein": 21.0, "Sağlıklı Yağ": 50.0, "Demir": 3.7}, chokingRisk: "Düşük", chokingNote: "Ağaç yemişi alerjeni; pişmiş hamur işinde.", needsReview: true),
  Food(name: "Hindistan Cevizi Unu", emoji: "🥥", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Hamur işlerinde pişirilerek.", 9: "Kek/krepte.", 12: "Tatlı/hamur işinde."}, nutritionValues: {"Enerji": 400, "Protein": 19.0, "Sağlıklı Yağ": 14.0, "Demir": 3.3}, chokingRisk: "Düşük", chokingNote: "Çok sıvı çeker; hamurda pişirilerek kullanılır.", needsReview: true),
  Food(name: "Lavaş", emoji: "🫓", category: "Tahıl", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Hafif kurutulmuş ince parçalar (gluten).", 12: "Küçük lokmalar/dürüm içi az."}, nutritionValues: {"Enerji": 275, "Protein": 8.0, "Sağlıklı Yağ": 1.0, "Demir": 2.5}, chokingRisk: "Orta", chokingNote: "Taze yumuşak ekmek topaklanır; hafif kurutulmuş, küçük parça.", needsReview: true),
  // Baharat / Diğer
  Food(name: "Kakule", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Öğütülmüş bir tutam, tatlandırmak için.", 9: "Muhallebi/yulafta az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 311, "Protein": 11.0, "Sağlıklı Yağ": 7.0, "Demir": 14.0}, chokingRisk: "Orta", chokingNote: "Bütün kapsül verilmez; öğütülmüş, az.", needsReview: true),
  Food(name: "Çemen", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Öğütülmüş çok az, yemeğe.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 323, "Protein": 23.0, "Sağlıklı Yağ": 6.4, "Demir": 33.0}, chokingRisk: "Düşük", chokingNote: "Öğütülmüş, çok az miktar.", needsReview: true),
  Food(name: "Kişniş Tohumu", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Öğütülmüş bir tutam, yemeğe.", 9: "Yemeklerde az.", 12: "Az miktar baharat."}, nutritionValues: {"Enerji": 298, "Protein": 12.0, "Sağlıklı Yağ": 18.0, "Demir": 16.0}, chokingRisk: "Orta", chokingNote: "Bütün tane verilmez; öğütülmüş olarak.", needsReview: true),
  Food(name: "Tarhun", emoji: "🌿", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Taze, ince kıyılmış çok az.", 9: "Yemeklerde az.", 12: "Az miktar aroma."}, nutritionValues: {"Enerji": 295, "Protein": 23.0, "Sağlıklı Yağ": 7.0, "Demir": 32.0}, chokingRisk: "Düşük", chokingNote: "İnce kıyılır; çok az miktar.", needsReview: true),
  Food(name: "Limon Otu", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Lifli; yenmez, pişirmede aroma.", 9: "Aroma için eklenir, SERVİSTEN ÖNCE çıkarılır.", 12: "Yenmez, çıkarılır."}, nutritionValues: {"Enerji": 99, "Protein": 1.8, "Sağlıklı Yağ": 0.5, "Demir": 8.2}, chokingRisk: "Yüksek", chokingNote: "Lifli/odunsu — YENMEZ, pişirmeden sonra çıkarılır.", needsReview: true),
  Food(name: "Yıldız Anason", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Bütün verilmez.", 9: "Pişirmede aroma, SERVİSTEN ÖNCE çıkarılır.", 12: "Öğütülmüş az miktar."}, nutritionValues: {"Enerji": 337, "Protein": 18.0, "Sağlıklı Yağ": 16.0, "Demir": 37.0}, chokingRisk: "Yüksek", chokingNote: "Sert yıldız — bütün YENMEZ, çıkarılır; öğütülmüş az.", needsReview: true),
  Food(name: "Hindistan Cevizi Sütü", emoji: "🥥", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Şekersiz, yemek pişirmede az.", 9: "Sebze/tatlıda az.", 12: "Yemeklerde az miktar."}, nutritionValues: {"Enerji": 230, "Protein": 2.3, "Sağlıklı Yağ": 24.0, "Demir": 1.6}, chokingRisk: "Düşük", chokingNote: "Şekersiz; yemekte az miktar (anne sütü/formül yerine geçmez).", needsReview: true),

  // ===== Parti 7 (final): genişletme (standart veri, UZMAN ONAYI BEKLİYOR) =====
  // Meyveler
  Food(name: "Cherimoya", emoji: "🍈", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yumuşak iç; TÜM çekirdekler ayıklanıp ezilir.", 9: "Çekirdeksiz yumuşak parçalar.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 75, "Protein": 1.6, "Sağlıklı Yağ": 0.7, "Demir": 0.3}, chokingRisk: "Yüksek", chokingNote: "Siyah çekirdekleri TOKSİK — hepsi mutlaka ayıklanır.", needsReview: true),
  Food(name: "Jakfruit", emoji: "🍈", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Olgun yumuşak dilimler, çekirdekleri ayıklanır.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 95, "Protein": 1.7, "Sağlıklı Yağ": 0.6, "Demir": 0.2}, chokingRisk: "Orta", chokingNote: "Çekirdekleri ayıklanır; olgun/yumuşak verilir.", needsReview: true),
  Food(name: "Feijoa", emoji: "🥝", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İç kısmı kaşıkla çıkarılıp ezilir.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 55, "Protein": 0.7, "Sağlıklı Yağ": 0.4, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Yumuşak iç kısım; kabuğu yenmez.", needsReview: true),
  Food(name: "Tamarillo", emoji: "🍅", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Kabuğu soyulup içi ezilir.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 2.0, "Sağlıklı Yağ": 0.4, "Demir": 0.6}, chokingRisk: "Orta", chokingNote: "Kabuğu soyulur; çekirdekli iç ezilir.", needsReview: true),
  Food(name: "Kivano", emoji: "🍈", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Jel/çekirdekli iç ezilir; sert kabuk yenmez.", 12: "İç kısmı kaşıkla."}, nutritionValues: {"Enerji": 44, "Protein": 1.8, "Sağlıklı Yağ": 1.3, "Demir": 1.1}, chokingRisk: "Orta", chokingNote: "Sert kabuk yenmez; çekirdekli jel ezilir.", needsReview: true),
  Food(name: "Kuru Vişne", emoji: "🍒", category: "Meyve", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Yapışkan/sert; önerilmez.", 9: "Çekirdeksiz olanı suda yumuşatılıp ince doğranır.", 12: "İnce doğranmış olarak."}, nutritionValues: {"Enerji": 330, "Protein": 1.5, "Sağlıklı Yağ": 1.5, "Demir": 2.0}, chokingRisk: "Yüksek", chokingNote: "Çekirdeksiz olanı; yapışkan — yumuşatılıp ince doğranır.", needsReview: true),
  Food(name: "Lucuma", emoji: "🍈", category: "Meyve", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Yumuşak iç ezilir veya toz olarak pürelere.", 9: "Yoğurt/pürelere karıştırılmış.", 12: "Küçük parçalar/toz."}, nutritionValues: {"Enerji": 99, "Protein": 2.0, "Sağlıklı Yağ": 0.5, "Demir": 1.0}, chokingRisk: "Düşük", chokingNote: "Yumuşak pulp; düşük risk.", needsReview: true),
  Food(name: "Sapota", emoji: "🍈", category: "Meyve", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Olgun yumuşak; iri çekirdekleri ayıklanıp ezilir.", 12: "Çekirdeksiz küçük parçalar."}, nutritionValues: {"Enerji": 83, "Protein": 0.4, "Sağlıklı Yağ": 1.1, "Demir": 0.8}, chokingRisk: "Yüksek", chokingNote: "Büyük siyah çekirdekleri mutlaka ayıklanır.", needsReview: true),
  // Sebzeler
  Food(name: "Maniok", emoji: "🥔", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ TOKSİK; önerilmez.", 9: "Soyulup iyice pişirilir; ezilir.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 160, "Protein": 1.4, "Sağlıklı Yağ": 0.3, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "ÇİĞ TOKSİK — soyulup iyice pişirilir, ezilir.", needsReview: true),
  Food(name: "Taro", emoji: "🥔", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Çiğ tahriş edici; önerilmez.", 9: "Soyulup iyice pişirilir; ezilir.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 112, "Protein": 1.5, "Sağlıklı Yağ": 0.2, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "ÇİĞ verilmez — mutlaka iyice pişirilir, ezilir.", needsReview: true),
  Food(name: "Lotus Kökü", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İyice pişirilip çok ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 74, "Protein": 2.6, "Sağlıklı Yağ": 0.1, "Demir": 1.2}, chokingRisk: "Orta", chokingNote: "Lifli/sert; iyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Su Ispanağı", emoji: "🥬", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip ezilir.", 9: "Pişmiş ince doğranmış.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 19, "Protein": 2.6, "Sağlıklı Yağ": 0.2, "Demir": 1.7}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip ince doğranır.", needsReview: true),
  Food(name: "Yeşil Sarımsak", emoji: "🧄", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce doğranıp pişirilerek yemeğe.", 12: "Pişmiş, ince doğranmış."}, nutritionValues: {"Enerji": 41, "Protein": 1.8, "Sağlıklı Yağ": 0.2, "Demir": 1.0}, chokingRisk: "Düşük", chokingNote: "İnce doğranıp pişirilir.", needsReview: true),
  Food(name: "Kuzu Göbeği Mantarı", emoji: "🍄", category: "Sebze", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Çiğ toksik; önerilmez.", 9: "MUTLAKA iyice pişirilir; ince doğranır.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 31, "Protein": 3.1, "Sağlıklı Yağ": 0.6, "Demir": 12.0}, chokingRisk: "Orta", chokingNote: "ÇİĞ TOKSİK — mutlaka iyice pişirilir; ince doğranır.", needsReview: true),
  Food(name: "Kenger", emoji: "🌿", category: "Sebze", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Dikenleri temizlenip iyice pişirilir; ince kıyılır.", 12: "Pişmiş ince doğranmış."}, nutritionValues: {"Enerji": 20, "Protein": 1.0, "Sağlıklı Yağ": 0.1, "Demir": 0.7}, chokingRisk: "Orta", chokingNote: "Dikenleri temizlenir; iyice pişirilip ince kıyılır.", needsReview: true),
  Food(name: "Çin Kabağı", emoji: "🥒", category: "Sebze", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Soyulup pişirilir; püre.", 9: "Pişmiş yumuşak çubuklar.", 12: "Pişmiş küçük parçalar."}, nutritionValues: {"Enerji": 13, "Protein": 0.4, "Sağlıklı Yağ": 0.2, "Demir": 0.4}, chokingRisk: "Düşük", chokingNote: "Pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Yaban Pırasası", emoji: "🌿", category: "Sebze", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "İnce doğranıp pişirilerek yemeğe.", 12: "Pişmiş, ince doğranmış."}, nutritionValues: {"Enerji": 61, "Protein": 1.5, "Sağlıklı Yağ": 0.3, "Demir": 1.2}, chokingRisk: "Düşük", chokingNote: "İnce doğranıp pişirilir.", needsReview: true),
  // Et / Balık / Süt
  Food(name: "Geyik Eti", emoji: "🍖", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Yağsız; nemli pişirilip didiklenir.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 158, "Protein": 30.0, "Sağlıklı Yağ": 3.2, "Demir": 4.5}, chokingRisk: "Orta", chokingNote: "Yağsız ve kuru olabilir; suyuyla nemli, didiklenir.", needsReview: true),
  Food(name: "Dana Yürek", emoji: "🥩", category: "Et", startingMonth: 8, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İyi pişmiş, ince doğranıp ezilir.", 12: "Küçük doğranmış parçalar."}, nutritionValues: {"Enerji": 112, "Protein": 17.0, "Sağlıklı Yağ": 3.9, "Demir": 4.3}, chokingRisk: "Orta", chokingNote: "İyi pişirilip ince doğranır/ezilir.", needsReview: true),
  Food(name: "Orfoz", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 92, "Protein": 19.4, "Sağlıklı Yağ": 1.0, "Demir": 0.9}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Trança Balığı", emoji: "🐟", category: "Balık", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Kılçığı ayıklanıp ezilir.", 9: "Ezilmiş, sebzeyle.", 12: "Küçük parçalar."}, nutritionValues: {"Enerji": 96, "Protein": 20.0, "Sağlıklı Yağ": 1.5, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Kılçıkları dikkatle ayıklanır.", needsReview: true),
  Food(name: "Istakoz", emoji: "🦞", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip didiklenir (alerjen)."}, nutritionValues: {"Enerji": 89, "Protein": 19.0, "Sağlıklı Yağ": 0.9, "Demir": 0.3}, chokingRisk: "Orta", chokingNote: "Çiğ ASLA; alerjen — 12 ay+, iyi pişmiş, didiklenmiş.", needsReview: true),
  Food(name: "Sübye", emoji: "🦑", category: "Balık", startingMonth: 12, allergyRisk: "Yüksek", presentationStyles: {6: "Önerilmez.", 9: "Önerilmez.", 12: "İyice pişirilip çok ince doğranır (sert + alerjen)."}, nutritionValues: {"Enerji": 79, "Protein": 16.0, "Sağlıklı Yağ": 0.7, "Demir": 6.0}, chokingRisk: "Yüksek", chokingNote: "Lastiksi/sert; alerjen — 12 ay+, çok ince doğranır.", needsReview: true),
  Food(name: "Otlu Peynir", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzu giderilmiş, küçük yumuşak parça.", 12: "Az tuzlu, küçük parça."}, nutritionValues: {"Enerji": 300, "Protein": 20.0, "Sağlıklı Yağ": 23.0, "Demir": 0.5}, chokingRisk: "Orta", chokingNote: "Tuzlu; ılık suda bekletilip tuzu azaltılır, küçük parça.", needsReview: true),
  Food(name: "Çeçil Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "İnce tellere ayrılıp küçük parça.", 12: "İnce teller halinde."}, nutritionValues: {"Enerji": 313, "Protein": 25.0, "Sağlıklı Yağ": 25.0, "Demir": 0.5}, chokingRisk: "Yüksek", chokingNote: "Tel tel/elastik; ince tellere ayrılır (yapışma/boğulma).", needsReview: true),
  Food(name: "Yörük Peyniri", emoji: "🧀", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Tuzu giderilmiş, küçük parça.", 12: "Az tuzlu, küçük parça."}, nutritionValues: {"Enerji": 270, "Protein": 18.0, "Sağlıklı Yağ": 21.0, "Demir": 0.4}, chokingRisk: "Orta", chokingNote: "Tuzu azaltılır; küçük yumuşak parça.", needsReview: true),
  Food(name: "Manda Sütü", emoji: "🥛", category: "Diğer", startingMonth: 12, allergyRisk: "Orta", presentationStyles: {6: "İçecek olarak verilmez; yemekte az.", 9: "İçecek olarak verilmez.", 12: "12 aydan sonra içecek olarak."}, nutritionValues: {"Enerji": 97, "Protein": 3.8, "Sağlıklı Yağ": 6.9, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "1 yaşından önce ana içecek olarak verilmez.", needsReview: true),
  Food(name: "Krema", emoji: "🥛", category: "Diğer", startingMonth: 9, allergyRisk: "Orta", presentationStyles: {6: "Önerilmez.", 9: "Yemek pişirmede az miktar.", 12: "Az miktar (yüksek yağ)."}, nutritionValues: {"Enerji": 340, "Protein": 2.8, "Sağlıklı Yağ": 36.0, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Yumuşak; az miktarda (yüksek yağ).", needsReview: true),
  Food(name: "Skyr", emoji: "🥛", category: "Diğer", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Sade, tam yağlı; kaşıkla.", 9: "Meyveyle karıştırılmış.", 12: "Sade/meyveli."}, nutritionValues: {"Enerji": 63, "Protein": 11.0, "Sağlıklı Yağ": 0.2, "Demir": 0.1}, chokingRisk: "Düşük", chokingNote: "Sade, şekersiz; düşük risk.", needsReview: true),
  // Un / Nişasta
  Food(name: "Yulaf Unu", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Lapa/muhallebi olarak pişirilir.", 9: "Meyveli lapa.", 12: "Hamur işinde."}, nutritionValues: {"Enerji": 404, "Protein": 15.0, "Sağlıklı Yağ": 9.1, "Demir": 4.0}, chokingRisk: "Düşük", chokingNote: "Pişirilerek lapa/hamur işinde.", needsReview: true),
  Food(name: "Çavdar Unu", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Lapa veya pişmiş hamur işinde (gluten).", 9: "Çavdar ekmeği/krepte.", 12: "Hamur işinde."}, nutritionValues: {"Enerji": 325, "Protein": 8.4, "Sağlıklı Yağ": 1.8, "Demir": 2.5}, chokingRisk: "Düşük", chokingNote: "Pişirilerek kullanılır.", needsReview: true),
  Food(name: "Karabuğday Unu", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Lapa/krep olarak pişirilir (glutensiz).", 9: "Meyveli lapa/krep.", 12: "Hamur işinde."}, nutritionValues: {"Enerji": 335, "Protein": 12.6, "Sağlıklı Yağ": 3.1, "Demir": 4.1}, chokingRisk: "Düşük", chokingNote: "Pişirilerek kullanılır.", needsReview: true),
  Food(name: "Buğday Nişastası", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Muhallebi/sos kıvam vericisi olarak pişirilir (gluten).", 9: "Meyveli muhallebi.", 12: "Tatlı/sos kıvam vericisi."}, nutritionValues: {"Enerji": 381, "Protein": 0.5, "Sağlıklı Yağ": 0.1, "Demir": 0.5}, chokingRisk: "Düşük", chokingNote: "Pişirilerek kıvam verici olarak kullanılır.", needsReview: true),
  // Yağ / Tatlandırıcı / Diğer
  Food(name: "Aspir Yağı", emoji: "🫗", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "Pişmiş yemeğe birkaç damla.", 9: "Yemeğe az.", 12: "Sıvı yağ olarak az."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Sıvı yağ; az miktar.", needsReview: true),
  Food(name: "Hindistan Cevizi Rendesi", emoji: "🥥", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Kuru/dağılgan; önerilmez.", 9: "Nemli yemeğe/yoğurda ince serpilmiş.", 12: "Tatlı/yoğurda serpilmiş."}, nutritionValues: {"Enerji": 660, "Protein": 6.9, "Sağlıklı Yağ": 65.0, "Demir": 3.3}, chokingRisk: "Orta", chokingNote: "Kuru ince rende boğazda toplanabilir; nemli gıdaya karıştırılır.", needsReview: true),
  Food(name: "Gül Suyu", emoji: "🌹", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Gıda kalitesinde birkaç damla aroma.", 12: "Tatlılarda az miktar."}, nutritionValues: {"Enerji": 1, "Protein": 0.0, "Sağlıklı Yağ": 0.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Gıda kalitesinde olanı; birkaç damla aroma.", needsReview: true),
  Food(name: "Çörek Otu Yağı", emoji: "🫗", category: "Diğer", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Birkaç damla yemeğe (güçlü aroma).", 12: "Az miktar."}, nutritionValues: {"Enerji": 884, "Protein": 0.0, "Sağlıklı Yağ": 100.0, "Demir": 0.0}, chokingRisk: "Düşük", chokingNote: "Güçlü; çok az miktar (birkaç damla).", needsReview: true),
  Food(name: "Hurma Ezmesi", emoji: "🫘", category: "Diğer", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Doğal tatlandırıcı; az miktar, sürme.", 12: "Tatlılarda az miktar."}, nutritionValues: {"Enerji": 280, "Protein": 2.5, "Sağlıklı Yağ": 0.4, "Demir": 1.0}, chokingRisk: "Orta", chokingNote: "Yapışkan; ince sürülür, az miktar (doğal şeker yüksek).", needsReview: true),
  Food(name: "Nar Ekşisi", emoji: "🫗", category: "Diğer", startingMonth: 9, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Ekşilik için yemeğe birkaç damla.", 12: "Az miktar."}, nutritionValues: {"Enerji": 280, "Protein": 1.5, "Sağlıklı Yağ": 0.0, "Demir": 1.5}, chokingRisk: "Düşük", chokingNote: "Şekersiz/katkısız olanı; az miktar.", needsReview: true),
  Food(name: "Besin Mayası", emoji: "🌿", category: "Diğer", startingMonth: 8, allergyRisk: "Düşük", presentationStyles: {6: "Önerilmez.", 9: "Yemeğe/püreye az miktar serpilir (B12 kaynağı).", 12: "Yemeklere serpiştirilmiş."}, nutritionValues: {"Enerji": 325, "Protein": 50.0, "Sağlıklı Yağ": 4.5, "Demir": 5.0}, chokingRisk: "Düşük", chokingNote: "Pul/toz; yemeğe serpilir.", needsReview: true),

  // ===== Ek tahıllar (talep üzerine) — standart veri + needsReview =====
  Food(name: "Siyez Bulguru", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyice pişirilip yumuşak lapa/püre (gluten).", 9: "Yumuşak pişmiş, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 340, "Protein": 12.0, "Sağlıklı Yağ": 2.0, "Demir": 3.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Firik Bulguru", emoji: "🌾", category: "Tahıl", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "İyice pişirilip yumuşak lapa/püre (gluten).", 9: "Yumuşak pişmiş, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 352, "Protein": 14.0, "Sağlıklı Yağ": 2.7, "Demir": 4.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır.", needsReview: true),
  Food(name: "Basmati Pirinç", emoji: "🍚", category: "Tahıl", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "İyice pişirilip yumuşak lapa/püre.", 9: "Yumuşak pişmiş, sebzeyle.", 12: "Pilav kıvamında."}, nutritionValues: {"Enerji": 360, "Protein": 7.5, "Sağlıklı Yağ": 0.6, "Demir": 0.5}, chokingRisk: "Düşük", chokingNote: "İyice pişirilip yumuşatılır; arsenik için tahıl çeşitlendirilir.", needsReview: true),
  Food(name: "Kuzu Kıyma", emoji: "🥩", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Yağsız kıyma iyice pişirilip ezilir/püre (demir kaynağı).", 9: "Suyuyla yumuşatılmış, ufalanmış köfte/parçalar.", 12: "Küçük köfteler/doğranmış parçalar."}, nutritionValues: {"Enerji": 282, "Protein": 25.0, "Sağlıklı Yağ": 20.0, "Demir": 1.6}, chokingRisk: "Orta", chokingNote: "Kuru kalmaması için suyuyla; iyice pişmiş ve ufalanmış olmalı.", needsReview: true),
  Food(name: "Yumurta", emoji: "🥚", category: "Et", startingMonth: 6, allergyRisk: "Yüksek", presentationStyles: {6: "Tamamen pişmiş (sarısı+beyazı katı); ezilip püre ya da yumuşak omlet şeritleri.", 9: "İyi pişmiş omlet/menemen parçaları, küçük lokmalar.", 12: "Haşlanmış yumurta dilimleri, omlet, menemen."}, nutritionValues: {"Enerji": 155, "Protein": 13.0, "Sağlıklı Yağ": 11.0, "Demir": 1.2}, gramsPerPiece: 50, chokingRisk: "Düşük", chokingNote: "Yumurtayı iyice pişirin (salmonella riski); yüksek alerjen olduğu için tek başına ve azar azar tanıtın.", needsReview: true),
  Food(name: "Su", emoji: "💧", category: "Diğer", startingMonth: 6, allergyRisk: "Düşük", presentationStyles: {6: "6. aydan itibaren ek gıdayla birlikte günde birkaç yudum (açık bardak/şişe).", 9: "Öğünlerle birlikte küçük yudumlar; açık bardak alıştırması.", 12: "İhtiyaca göre, açık bardaktan serbestçe."}, nutritionValues: {"Enerji": 0, "Protein": 0.0, "Sağlıklı Yağ": 0.0, "Demir": 0.0}, cartUnit: "lt", chokingRisk: "Düşük", chokingNote: "6 aydan önce su verilmez; az miktarda ve gözetim altında.", needsReview: true),
  Food(name: "Kuzu İlikli Kemik Suyu", emoji: "🍲", category: "Et", startingMonth: 6, allergyRisk: "Orta", presentationStyles: {6: "Tuzsuz, iyice süzülmüş kemik suyu; püre ve çorbaları sulandırmak için pişirme sıvısı olarak.", 9: "Sebze/tahıl yemeklerinde pişirme suyu; çorbalarda.", 12: "Çorba ve yemeklerde tuzsuz pişirme sıvısı."}, nutritionValues: {"Enerji": 38, "Protein": 6.0, "Sağlıklı Yağ": 1.0, "Demir": 0.3}, cartUnit: "lt", chokingRisk: "Düşük", chokingNote: "Tuz eklemeyin; iyice süzüp kemik/kıkırdak parçası kalmadığından emin olun.", needsReview: true),
];

// Mock Baby Recipes Database
List<Recipe> _generateAllRecipes() {
  final List<Recipe> recipes = [
    Recipe(
      id: "r1",
      name: "Balkabağı ve Havuç Püresi",
      prepTime: "15 dk",
      startingMonth: 6,
      kcal: 85,
      imageUrl: "",
      ingredients: ["Balkabağı", "Havuç", "Zeytinyağı"],
      ingredientAmounts: ["100 gr", "1 adet orta boy", "1 tatlı kaşığı"],
      steps: [
        "Balkabağı ve havucu küp küp doğrayın.",
        "Küçük bir tencerede sebzeler yumuşayana kadar haşlayın. (Yaklaşık 10-12 dakika)",
        "Haşlanan sebzeleri pürüzsüz olana kadar blenderdan geçirin veya çatalla ezin.",
        "Son olarak üzerine zeytinyağını ekleyip karıştırın ve ılık servis edin."
      ],
      allergyWarning: "Bu tarif havuç içerir. Bebeğinizin havuç alerjisi varsa lütfen doktorunuza danışın.",
    ),
    Recipe(
      id: "r2",
      name: "Sebzeli Bebek Omleti",
      prepTime: "10 dk",
      startingMonth: 8,
      kcal: 120,
      imageUrl: "",
      ingredients: ["Yumurta Sarısı", "Brokoli", "Lor Peyniri", "Tereyağı"],
      ingredientAmounts: ["1 adet", "2-3 küçük çiçek", "1 yemek kaşığı", "1 çay kaşığı"],
      steps: [
        "Brokoliyi buharda iyice yumuşayana kadar haşlayın ve ince ince kıyın.",
        "Bir kasede yumurta sarısı, haşlanmış brokoli ve lor peynirini iyice çırpın.",
        "Tavada tereyağını eritin ve hazırladığınız omlet harcını dökün.",
        "Arkalı önlü kısık ateşte iyice pişene kadar pişirin ve ılındıktan sonra parmak gıda olarak sunun."
      ],
      allergyWarning: "Bu tarif yumurta sarısı ve lor peyniri (süt ürünü) içerir. Alerji geçmişi varsa dikkat ediniz.",
    ),
    Recipe(
      id: "r3",
      name: "Avokadolu Muzlu Püre",
      prepTime: "5 dk",
      startingMonth: 6,
      kcal: 145,
      imageUrl: "",
      ingredients: ["Avokado", "Muz", "Ihlamur Çayı"],
      ingredientAmounts: ["1/2 adet olgun", "1/2 adet", "1 yemek kaşığı"],
      steps: [
        "Olgun avokadonun içini kaşıkla çıkarın.",
        "Muzu soyun ve yarısını bir tabağa alın.",
        "Avokado ve muzu çatalla pürüzsüz olana kadar ezin.",
        "Ihlamur çayını (veya anne sütünü) ekleyerek kıvamını hafifçe yumuşatıp servis edin."
      ],
      allergyWarning: "Alerjen madde içermez, ek gıdaya başlangıç için ideal ve son derece besleyicidir.",
    ),
    Recipe(
      id: "r4",
      name: "Somonlu Patates Çorbası",
      prepTime: "25 dk",
      startingMonth: 8,
      kcal: 165,
      imageUrl: "",
      ingredients: ["Somon", "Patates", "Havuç", "Zeytinyağı"],
      ingredientAmounts: ["50 gr kılçıksız fileto", "1 küçük adet", "1/2 adet", "1 tatlı kaşığı"],
      steps: [
        "Patates ve havucu küp küp doğrayıp haşlamaya bırakın.",
        "Kılçıksız somon filetosunu buharda ayrıca haşlayın ve tamamen temizlendiğinden emin olun.",
        "Sebzeler yumuşayınca somon balığı etini tencereye ekleyin.",
        "Blenderdan geçirip zeytinyağını katın ve ılık olarak çorba kasesinde servis edin."
      ],
      allergyWarning: "Bu tarif balık (Somon) içerir. Bebeklerde balık alerjisi reaksiyonlarına karşı dikkatli olunmalıdır.",
    ),
    Recipe(
      id: "r5",
      name: "Yeşil Bebek Omleti",
      prepTime: "12 dk",
      startingMonth: 9,
      kcal: 110,
      imageUrl: "",
      ingredients: ["Yumurta Sarısı", "Ispanak", "Labne", "Zeytinyağı"],
      ingredientAmounts: ["1 adet", "4-5 yaprak", "1 tatlı kaşığı", "1 çay kaşığı"],
      steps: [
        "Ispanak yapraklarını sirkeli suda yıkayıp incecik kıyın ve buharda soteleyin.",
        "Kasede yumurta sarısı, pişen ıspanak ve labne peynirini homojen olana kadar çırpın.",
        "Tavada zeytinyağını ısıtıp harcı dökün, çift taraflı iyice pişene kadar bekletin.",
        "Yumuşak dilimler halinde keserek servis edin."
      ],
      allergyWarning: "Ispanak nitrat içerebileceğinden bekletilmeden tüketilmelidir. Yumurta sarısı içerir.",
    ),
  ];

  int recipeCounter = 6;

  // 1. Purees (6+ Ay)
  final List<String> pureeVegs = ["Balkabağı", "Havuç", "Kabak", "Patates", "Tatlı Patates", "Karnabahar", "Bezelye"];
  final List<String> pureeFruits = ["Muz", "Elma", "Armut", "Şeftali", "Avokado", "Kayısı"];

  for (var i = 0; i < pureeVegs.length; i++) {
    for (var j = i + 1; j < pureeVegs.length; j++) {
      if (recipes.length >= 150) break;
      final veg1 = pureeVegs[i];
      final veg2 = pureeVegs[j];
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "Buharda $veg1 ve $veg2 Püresi",
        prepTime: "${10 + (recipeCounter % 3) * 5} dk",
        startingMonth: 6,
        kcal: 60.0 + (recipeCounter % 5) * 15,
        imageUrl: "",
        ingredients: [veg1, veg2, "Zeytinyağı"],
        ingredientAmounts: ["50 gr", "50 gr", "1 tatlı kaşığı"],
        steps: [
          "İyice yıkanmış $veg1 ve $veg2 sebzelerini soyup küp küp doğrayın.",
          "Buharda pişirme sepetinde yumuşayana kadar yaklaşık 12-15 dakika haşlayın.",
          "Haşlanan sebzeleri pürüzsüz olana kadar ezin veya blenderdan geçirin.",
          "Üzerine 1 tatlı kaşığı zeytinyağı ilave ederek ılık servis yapın."
        ],
        allergyWarning: "Sebze alerjisi geçmişi varsa ilk defa verirken 3 gün kuralına uyunuz.",
      ));
    }
  }

  for (var i = 0; i < pureeFruits.length; i++) {
    for (var j = i + 1; j < pureeFruits.length; j++) {
      if (recipes.length >= 150) break;
      final f1 = pureeFruits[i];
      final f2 = pureeFruits[j];
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "Tatlı $f1 ve $f2 Ezmesi",
        prepTime: "5 dk",
        startingMonth: 6,
        kcal: 70.0 + (recipeCounter % 4) * 20,
        imageUrl: "",
        ingredients: [f1, f2],
        ingredientAmounts: ["1/2 adet", "1/2 adet"],
        steps: [
          "Olgunlaşmış $f1 ve $f2 meyvelerini yıkayıp kabuklarını soyun.",
          "Meyveleri cam rendede rendeyin veya çatalla iyice pürüzsüz olana kadar ezin.",
          "Dilerseniz kıvamını açmak için az miktarda anne sütü veya formül mama ekleyebilirsiniz."
        ],
        allergyWarning: "Herhangi bir alerjik reaksiyon ihtimaline karşı 3 gün kuralını uygulayın.",
      ));
    }
  }

  // 2. Porridges & Grains (6+ or 8+ Ay)
  final List<String> grains = ["Yulaf", "İrmik", "Pirinç", "Kinoa", "Ruşeym"];
  final List<String> fruitsForPorridge = ["Muz", "Elma", "Armut", "Şeftali", "Kayısı", "Pekmez"];
  for (var g in grains) {
    for (var f in fruitsForPorridge) {
      if (recipes.length >= 150) break;
      int startingM = (g == "Ruşeym" || g == "Kinoa") ? 8 : 6;
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "$f Aromalı Yumuşak $g Lapası",
        prepTime: "15 dk",
        startingMonth: startingM,
        kcal: 110.0 + (recipeCounter % 6) * 15,
        imageUrl: "",
        ingredients: [g, f, "Anne Sütü"],
        ingredientAmounts: ["2 yemek kaşığı", "1/2 adet", "3 yemek kaşığı"],
        steps: [
          "$g ununu/tanesini küçük bir cezvede su ile sürekli karıştırarak muhallebi kıvamına gelene kadar pişirin.",
          "Ocaktan aldıktan sonra ılımasını bekleyin.",
          "Yumuşak $f meyvesini rendeleyip lapanın içine ilave edin.",
          "İsteğe bağlı olarak anne sütü ekleyerek kıvamını yumuşatın."
        ],
        allergyWarning: g == "Ruşeym" ? "Glüten içerir. Glüten hassasiyeti veya alerjisi olan bebekler için uygun değildir." : "Alerji riski düşüktür.",
      ));
    }
  }

  // 3. Omlets & Eggs (8+ Ay)
  final List<String> omeletVegs = ["Brokoli", "Ispanak", "Kabak", "Tatlı Patates", "Pazı", "Kırmızı Biber"];
  final List<String> cheeses = ["Lor Peyniri", "Labne", "Peynir"];
  for (var v in omeletVegs) {
    for (var c in cheeses) {
      if (recipes.length >= 150) break;
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "Bebekler İçin $v'li $c'li Omlet",
        prepTime: "10 dk",
        startingMonth: 8,
        kcal: 115.0 + (recipeCounter % 4) * 10,
        imageUrl: "",
        ingredients: ["Yumurta Sarısı", v, c, "Tereyağı"],
        ingredientAmounts: ["1 adet", "2 yemek kaşığı ince kıyılmış", "1 tatlı kaşığı", "1 çay kaşığı"],
        steps: [
          "$v sebzesini buharda iyice yumuşayana kadar haşlayın.",
          "Yumurta sarısını, $c peynirini ve haşlanmış $v'i bir kasede çırpın.",
          "Tavada tereyağını eritin.",
          "Harcı döküp arkalı önlü kısık ateşte iyice pişirin."
        ],
        allergyWarning: "Yumurta ve süt ürünü ($c) içerir. Alerji belirtileri açısından dikkatli olun.",
      ));
    }
  }

  // 4. Soups (8+ or 9+ Ay)
  final List<String> proteins = ["Tavuk", "Dana Kıyma", "Kuzu Eti", "Hindi"];
  final List<String> soupVegs = ["Havuç", "Kabak", "Patates", "Balkabağı", "Kereviz", "Pırasa"];
  for (var p in proteins) {
    for (var sv in soupVegs) {
      if (recipes.length >= 150) break;
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "Besleyici $p'lu $sv Çorbası",
        prepTime: "25 dk",
        startingMonth: 8,
        kcal: 140.0 + (recipeCounter % 5) * 15,
        imageUrl: "",
        ingredients: [p, sv, "İrmik", "Zeytinyağı"],
        ingredientAmounts: ["30 gr kıyılmış", "1/2 adet", "1 tatlı kaşığı", "1 tatlı kaşığı"],
        steps: [
          "Küçük bir tencerede $p etini az miktar su ile haşlamaya başlayın.",
          "Yumuşayan ete küçük doğranmış $sv sebzesini ve irmiği ekleyin.",
          "Sebzeler tamamen pişene kadar orta ateşte kaynatın.",
          "Çorbayı pürüzsüz kıvama getirip zeytinyağı ile tatlandırın."
        ],
        allergyWarning: "Et proteini ve irmik (glüten) içerir. Alerjen durumuna göre tercih edin.",
      ));
    }
  }

  // 5. Fish Dishes (9+ or 10+ Ay)
  final List<String> fishTypes = ["Somon", "Mezgit", "Levrek", "Çipura"];
  final List<String> fishVegs = ["Patates", "Kabak", "Havuç"];
  for (var f in fishTypes) {
    for (var fv in fishVegs) {
      if (recipes.length >= 150) break;
      recipes.add(Recipe(
        id: "r${recipeCounter++}",
        name: "Buharda Lezzetli $f ve $fv Yemeği",
        prepTime: "20 dk",
        startingMonth: 9,
        kcal: 130.0 + (recipeCounter % 4) * 20,
        imageUrl: "",
        ingredients: [f, fv, "Dereotu", "Zeytinyağı"],
        ingredientAmounts: ["40 gr fileto", "1/2 adet", "3-4 dal", "1 tatlı kaşığı"],
        steps: [
          "$f balık filetosunun kılçıklarını çok dikkatli bir şekilde kontrol edip temizleyin.",
          "$fv sebzesini ince halkalar halinde doğrayın.",
          "Balığı ve sebzeyi buharda yumuşayana kadar pişirin.",
          "Üzerine zeytinyağı gezdirip ince kıyılmış dereotu serpiştirerek servis edin."
        ],
        allergyWarning: "Balık ($f) içerir. Balık alerjisi yüksek riskli alerjenler grubundadır. Dikkat edin.",
      ));
    }
  }

  // Fill up if still less than 150 (Safeguard)
  while (recipes.length < 150) {
    recipes.add(Recipe(
      id: "r${recipeCounter++}",
      name: "Bebekler İçin Sebzeli Bulgur Pilavı",
      prepTime: "15 dk",
      startingMonth: 9,
      kcal: 125,
      imageUrl: "",
      ingredients: ["Kabak", "Havuç", "Tereyağı"],
      ingredientAmounts: ["2 yemek kaşığı rendelenmiş", "2 yemek kaşığı rendelenmiş", "1 tatlı kaşığı"],
      steps: [
        "Bulguru sıcak suyla haşlayıp kabarmasını bekleyin.",
        "Ayrı bir tavada tereyağı ile havuç ve kabağı soteleyin.",
        "Sotelenmiş sebzelerle bulguru karıştırıp demlenmeye bırakın."
      ],
      allergyWarning: "Glüten içerir.",
    ));
  }

  // ===== Bebek Köfteleri (15 tarif) — fırında/buharda, tuzsuz, kızartmasız =====
  recipes.addAll([
    Recipe(
      id: "kofte1", name: "Fırında Tavuklu Sebzeli Köfte", category: "Bebek Köfteleri",
      prepTime: "30 dk", startingMonth: 9, kcal: 140, imageUrl: "",
      ingredients: ["Tavuk Göğsü", "Havuç", "Patates", "Yumurta Sarısı", "Galeta Unu"],
      ingredientAmounts: ["80 gr", "1/2 adet", "1/2 adet", "1 adet", "2 yemek kaşığı"],
      steps: [
        "Havuç ve patatesi haşlayıp püre haline getirin.",
        "Çiğ tavuk göğsünü ince ince kıyın veya rondodan geçirin.",
        "Tüm malzemeleri yumurta sarısı ve galeta unuyla yoğurun, küçük köfteler şekillendirin.",
        "Yağlı kağıt serili tepside 180°C fırında 20-25 dakika içi tamamen pişene kadar pişirin.",
        "Ilındıktan sonra çatalla ezilebilecek yumuşaklıkta parmak gıda olarak sunun.",
      ],
      allergyWarning: "Yumurta ve glüten (galeta unu) içerir. Tavuk iyice pişmelidir.",
    ),
    Recipe(
      id: "kofte2", name: "Buharda Hindi Köftesi", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 8, kcal: 120, imageUrl: "",
      ingredients: ["Hindi Göğsü", "Kabak", "Yulaf", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "1/2 adet", "2 yemek kaşığı", "1 adet"],
      steps: [
        "Kabağı rendeleyip suyunu hafifçe sıkın.",
        "Hindi göğsünü ince kıyın; yulafı toz haline getirin.",
        "Tüm malzemeleri yoğurup küçük köfteler yapın.",
        "Buharda 15-18 dakika içi pişene kadar pişirin.",
        "Ilık ve yumuşak olarak sunun.",
      ],
      allergyWarning: "Yumurta içerir. Hindi iyice pişmelidir.",
    ),
    Recipe(
      id: "kofte3", name: "Mercimekli Vejetaryen Köfte", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 8, kcal: 110, imageUrl: "",
      ingredients: ["Kırmızı Mercimek", "Bulgur", "Havuç", "Zeytinyağı"],
      ingredientAmounts: ["60 gr", "2 yemek kaşığı", "1/2 adet", "1 tatlı kaşığı"],
      steps: [
        "Kırmızı mercimeği yumuşayana kadar haşlayın.",
        "İnce bulguru ekleyip karışım ılıyana kadar dinlendirin (bulgur şişsin).",
        "Rendelenmiş havucu ekleyip yoğurun, küçük köfteler şekillendirin.",
        "Acısız/baharatsız olarak, ılık servis edin.",
      ],
      allergyWarning: "Glüten (bulgur) içerir. Baharat ve tuz eklemeyin.",
    ),
    Recipe(
      id: "kofte4", name: "Fırında Somon Köftesi", category: "Bebek Köfteleri",
      prepTime: "30 dk", startingMonth: 9, kcal: 150, imageUrl: "",
      ingredients: ["Somon", "Patates", "Dereotu", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "1/2 adet", "1 tutam", "1 adet"],
      steps: [
        "Somonun TÜM kılçıklarını dikkatle ayıklayıp buharda pişirin.",
        "Patatesi haşlayıp ezin.",
        "Somonu çatalla didikleyip patates, ince kıyılmış dereotu ve yumurta sarısıyla yoğurun.",
        "Küçük köfteler yapıp 180°C fırında 18-20 dakika pişirin.",
        "Ilındıktan sonra ezilebilecek yumuşaklıkta sunun.",
      ],
      allergyWarning: "Balık ve yumurta içerir. Kılçık riskine karşı çok dikkatli ayıklayın.",
    ),
    Recipe(
      id: "kofte5", name: "Patatesli Brokoli Köftesi", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 8, kcal: 100, imageUrl: "",
      ingredients: ["Brokoli", "Patates", "Lor Peyniri", "Galeta Unu"],
      ingredientAmounts: ["4-5 küçük çiçek", "1 adet", "1 yemek kaşığı", "2 yemek kaşığı"],
      steps: [
        "Brokoli ve patatesi buharda iyice yumuşayana kadar haşlayın.",
        "İkisini de ezip lor peyniri ve galeta unuyla karıştırın.",
        "Küçük köfteler şekillendirin.",
        "180°C fırında 15-18 dakika hafif kızarana kadar pişirip ılık sunun.",
      ],
      allergyWarning: "Süt ürünü (lor) ve glüten içerir.",
    ),
    Recipe(
      id: "kofte6", name: "Dana Kıymalı Mini Köfte", category: "Bebek Köfteleri",
      prepTime: "30 dk", startingMonth: 9, kcal: 160, imageUrl: "",
      ingredients: ["Dana Kıyma", "Soğan", "Yulaf", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "1/4 adet", "2 yemek kaşığı", "1 adet"],
      steps: [
        "Soğanı çok ince rendeleyip suyunu sıkın.",
        "Yulafı toz haline getirin.",
        "Yağsız dana kıymayı soğan, yulaf ve yumurta sarısıyla iyice yoğurun.",
        "Küçük köfteler yapıp 180°C fırında 20-22 dakika tamamen pişene kadar pişirin.",
        "Ilındıktan sonra yumuşak olarak sunun.",
      ],
      allergyWarning: "Yumurta içerir. Et iyice pişmelidir; tuz/baharat eklemeyin.",
    ),
    Recipe(
      id: "kofte7", name: "Nohutlu Falafel Köftesi", category: "Bebek Köfteleri",
      prepTime: "30 dk", startingMonth: 10, kcal: 130, imageUrl: "",
      ingredients: ["Nohut", "Maydanoz", "Sarımsak", "Zeytinyağı"],
      ingredientAmounts: ["80 gr", "1 tutam", "1/4 diş", "1 tatlı kaşığı"],
      steps: [
        "Haşlanmış nohutu çok ince ezin/rondodan geçirin.",
        "İnce kıyılmış maydanoz ve az sarımsakla yoğurun.",
        "Küçük köfteler yapıp üzerine zeytinyağı sürün.",
        "180°C fırında 18-20 dakika pişirip ılık ve yumuşak sunun (kızartmayın).",
      ],
      allergyWarning: "Tuz ve baharat eklemeyin; nohut iyice pişmiş ve ezilmiş olmalı.",
    ),
    Recipe(
      id: "kofte8", name: "Kabaklı Peynirli Köfte", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 9, kcal: 110, imageUrl: "",
      ingredients: ["Kabak", "Lor Peyniri", "Yumurta Sarısı", "Galeta Unu"],
      ingredientAmounts: ["1 adet", "1 yemek kaşığı", "1 adet", "2 yemek kaşığı"],
      steps: [
        "Kabağı rendeleyip suyunu iyice sıkın.",
        "Lor peyniri, yumurta sarısı ve galeta unuyla karıştırın.",
        "Küçük köfteler şekillendirin.",
        "180°C fırında 15-18 dakika pişirip ılık sunun.",
      ],
      allergyWarning: "Yumurta, süt ürünü ve glüten içerir.",
    ),
    Recipe(
      id: "kofte9", name: "Yulaflı Tavuk Köftesi", category: "Bebek Köfteleri",
      prepTime: "28 dk", startingMonth: 9, kcal: 135, imageUrl: "",
      ingredients: ["Tavuk Göğsü", "Yulaf", "Havuç", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "3 yemek kaşığı", "1/2 adet", "1 adet"],
      steps: [
        "Yulafı toz haline getirin; havucu rendeleyin.",
        "İnce kıyılmış tavuğu yulaf, havuç ve yumurta sarısıyla yoğurun.",
        "Küçük köfteler yapın.",
        "180°C fırında 20-22 dakika içi pişene kadar pişirip ılık sunun.",
      ],
      allergyWarning: "Yumurta içerir. Tavuk iyice pişmelidir.",
    ),
    Recipe(
      id: "kofte10", name: "Ispanaklı Lor Köftesi", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 9, kcal: 105, imageUrl: "",
      ingredients: ["Ispanak", "Lor Peyniri", "Patates", "Galeta Unu"],
      ingredientAmounts: ["1 avuç", "2 yemek kaşığı", "1/2 adet", "2 yemek kaşığı"],
      steps: [
        "Ispanağı haşlayıp suyunu sıkın ve ince kıyın.",
        "Haşlanmış patatesi ezip lor peyniri ve ıspanakla karıştırın.",
        "Galeta unu ekleyip küçük köfteler yapın.",
        "180°C fırında 15-18 dakika pişirip ılık sunun.",
      ],
      allergyWarning: "Süt ürünü ve glüten içerir. Ispanak taze tüketilmelidir.",
    ),
    Recipe(
      id: "kofte11", name: "Bulgurlu Mercimek Köftesi (Vegan)", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 10, kcal: 115, imageUrl: "",
      ingredients: ["Kırmızı Mercimek", "Bulgur", "Soğan", "Zeytinyağı"],
      ingredientAmounts: ["60 gr", "3 yemek kaşığı", "1/4 adet", "1 tatlı kaşığı"],
      steps: [
        "Mercimeği yumuşayana kadar haşlayın.",
        "İnce bulguru ekleyip kapağı kapalı dinlendirin.",
        "Rendelenmiş soğanı (suyu sıkılmış) ve zeytinyağını ekleyip yoğurun.",
        "Küçük köfteler şekillendirip baharatsız, ılık sunun.",
      ],
      allergyWarning: "Glüten (bulgur) içerir. Tuz/baharat ve acı eklemeyin.",
    ),
    Recipe(
      id: "kofte12", name: "Havuçlu Tavuk Köftesi", category: "Bebek Köfteleri",
      prepTime: "28 dk", startingMonth: 9, kcal: 130, imageUrl: "",
      ingredients: ["Tavuk Göğsü", "Havuç", "Patates", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "1 adet", "1/2 adet", "1 adet"],
      steps: [
        "Havuç ve patatesi haşlayıp ezin.",
        "İnce kıyılmış tavukla ve yumurta sarısıyla yoğurun.",
        "Küçük köfteler yapın.",
        "180°C fırında 20-22 dakika pişirip ılındıktan sonra sunun.",
      ],
      allergyWarning: "Yumurta içerir. Tavuk iyice pişmelidir.",
    ),
    Recipe(
      id: "kofte13", name: "Tatlı Patatesli Hindi Köftesi", category: "Bebek Köfteleri",
      prepTime: "28 dk", startingMonth: 9, kcal: 135, imageUrl: "",
      ingredients: ["Hindi Göğsü", "Tatlı Patates", "Yulaf", "Yumurta Sarısı"],
      ingredientAmounts: ["80 gr", "1/2 adet", "2 yemek kaşığı", "1 adet"],
      steps: [
        "Tatlı patatesi haşlayıp ezin.",
        "İnce kıyılmış hindi, toz yulaf ve yumurta sarısıyla yoğurun.",
        "Küçük köfteler yapın.",
        "180°C fırında 20-22 dakika pişirip ılık sunun.",
      ],
      allergyWarning: "Yumurta içerir. Hindi iyice pişmelidir.",
    ),
    Recipe(
      id: "kofte14", name: "Bezelyeli Pirinçli Köfte", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 8, kcal: 110, imageUrl: "",
      ingredients: ["Bezelye", "Pirinç", "Lor Peyniri", "Yumurta Sarısı"],
      ingredientAmounts: ["50 gr", "2 yemek kaşığı", "1 yemek kaşığı", "1 adet"],
      steps: [
        "Pirinci iyice yumuşayana kadar pişirin (lapa kıvamı).",
        "Bezelyeyi haşlayıp ezin.",
        "Tüm malzemeleri yoğurup küçük köfteler yapın.",
        "180°C fırında 15-18 dakika pişirip ılık sunun.",
      ],
      allergyWarning: "Yumurta ve süt ürünü içerir.",
    ),
    Recipe(
      id: "kofte15", name: "Karnabaharlı Peynirli Köfte", category: "Bebek Köfteleri",
      prepTime: "25 dk", startingMonth: 9, kcal: 105, imageUrl: "",
      ingredients: ["Karnabahar", "Lor Peyniri", "Yumurta Sarısı", "Galeta Unu"],
      ingredientAmounts: ["5-6 küçük çiçek", "1 yemek kaşığı", "1 adet", "2 yemek kaşığı"],
      steps: [
        "Karnabaharı buharda yumuşayana kadar haşlayıp ezin.",
        "Lor peyniri, yumurta sarısı ve galeta unuyla karıştırın.",
        "Küçük köfteler şekillendirin.",
        "180°C fırında 15-18 dakika pişirip ılık sunun.",
      ],
      allergyWarning: "Yumurta, süt ürünü ve glüten içerir.",
    ),
  ]);

  // ===== Bebek Çorbaları (10) =====
  recipes.addAll([
    Recipe(id: "corba1", name: "Sebze Çorbası", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 6, kcal: 70, imageUrl: "", ingredients: ["Havuç", "Patates", "Kabak", "Zeytinyağı"], ingredientAmounts: ["1/2 adet", "1/2 adet", "1/2 adet", "1 tatlı kaşığı"], steps: ["Sebzeleri soyup küp küp doğrayın.", "Az suda yumuşayana kadar haşlayın.", "Blenderdan geçirip pürüzsüz çorba kıvamına getirin.", "Zeytinyağı ekleyip ılık servis edin."], allergyWarning: "İlk kez verilen sebzelerde 3 gün kuralına uyun."),
    Recipe(id: "corba2", name: "Kırmızı Mercimek Çorbası", category: "Bebek Çorbaları", prepTime: "30 dk", startingMonth: 6, kcal: 90, imageUrl: "", ingredients: ["Kırmızı Mercimek", "Havuç", "Patates", "Zeytinyağı"], ingredientAmounts: ["60 gr", "1/2 adet", "1/2 adet", "1 tatlı kaşığı"], steps: ["Mercimek ve sebzeleri yıkayıp küçük doğrayın.", "Yumuşayana kadar haşlayın.", "Blenderdan geçirip kıvam verin.", "Zeytinyağı ile ılık sunun (tuz eklemeyin)."], allergyWarning: "Tuz ve baharat eklemeyin."),
    Recipe(id: "corba3", name: "Balkabağı Çorbası", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 6, kcal: 75, imageUrl: "", ingredients: ["Balkabağı", "Havuç", "Tereyağı"], ingredientAmounts: ["120 gr", "1/2 adet", "1 çay kaşığı"], steps: ["Balkabağı ve havucu doğrayıp haşlayın.", "Ezip blenderdan geçirin.", "Az tereyağı ekleyip ılık sunun."], allergyWarning: "Süt ürünü (tereyağı) içerir."),
    Recipe(id: "corba4", name: "Brokoli Çorbası", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 6, kcal: 65, imageUrl: "", ingredients: ["Brokoli", "Patates", "Zeytinyağı"], ingredientAmounts: ["5-6 çiçek", "1/2 adet", "1 tatlı kaşığı"], steps: ["Brokoli ve patatesi buharda yumuşatın.", "Blenderdan geçirip kıvam verin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "—"),
    Recipe(id: "corba5", name: "Tavuklu Sebze Çorbası", category: "Bebek Çorbaları", prepTime: "35 dk", startingMonth: 8, kcal: 100, imageUrl: "", ingredients: ["Tavuk Göğsü", "Havuç", "Patates", "Pirinç"], ingredientAmounts: ["50 gr", "1/2 adet", "1/2 adet", "1 yemek kaşığı"], steps: ["Tavuğu kemiksiz haşlayıp didikleyin.", "Sebze ve pirinci yumuşayana kadar pişirin.", "Tavukla birleştirip ezin/blenderdan geçirin.", "Ilık sunun."], allergyWarning: "Tavuk iyice pişmelidir."),
    Recipe(id: "corba6", name: "Yoğurt Çorbası (Yayla)", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 8, kcal: 95, imageUrl: "", ingredients: ["Yoğurt", "Pirinç", "Yumurta Sarısı", "Nane"], ingredientAmounts: ["3 yemek kaşığı", "1 yemek kaşığı", "1 adet", "1 tutam"], steps: ["Pirinci yumuşayana kadar pişirin.", "Yoğurt ve yumurta sarısını çırpıp yavaşça ekleyin (kesilmesin).", "Kısık ateşte karıştırarak ısıtın.", "Az nane ile ılık sunun."], allergyWarning: "Süt ürünü ve yumurta içerir."),
    Recipe(id: "corba7", name: "Bezelye Çorbası", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 6, kcal: 80, imageUrl: "", ingredients: ["Bezelye", "Patates", "Zeytinyağı"], ingredientAmounts: ["80 gr", "1/2 adet", "1 tatlı kaşığı"], steps: ["Bezelye ve patatesi haşlayın.", "Blenderdan geçirip kıvam verin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "—"),
    Recipe(id: "corba8", name: "Tarhana Benzeri Sebze Çorbası", category: "Bebek Çorbaları", prepTime: "30 dk", startingMonth: 9, kcal: 90, imageUrl: "", ingredients: ["Domates", "Kabak", "Pirinç Unu", "Zeytinyağı"], ingredientAmounts: ["1 adet", "1/2 adet", "1 yemek kaşığı", "1 tatlı kaşığı"], steps: ["Domatesin kabuğunu soyup çekirdeğini ayıklayın.", "Sebzeleri haşlayıp ezin.", "Pirinç unuyla koyulaştırıp pişirin.", "Zeytinyağı ile ılık sunun."], allergyWarning: "—"),
    Recipe(id: "corba9", name: "Karnabahar Çorbası", category: "Bebek Çorbaları", prepTime: "25 dk", startingMonth: 6, kcal: 65, imageUrl: "", ingredients: ["Karnabahar", "Patates", "Tereyağı"], ingredientAmounts: ["5-6 çiçek", "1/2 adet", "1 çay kaşığı"], steps: ["Karnabahar ve patatesi yumuşayana kadar haşlayın.", "Blenderdan geçirin.", "Az tereyağı ekleyip ılık sunun."], allergyWarning: "Süt ürünü içerir."),
    Recipe(id: "corba10", name: "Etli Sebze Çorbası", category: "Bebek Çorbaları", prepTime: "40 dk", startingMonth: 9, kcal: 110, imageUrl: "", ingredients: ["Dana Kıyma", "Havuç", "Patates", "Pirinç"], ingredientAmounts: ["50 gr", "1/2 adet", "1/2 adet", "1 yemek kaşığı"], steps: ["Yağsız kıymayı az suda pişirin.", "Sebze ve pirinci ekleyip yumuşayana kadar haşlayın.", "Ezip kıvam verin.", "Ilık sunun."], allergyWarning: "Et iyice pişmelidir."),
  ]);

  // ===== Bebek Kahvaltısı (10) =====
  recipes.addAll([
    Recipe(id: "kahvalti1", name: "Muzlu Yulaf Ezmesi", category: "Bebek Kahvaltısı", prepTime: "10 dk", startingMonth: 6, kcal: 120, imageUrl: "", ingredients: ["Yulaf", "Muz"], ingredientAmounts: ["3 yemek kaşığı", "1/2 adet"], steps: ["Yulafı suyla yumuşayana kadar pişirin.", "Muzu ezip karıştırın.", "Ilık lapa kıvamında sunun."], allergyWarning: "—"),
    Recipe(id: "kahvalti2", name: "Yumurta Sarısı Püresi", category: "Bebek Kahvaltısı", prepTime: "12 dk", startingMonth: 6, kcal: 90, imageUrl: "", ingredients: ["Yumurta Sarısı", "Tereyağı"], ingredientAmounts: ["1 adet", "1 çay kaşığı"], steps: ["Yumurtayı tam haşlayın.", "Sarısını ayırıp çatalla ezin.", "Az tereyağı/anne sütü ile yumuşatıp sunun."], allergyWarning: "Yumurta ve süt ürünü içerir."),
    Recipe(id: "kahvalti3", name: "Avokadolu Tam Buğday Ekmeği", category: "Bebek Kahvaltısı", prepTime: "8 dk", startingMonth: 8, kcal: 130, imageUrl: "", ingredients: ["Avokado", "Tam Buğday Unu"], ingredientAmounts: ["1/4 adet", "1 dilim ekmek"], steps: ["Olgun avokadoyu ezin.", "Hafif kızartılmış tam buğday ekmeğine ince sürün.", "Küçük parçalara bölüp sunun."], allergyWarning: "Glüten içerir."),
    Recipe(id: "kahvalti4", name: "Lor Peynirli Meyve Kasesi", category: "Bebek Kahvaltısı", prepTime: "5 dk", startingMonth: 8, kcal: 95, imageUrl: "", ingredients: ["Lor Peyniri", "Armut", "Yulaf"], ingredientAmounts: ["2 yemek kaşığı", "1/2 adet", "1 yemek kaşığı"], steps: ["Armudu rendeleyin/ince doğrayın.", "Lor ve toz yulafla karıştırın.", "Kaşıkla sunun."], allergyWarning: "Süt ürünü içerir."),
    Recipe(id: "kahvalti5", name: "Sebzeli Bebek Omleti", category: "Bebek Kahvaltısı", prepTime: "12 dk", startingMonth: 8, kcal: 120, imageUrl: "", ingredients: ["Yumurta Sarısı", "Kabak", "Lor Peyniri", "Tereyağı"], ingredientAmounts: ["1 adet", "1/4 adet", "1 yemek kaşığı", "1 çay kaşığı"], steps: ["Kabağı rendeleyip suyunu sıkın.", "Yumurta sarısı ve lorla çırpın.", "Tereyağında kısık ateşte iyice pişirin.", "Ilındıktan sonra parmak gıda olarak sunun."], allergyWarning: "Yumurta ve süt ürünü içerir."),
    Recipe(id: "kahvalti6", name: "Tahinli Pekmezli Ekmek", category: "Bebek Kahvaltısı", prepTime: "5 dk", startingMonth: 9, kcal: 140, imageUrl: "", ingredients: ["Tahin", "Pekmez", "Tam Buğday Unu"], ingredientAmounts: ["1 tatlı kaşığı", "1 tatlı kaşığı", "1 dilim ekmek"], steps: ["Tahin ve pekmezi karıştırın.", "Ekmeğe ince sürün.", "Küçük parçalara bölüp sunun."], allergyWarning: "Susam (tahin) ve glüten içerir."),
    Recipe(id: "kahvalti7", name: "Yoğurtlu Yaban Mersinli Kase", category: "Bebek Kahvaltısı", prepTime: "5 dk", startingMonth: 8, kcal: 90, imageUrl: "", ingredients: ["Yoğurt", "Yaban Mersini", "Yulaf"], ingredientAmounts: ["3 yemek kaşığı", "1 avuç", "1 yemek kaşığı"], steps: ["Yaban mersinlerini ezin.", "Yoğurt ve toz yulafla karıştırın.", "Kaşıkla sunun."], allergyWarning: "Süt ürünü içerir."),
    Recipe(id: "kahvalti8", name: "Elmalı Tarçınlı Yulaf", category: "Bebek Kahvaltısı", prepTime: "12 dk", startingMonth: 6, kcal: 115, imageUrl: "", ingredients: ["Yulaf", "Elma", "Tarçın"], ingredientAmounts: ["3 yemek kaşığı", "1/2 adet", "1 tutam"], steps: ["Elmayı rendeleyin.", "Yulafı suyla pişirip elmayı ekleyin.", "Bir tutam tarçınla ılık sunun."], allergyWarning: "—"),
    Recipe(id: "kahvalti9", name: "Süzme Peynirli Salatalık Çubukları", category: "Bebek Kahvaltısı", prepTime: "5 dk", startingMonth: 9, kcal: 70, imageUrl: "", ingredients: ["Süzme Peynir", "Salatalık"], ingredientAmounts: ["2 yemek kaşığı", "1/2 adet"], steps: ["Salatalığı soyup kalın çubuklar kesin.", "Süzme peyniri yanında sunun (banarak).", "Gözetim altında parmak gıda olarak verin."], allergyWarning: "Süt ürünü içerir."),
    Recipe(id: "kahvalti10", name: "Mercimekli Yumurtalı Kahvaltı Tabağı", category: "Bebek Kahvaltısı", prepTime: "20 dk", startingMonth: 9, kcal: 130, imageUrl: "", ingredients: ["Kırmızı Mercimek", "Yumurta Sarısı", "Zeytinyağı"], ingredientAmounts: ["40 gr", "1 adet", "1 tatlı kaşığı"], steps: ["Mercimeği yumuşayana kadar haşlayıp ezin.", "Yumurtayı tam haşlayıp sarısını ekleyin.", "Zeytinyağı ile karıştırıp ılık sunun."], allergyWarning: "Yumurta içerir."),
  ]);

  // ===== Bebek Muhallebisi ve Mama Tarifleri (10) =====
  recipes.addAll([
    Recipe(id: "muhallebi1", name: "Pirinç Unlu Muhallebi", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "15 dk", startingMonth: 6, kcal: 100, imageUrl: "", ingredients: ["Pirinç Unu", "Muz"], ingredientAmounts: ["1 yemek kaşığı", "1/2 adet"], steps: ["Pirinç ununu anne sütü/formül veya su ile pişirip koyulaştırın.", "Soğuyunca ezilmiş muz ekleyin.", "Ilık sunun (şeker eklemeyin)."], allergyWarning: "Şeker/inek sütü eklemeyin (1 yaş altı)."),
    Recipe(id: "muhallebi2", name: "Muzlu Avokado Maması", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "5 dk", startingMonth: 6, kcal: 110, imageUrl: "", ingredients: ["Muz", "Avokado"], ingredientAmounts: ["1/2 adet", "1/4 adet"], steps: ["Muz ve avokadoyu çatalla ezin.", "Pürüzsüz olana kadar karıştırın.", "Hemen sunun."], allergyWarning: "—"),
    Recipe(id: "muhallebi3", name: "İrmik Muhallebisi", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "15 dk", startingMonth: 6, kcal: 105, imageUrl: "", ingredients: ["İrmik", "Elma"], ingredientAmounts: ["1 yemek kaşığı", "1/2 adet"], steps: ["İrmiği anne sütü/formül/su ile pişirin.", "Rendelenmiş elmayı ekleyip pişirin.", "Ilık sunun."], allergyWarning: "Glüten içerir."),
    Recipe(id: "muhallebi4", name: "Mısır Nişastalı Meyveli Muhallebi", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "15 dk", startingMonth: 6, kcal: 95, imageUrl: "", ingredients: ["Mısır Nişastası", "Armut"], ingredientAmounts: ["1 yemek kaşığı", "1/2 adet"], steps: ["Nişastayı su/anne sütü ile pişirip koyulaştırın.", "Ezilmiş armut ekleyin.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "muhallebi5", name: "Yulaf Maması", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "12 dk", startingMonth: 6, kcal: 115, imageUrl: "", ingredients: ["Yulaf", "Muz"], ingredientAmounts: ["3 yemek kaşığı", "1/2 adet"], steps: ["Yulafı su/anne sütü ile lapa kıvamına getirin.", "Ezilmiş muz ekleyin.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "muhallebi6", name: "Balkabaklı Mama", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "20 dk", startingMonth: 6, kcal: 85, imageUrl: "", ingredients: ["Balkabağı", "Pirinç Unu"], ingredientAmounts: ["100 gr", "1 yemek kaşığı"], steps: ["Balkabağını haşlayıp ezin.", "Pirinç unu ve sıvı ile pişirip kıvam verin.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "muhallebi7", name: "Tahinli Muz Maması", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "5 dk", startingMonth: 8, kcal: 130, imageUrl: "", ingredients: ["Muz", "Tahin", "Yulaf"], ingredientAmounts: ["1/2 adet", "1 tatlı kaşığı", "1 yemek kaşığı"], steps: ["Muzu ezin.", "Tahin ve toz yulafla karıştırın.", "Hemen sunun."], allergyWarning: "Susam içerir."),
    Recipe(id: "muhallebi8", name: "Elmalı Tarçınlı Muhallebi", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "15 dk", startingMonth: 6, kcal: 100, imageUrl: "", ingredients: ["Pirinç Unu", "Elma", "Tarçın"], ingredientAmounts: ["1 yemek kaşığı", "1/2 adet", "1 tutam"], steps: ["Pirinç ununu sıvı ile pişirin.", "Rendelenmiş elma ve bir tutam tarçın ekleyin.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "muhallebi9", name: "Hurmalı Mama (10 ay+)", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "10 dk", startingMonth: 10, kcal: 120, imageUrl: "", ingredients: ["Hurma", "Yulaf"], ingredientAmounts: ["1 adet", "3 yemek kaşığı"], steps: ["Çekirdeksiz hurmayı sıcak suda yumuşatıp ezin.", "Yulaf lapasına az miktar ekleyin.", "Ilık sunun (doğal şeker, az verilir)."], allergyWarning: "Doğal şeker yüksek; az miktarda."),
    Recipe(id: "muhallebi10", name: "Lor Peynirli Meyveli Mama", category: "Bebek Muhallebisi ve Mama Tarifleri", prepTime: "5 dk", startingMonth: 8, kcal: 95, imageUrl: "", ingredients: ["Lor Peyniri", "Şeftali"], ingredientAmounts: ["2 yemek kaşığı", "1/2 adet"], steps: ["Şeftaliyi soyup ezin.", "Lor peyniri ile karıştırın.", "Kaşıkla sunun."], allergyWarning: "Süt ürünü içerir."),
  ]);

  // ===== Bebek Bisküvileri (10) — fırında, şekersiz =====
  recipes.addAll([
    Recipe(id: "biskuvi1", name: "Muzlu Yulaflı Bebek Bisküvisi", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 9, kcal: 110, imageUrl: "", ingredients: ["Muz", "Yulaf"], ingredientAmounts: ["1 adet", "5 yemek kaşığı"], steps: ["Muzu ezip toz yulafla yoğurun.", "Küçük yuvarlaklar yapıp hafif bastırın.", "180°C fırında 15-18 dakika pişirin.", "İyice soğutup sunun."], allergyWarning: "Şeker eklenmez; sadece muz tatlandırır."),
    Recipe(id: "biskuvi2", name: "Elmalı Tarçınlı Kurabiye", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 9, kcal: 115, imageUrl: "", ingredients: ["Elma", "Yulaf", "Tarçın"], ingredientAmounts: ["1 adet", "5 yemek kaşığı", "1 tutam"], steps: ["Elmayı rendeleyip suyunu hafif sıkın.", "Toz yulaf ve tarçınla yoğurun.", "Şekil verip 180°C fırında 18 dakika pişirin.", "Soğutup sunun."], allergyWarning: "—"),
    Recipe(id: "biskuvi3", name: "Hurmalı Yulaf Topları", category: "Bebek Bisküvileri", prepTime: "15 dk", startingMonth: 10, kcal: 120, imageUrl: "", ingredients: ["Hurma", "Yulaf", "Tahin"], ingredientAmounts: ["2 adet", "4 yemek kaşığı", "1 tatlı kaşığı"], steps: ["Hurmayı yumuşatıp ezin.", "Toz yulaf ve tahinle yoğurun.", "Küçük toplar yapın (pişirmeden de sunulabilir).", "İyice yumuşak olduğundan emin olun."], allergyWarning: "Susam içerir; doğal şeker yüksek."),
    Recipe(id: "biskuvi4", name: "Tam Buğdaylı Sade Bisküvi", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 10, kcal: 130, imageUrl: "", ingredients: ["Tam Buğday Unu", "Muz", "Zeytinyağı"], ingredientAmounts: ["1 su bardağı", "1 adet", "1 yemek kaşığı"], steps: ["Tüm malzemeleri yoğurun.", "Açıp şekil verin.", "180°C fırında 15-18 dakika pişirip soğutun."], allergyWarning: "Glüten içerir."),
    Recipe(id: "biskuvi5", name: "Havuçlu Yulaf Bisküvisi", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 9, kcal: 105, imageUrl: "", ingredients: ["Havuç", "Yulaf", "Muz"], ingredientAmounts: ["1/2 adet", "4 yemek kaşığı", "1/2 adet"], steps: ["Havucu rendeleyin, muzu ezin.", "Toz yulafla yoğurun.", "180°C fırında 18 dakika pişirip soğutun."], allergyWarning: "—"),
    Recipe(id: "biskuvi6", name: "Cevizli Muzlu Bisküvi (12 ay+)", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 12, kcal: 140, imageUrl: "", ingredients: ["Muz", "Yulaf", "Ceviz"], ingredientAmounts: ["1 adet", "5 yemek kaşığı", "1 tatlı kaşığı"], steps: ["Cevizi çok ince öğütün.", "Ezilmiş muz ve toz yulafla yoğurun.", "180°C fırında 18 dakika pişirip soğutun."], allergyWarning: "Ağaç yemişi (ceviz) içerir; öğütülmüş olmalı."),
    Recipe(id: "biskuvi7", name: "Elmalı Yulaflı Lokmalar", category: "Bebek Bisküvileri", prepTime: "25 dk", startingMonth: 9, kcal: 100, imageUrl: "", ingredients: ["Elma", "Yulaf", "Tarçın"], ingredientAmounts: ["1 adet", "4 yemek kaşığı", "1 tutam"], steps: ["Elmayı rendeleyin.", "Toz yulaf ve tarçınla karıştırıp küçük lokmalar yapın.", "180°C fırında 15 dakika pişirip soğutun."], allergyWarning: "—"),
    Recipe(id: "biskuvi8", name: "Balkabaklı Bisküvi", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 9, kcal: 105, imageUrl: "", ingredients: ["Balkabağı", "Yulaf", "Tarçın"], ingredientAmounts: ["80 gr", "5 yemek kaşığı", "1 tutam"], steps: ["Balkabağını haşlayıp ezin.", "Toz yulaf ve tarçınla yoğurun.", "180°C fırında 18 dakika pişirip soğutun."], allergyWarning: "—"),
    Recipe(id: "biskuvi9", name: "Hindistan Cevizli Yulaf Bisküvisi (12 ay+)", category: "Bebek Bisküvileri", prepTime: "30 dk", startingMonth: 12, kcal: 135, imageUrl: "", ingredients: ["Yulaf", "Muz", "Hindistan Cevizi"], ingredientAmounts: ["5 yemek kaşığı", "1 adet", "1 yemek kaşığı"], steps: ["Muzu ezin.", "Toz yulaf ve ince hindistan cevizi rendesiyle yoğurun.", "180°C fırında 18 dakika pişirip soğutun."], allergyWarning: "—"),
    Recipe(id: "biskuvi10", name: "Armutlu Yumuşak Bisküvi", category: "Bebek Bisküvileri", prepTime: "28 dk", startingMonth: 9, kcal: 105, imageUrl: "", ingredients: ["Armut", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["1 adet", "5 yemek kaşığı", "1 adet"], steps: ["Armudu rendeleyin.", "Toz yulaf ve yumurta sarısıyla yoğurun.", "180°C fırında 18 dakika pişirip soğutun."], allergyWarning: "Yumurta içerir."),
  ]);

  // ===== Bebek Pankek Tarifleri (10) =====
  recipes.addAll([
    Recipe(id: "pankek1", name: "Muzlu Yumurta Pankeği", category: "Bebek Pankek Tarifleri", prepTime: "12 dk", startingMonth: 9, kcal: 120, imageUrl: "", ingredients: ["Muz", "Yumurta Sarısı", "Yulaf"], ingredientAmounts: ["1 adet", "1 adet", "2 yemek kaşığı"], steps: ["Muzu ezip yumurta sarısı ve toz yulafla çırpın.", "Yapışmaz tavada az yağla kısık ateşte pişirin.", "İki tarafını da iyice pişirin.", "Ilık, küçük parçalar halinde sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "pankek2", name: "Elmalı Tam Buğday Pankeği", category: "Bebek Pankek Tarifleri", prepTime: "15 dk", startingMonth: 9, kcal: 130, imageUrl: "", ingredients: ["Tam Buğday Unu", "Elma", "Yumurta Sarısı"], ingredientAmounts: ["3 yemek kaşığı", "1/2 adet", "1 adet"], steps: ["Elmayı rendeleyin.", "Un ve yumurta sarısıyla akışkan hamur yapın.", "Kısık ateşte pişirin.", "Küçük parçalara bölüp sunun."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "pankek3", name: "Yulaflı Yoğurtlu Pankek", category: "Bebek Pankek Tarifleri", prepTime: "15 dk", startingMonth: 9, kcal: 125, imageUrl: "", ingredients: ["Yulaf", "Yoğurt", "Yumurta Sarısı"], ingredientAmounts: ["3 yemek kaşığı", "2 yemek kaşığı", "1 adet"], steps: ["Toz yulaf, yoğurt ve yumurta sarısını karıştırın.", "Kısık ateşte yapışmaz tavada pişirin.", "İki tarafını pişirip ılık sunun."], allergyWarning: "Süt ürünü ve yumurta içerir."),
    Recipe(id: "pankek4", name: "Balkabaklı Pankek", category: "Bebek Pankek Tarifleri", prepTime: "18 dk", startingMonth: 9, kcal: 115, imageUrl: "", ingredients: ["Balkabağı", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["60 gr", "3 yemek kaşığı", "1 adet"], steps: ["Balkabağını haşlayıp ezin.", "Toz yulaf ve yumurta sarısıyla karıştırın.", "Kısık ateşte pişirip ılık sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "pankek5", name: "Muzlu İki Malzemeli Pankek", category: "Bebek Pankek Tarifleri", prepTime: "10 dk", startingMonth: 9, kcal: 95, imageUrl: "", ingredients: ["Muz", "Yumurta Sarısı"], ingredientAmounts: ["1 adet", "1 adet"], steps: ["Muzu ezip yumurta sarısıyla çırpın.", "Yapışmaz tavada kısık ateşte küçük pankekler pişirin.", "İyice pişirip ılık sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "pankek6", name: "Ispanaklı Tuzsuz Pankek", category: "Bebek Pankek Tarifleri", prepTime: "18 dk", startingMonth: 9, kcal: 110, imageUrl: "", ingredients: ["Ispanak", "Tam Buğday Unu", "Yumurta Sarısı"], ingredientAmounts: ["1 avuç", "3 yemek kaşığı", "1 adet"], steps: ["Ispanağı haşlayıp suyunu sıkın, ezin.", "Un ve yumurta sarısıyla akışkan hamur yapın.", "Kısık ateşte pişirip ılık sunun."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "pankek7", name: "Havuçlu Tarçınlı Pankek", category: "Bebek Pankek Tarifleri", prepTime: "18 dk", startingMonth: 9, kcal: 120, imageUrl: "", ingredients: ["Havuç", "Yulaf", "Yumurta Sarısı", "Tarçın"], ingredientAmounts: ["1/2 adet", "3 yemek kaşığı", "1 adet", "1 tutam"], steps: ["Havucu rendeleyin.", "Toz yulaf, yumurta sarısı ve tarçınla karıştırın.", "Kısık ateşte pişirip ılık sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "pankek8", name: "Armutlu Yulaf Pankeği", category: "Bebek Pankek Tarifleri", prepTime: "15 dk", startingMonth: 9, kcal: 110, imageUrl: "", ingredients: ["Armut", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["1/2 adet", "3 yemek kaşığı", "1 adet"], steps: ["Armudu rendeleyin.", "Toz yulaf ve yumurta sarısıyla karıştırın.", "Kısık ateşte pişirip ılık sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "pankek9", name: "Peynirli Tuzsuz Pankek", category: "Bebek Pankek Tarifleri", prepTime: "15 dk", startingMonth: 9, kcal: 125, imageUrl: "", ingredients: ["Lor Peyniri", "Tam Buğday Unu", "Yumurta Sarısı"], ingredientAmounts: ["2 yemek kaşığı", "3 yemek kaşığı", "1 adet"], steps: ["Tüm malzemeleri karıştırıp akışkan hamur yapın.", "Kısık ateşte küçük pankekler pişirin.", "Ilık sunun."], allergyWarning: "Süt ürünü, glüten ve yumurta içerir."),
    Recipe(id: "pankek10", name: "Yaban Mersinli Yulaf Pankeği", category: "Bebek Pankek Tarifleri", prepTime: "15 dk", startingMonth: 9, kcal: 115, imageUrl: "", ingredients: ["Yaban Mersini", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["1 avuç", "3 yemek kaşığı", "1 adet"], steps: ["Yaban mersinlerini ezin.", "Toz yulaf ve yumurta sarısıyla karıştırın.", "Kısık ateşte pişirip ılık sunun."], allergyWarning: "Yumurta içerir."),
  ]);

  // ===== Bebek Ekmekleri (10) — fırında, tuzsuz =====
  recipes.addAll([
    Recipe(id: "ekmek1", name: "Muzlu Yulaf Ekmeği", category: "Bebek Ekmekleri", prepTime: "40 dk", startingMonth: 9, kcal: 150, imageUrl: "", ingredients: ["Muz", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["2 adet", "1 su bardağı", "1 adet"], steps: ["Muzları ezip toz yulaf ve yumurta sarısıyla karıştırın.", "Yağlı kağıtlı küçük kalıba dökün.", "180°C fırında 25-30 dakika pişirin.", "Soğutup ince dilimleyip sunun."], allergyWarning: "Yumurta içerir."),
    Recipe(id: "ekmek2", name: "Havuçlu Tam Buğday Ekmeği", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 160, imageUrl: "", ingredients: ["Tam Buğday Unu", "Havuç", "Zeytinyağı", "Yumurta Sarısı"], ingredientAmounts: ["1.5 su bardağı", "1 adet", "2 yemek kaşığı", "1 adet"], steps: ["Havucu rendeleyin.", "Tüm malzemeleri yoğurun.", "Kalıba döküp 180°C fırında 30 dakika pişirin.", "Soğutup dilimleyin."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "ekmek3", name: "Patatesli Yumuşak Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 155, imageUrl: "", ingredients: ["Patates", "Tam Buğday Unu", "Zeytinyağı"], ingredientAmounts: ["1 adet", "1 su bardağı", "1 yemek kaşığı"], steps: ["Patatesi haşlayıp ezin.", "Un ve zeytinyağıyla yumuşak hamur yapın.", "180°C fırında 25-30 dakika pişirin.", "Soğutup sunun."], allergyWarning: "Glüten içerir."),
    Recipe(id: "ekmek4", name: "Balkabaklı Mini Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 150, imageUrl: "", ingredients: ["Balkabağı", "Tam Buğday Unu", "Yumurta Sarısı"], ingredientAmounts: ["100 gr", "1 su bardağı", "1 adet"], steps: ["Balkabağını haşlayıp ezin.", "Un ve yumurta sarısıyla yoğurun.", "180°C fırında 28 dakika pişirip soğutun."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "ekmek5", name: "Yulaflı Kepekli Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 155, imageUrl: "", ingredients: ["Yulaf", "Tam Buğday Unu", "Yoğurt"], ingredientAmounts: ["4 yemek kaşığı", "1 su bardağı", "3 yemek kaşığı"], steps: ["Toz yulaf, un ve yoğurdu yoğurun.", "Kalıba dökün.", "180°C fırında 28-30 dakika pişirip soğutun."], allergyWarning: "Glüten ve süt ürünü içerir."),
    Recipe(id: "ekmek6", name: "Peynirli Mini Poğaça (Tuzsuz)", category: "Bebek Ekmekleri", prepTime: "40 dk", startingMonth: 10, kcal: 165, imageUrl: "", ingredients: ["Tam Buğday Unu", "Lor Peyniri", "Yumurta Sarısı", "Zeytinyağı"], ingredientAmounts: ["1 su bardağı", "2 yemek kaşığı", "1 adet", "1 yemek kaşığı"], steps: ["Tüm malzemeleri yoğurun.", "Küçük poğaçalar şekillendirin.", "180°C fırında 20 dakika pişirip soğutun."], allergyWarning: "Glüten, süt ürünü ve yumurta içerir."),
    Recipe(id: "ekmek7", name: "Ispanaklı Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 150, imageUrl: "", ingredients: ["Ispanak", "Tam Buğday Unu", "Yumurta Sarısı"], ingredientAmounts: ["1 avuç", "1 su bardağı", "1 adet"], steps: ["Ispanağı haşlayıp suyunu sıkın, ezin.", "Un ve yumurta sarısıyla yoğurun.", "180°C fırında 28 dakika pişirip soğutun."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "ekmek8", name: "Elmalı Tarçınlı Kek Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 160, imageUrl: "", ingredients: ["Elma", "Tam Buğday Unu", "Yumurta Sarısı", "Tarçın"], ingredientAmounts: ["1 adet", "1 su bardağı", "1 adet", "1 tutam"], steps: ["Elmayı rendeleyin.", "Un, yumurta sarısı ve tarçınla yoğurun.", "180°C fırında 28 dakika pişirip soğutun."], allergyWarning: "Glüten ve yumurta içerir."),
    Recipe(id: "ekmek9", name: "Cevizli Muzlu Kek Ekmek (12 ay+)", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 12, kcal: 175, imageUrl: "", ingredients: ["Muz", "Tam Buğday Unu", "Ceviz", "Yumurta Sarısı"], ingredientAmounts: ["2 adet", "1 su bardağı", "1 yemek kaşığı", "1 adet"], steps: ["Cevizi ince öğütün.", "Ezilmiş muz, un ve yumurta sarısıyla yoğurun.", "180°C fırında 30 dakika pişirip soğutun."], allergyWarning: "Glüten, yumurta ve ağaç yemişi içerir."),
    Recipe(id: "ekmek10", name: "Karabuğdaylı Glutensiz Ekmek", category: "Bebek Ekmekleri", prepTime: "45 dk", startingMonth: 10, kcal: 150, imageUrl: "", ingredients: ["Karabuğday", "Muz", "Zeytinyağı"], ingredientAmounts: ["1 su bardağı un", "1 adet", "1 yemek kaşığı"], steps: ["Karabuğday ununu ezilmiş muz ve sıvı ile yoğurun.", "Kalıba dökün.", "180°C fırında 30 dakika pişirip soğutun."], allergyWarning: "Glutensiz; muz ile tatlandırılır."),
  ]);

  // ===== Bebek Çayları (8) — şekersiz, az miktar, ana içecek anne sütü/formüldür =====
  recipes.addAll([
    Recipe(id: "cay1", name: "Ihlamur Çayı (Ilık, Şekersiz)", category: "Bebek Çayları", prepTime: "10 dk", startingMonth: 6, kcal: 2, imageUrl: "", ingredients: ["Ihlamur Çayı"], ingredientAmounts: ["1-2 tatlı kaşığı"], steps: ["Az ıhlamuru demleyip iyice soğutun.", "Şeker EKLEMEDEN, 1-2 tatlı kaşığı ılık verin.", "Ana içecek anne sütü/formüldür; çay onun yerine geçmez."], allergyWarning: "Şeker eklemeyin; az miktarda. Doktorunuza danışın."),
    Recipe(id: "cay2", name: "Rezene Çayı (Gaz için)", category: "Bebek Çayları", prepTime: "10 dk", startingMonth: 6, kcal: 2, imageUrl: "", ingredients: ["Rezene Tohumu"], ingredientAmounts: ["1 tatlı kaşığı"], steps: ["Az rezeneyi demleyip süzün ve soğutun.", "Şekersiz, çok az miktar ılık verin.", "Gaz/kolik için; sık ve çok verilmez."], allergyWarning: "Az miktar; doktora danışın."),
    Recipe(id: "cay3", name: "Papatya Çayı", category: "Bebek Çayları", prepTime: "10 dk", startingMonth: 6, kcal: 2, imageUrl: "", ingredients: ["Ihlamur Çayı"], ingredientAmounts: ["1 tatlı kaşığı"], steps: ["Çok az papatyayı demleyip iyice soğutun.", "Şekersiz, az miktar ılık verin.", "Uyku/sakinlik için; çok verilmez."], allergyWarning: "Papatya alerjisine dikkat; doktora danışın."),
    Recipe(id: "cay4", name: "Elma Kabuğu Suyu (Şekersiz)", category: "Bebek Çayları", prepTime: "15 dk", startingMonth: 8, kcal: 5, imageUrl: "", ingredients: ["Elma"], ingredientAmounts: ["1 adet kabuğu"], steps: ["Temiz elma kabuklarını az suda kaynatıp süzün.", "İyice soğutup şekersiz çok az verin.", "Ana içecek değildir."], allergyWarning: "Şeker eklemeyin; az miktar."),
    Recipe(id: "cay5", name: "Kuşburnu Çayı (Şekersiz)", category: "Bebek Çayları", prepTime: "15 dk", startingMonth: 9, kcal: 4, imageUrl: "", ingredients: ["Kuşburnu"], ingredientAmounts: ["1 tatlı kaşığı"], steps: ["Kuşburnunu demleyip iyice süzün (tüy/çekirdek kalmasın).", "Soğutup şekersiz az miktar verin.", "C vitamini içerir; az verilir."], allergyWarning: "İyice süzülmeli; az miktar."),
    Recipe(id: "cay6", name: "Anason Çayı (Gaz için, çok az)", category: "Bebek Çayları", prepTime: "10 dk", startingMonth: 8, kcal: 2, imageUrl: "", ingredients: ["Anason"], ingredientAmounts: ["1/2 tatlı kaşığı"], steps: ["Çok az anasonu demleyip süzün, soğutun.", "Şekersiz, uç miktar ılık verin.", "Sık verilmez; doktora danışın."], allergyWarning: "Çok az miktar; doktora danışın."),
    Recipe(id: "cay7", name: "Nane Çayı (10 ay+, çok az)", category: "Bebek Çayları", prepTime: "10 dk", startingMonth: 10, kcal: 2, imageUrl: "", ingredients: ["Nane"], ingredientAmounts: ["2-3 yaprak"], steps: ["Birkaç taze nane yaprağını demleyip süzün.", "İyice soğutup şekersiz çok az verin.", "Mide rahatlığı için; az verilir."], allergyWarning: "Az miktar; doktora danışın."),
    Recipe(id: "cay8", name: "Kayısı Hoşafı (Şekersiz)", category: "Bebek Çayları", prepTime: "20 dk", startingMonth: 8, kcal: 30, imageUrl: "", ingredients: ["Kuru Kayısı"], ingredientAmounts: ["2 adet"], steps: ["Kükürtsüz kuru kayısıyı az suda kaynatın.", "Suyunu süzüp soğutun (şeker eklemeyin).", "Kabızlıkta az miktar verilir."], allergyWarning: "Kükürtsüz olanı tercih edin; şeker eklemeyin."),
  ]);

  // ===== Bebek Püreleri (8 imzalık) =====
  recipes.addAll([
    Recipe(id: "pure1", name: "Avokado Püresi", category: "Bebek Püreleri", prepTime: "5 dk", startingMonth: 6, kcal: 110, imageUrl: "", ingredients: ["Avokado"], ingredientAmounts: ["1/2 adet"], steps: ["Olgun avokadoyu çatalla pürüzsüz ezin.", "Gerekirse anne sütü/su ile yumuşatın.", "Hemen sunun."], allergyWarning: "—"),
    Recipe(id: "pure2", name: "Tatlı Patates Püresi", category: "Bebek Püreleri", prepTime: "20 dk", startingMonth: 6, kcal: 90, imageUrl: "", ingredients: ["Tatlı Patates", "Zeytinyağı"], ingredientAmounts: ["1 adet", "1 tatlı kaşığı"], steps: ["Tatlı patatesi haşlayıp soyun.", "Pürüzsüz ezin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "—"),
    Recipe(id: "pure3", name: "Elma Püresi", category: "Bebek Püreleri", prepTime: "15 dk", startingMonth: 6, kcal: 60, imageUrl: "", ingredients: ["Elma"], ingredientAmounts: ["1 adet"], steps: ["Elmayı soyup doğrayın ve buharda yumuşatın.", "Pürüzsüz ezin.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "pure4", name: "Brokoli Patates Püresi", category: "Bebek Püreleri", prepTime: "20 dk", startingMonth: 6, kcal: 75, imageUrl: "", ingredients: ["Brokoli", "Patates", "Zeytinyağı"], ingredientAmounts: ["4 çiçek", "1/2 adet", "1 tatlı kaşığı"], steps: ["Brokoli ve patatesi buharda yumuşatın.", "Birlikte ezip blenderdan geçirin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "—"),
    Recipe(id: "pure5", name: "Muzlu Yulaf Püresi", category: "Bebek Püreleri", prepTime: "10 dk", startingMonth: 6, kcal: 110, imageUrl: "", ingredients: ["Muz", "Yulaf"], ingredientAmounts: ["1/2 adet", "2 yemek kaşığı"], steps: ["Yulafı su/anne sütü ile pişirin.", "Ezilmiş muzu ekleyip karıştırın.", "Ilık sunun."], allergyWarning: "—"),
    Recipe(id: "pure6", name: "Mercimekli Havuç Püresi", category: "Bebek Püreleri", prepTime: "25 dk", startingMonth: 6, kcal: 90, imageUrl: "", ingredients: ["Kırmızı Mercimek", "Havuç", "Zeytinyağı"], ingredientAmounts: ["40 gr", "1/2 adet", "1 tatlı kaşığı"], steps: ["Mercimek ve havucu yumuşayana kadar haşlayın.", "Pürüzsüz ezin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "—"),
    Recipe(id: "pure7", name: "Şeftali Püresi", category: "Bebek Püreleri", prepTime: "10 dk", startingMonth: 6, kcal: 55, imageUrl: "", ingredients: ["Şeftali"], ingredientAmounts: ["1 adet"], steps: ["Şeftaliyi soyup çekirdeğini çıkarın.", "Çatalla ezin (sert ise buharda yumuşatın).", "Ilık/serin sunun."], allergyWarning: "—"),
    Recipe(id: "pure8", name: "Tavuklu Sebze Püresi", category: "Bebek Püreleri", prepTime: "30 dk", startingMonth: 8, kcal: 110, imageUrl: "", ingredients: ["Tavuk Göğsü", "Patates", "Havuç", "Zeytinyağı"], ingredientAmounts: ["50 gr", "1/2 adet", "1/2 adet", "1 tatlı kaşığı"], steps: ["Tavuğu kemiksiz haşlayıp didikleyin.", "Sebzeleri haşlayıp ezin.", "Tavukla birlikte blenderdan geçirin.", "Zeytinyağı ekleyip ılık sunun."], allergyWarning: "Tavuk iyice pişmelidir."),
  ]);

  // ===== Kuzu Kıymalı Tarifler (10) — fırında/buharda, tuzsuz =====
  recipes.addAll([
    Recipe(id: "kuzu1", name: "Kuzu Kıymalı Sebzeli Köfte", category: "Bebek Köfteleri", prepTime: "30 dk", startingMonth: 9, kcal: 160, imageUrl: "", ingredients: ["Kuzu Kıyma", "Havuç", "Patates", "Yumurta Sarısı"], ingredientAmounts: ["80 gr", "1/2 adet", "1/2 adet", "1 adet"], steps: ["Havuç ve patatesi haşlayıp ezin.", "Yağsız kuzu kıymayı sebze ve yumurta sarısıyla yoğurun.", "Küçük köfteler yapıp 180°C fırında 20-22 dakika tamamen pişene kadar pişirin.", "Ilındıktan sonra yumuşak parmak gıda olarak sunun."], allergyWarning: "Yumurta içerir. Et iyice pişmelidir; tuz/baharat eklemeyin."),
    Recipe(id: "kuzu2", name: "Kuzu Kıymalı Mercimek Çorbası", category: "Bebek Çorbaları", prepTime: "35 dk", startingMonth: 8, kcal: 120, imageUrl: "", ingredients: ["Kuzu Kıyma", "Kırmızı Mercimek", "Havuç", "Zeytinyağı"], ingredientAmounts: ["50 gr", "50 gr", "1/2 adet", "1 tatlı kaşığı"], steps: ["Yağsız kuzu kıymayı az suda pişirin.", "Mercimek ve havucu ekleyip yumuşayana kadar haşlayın.", "Ezip/blenderdan geçirip kıvam verin.", "Zeytinyağı ile ılık sunun (tuz eklemeyin)."], allergyWarning: "Et iyice pişmelidir."),
    Recipe(id: "kuzu3", name: "Kuzu Kıymalı Patates Püresi", category: "Bebek Püreleri", prepTime: "30 dk", startingMonth: 8, kcal: 130, imageUrl: "", ingredients: ["Kuzu Kıyma", "Patates", "Havuç", "Tereyağı"], ingredientAmounts: ["50 gr", "1 adet", "1/2 adet", "1 çay kaşığı"], steps: ["Kuzu kıymayı az suda iyice pişirin.", "Patates ve havucu haşlayıp ezin.", "Etle birlikte ezip pürüzsüz püre yapın.", "Az tereyağı ekleyip ılık sunun."], allergyWarning: "Süt ürünü (tereyağı) içerir."),
    Recipe(id: "kuzu4", name: "Kuzu Kıymalı Sebze Yemeği", category: "Bebek Köfteleri", prepTime: "35 dk", startingMonth: 9, kcal: 150, imageUrl: "", ingredients: ["Kuzu Kıyma", "Kabak", "Patates", "Domates"], ingredientAmounts: ["80 gr", "1/2 adet", "1/2 adet", "1 adet"], steps: ["Domatesin kabuğunu soyup çekirdeğini ayıklayın.", "Kuzu kıymayı az suda pişirin.", "Doğranmış sebzeleri ekleyip yumuşayana kadar pişirin.", "Çatalla ezerek ılık sunun."], allergyWarning: "Et iyice pişmelidir."),
    Recipe(id: "kuzu5", name: "Kuzu Kıymalı Bulgur Pilavı", category: "Bebek Kahvaltısı", prepTime: "35 dk", startingMonth: 9, kcal: 155, imageUrl: "", ingredients: ["Kuzu Kıyma", "Bulgur", "Havuç", "Zeytinyağı"], ingredientAmounts: ["60 gr", "3 yemek kaşığı", "1/2 adet", "1 tatlı kaşığı"], steps: ["Kuzu kıymayı az suda pişirin.", "Rendelenmiş havucu ekleyin.", "Bulguru ekleyip iyice yumuşayana kadar pişirin.", "Çatalla ezerek/yumuşak haliyle ılık sunun."], allergyWarning: "Glüten (bulgur) içerir; et iyice pişmelidir."),
    Recipe(id: "kuzu6", name: "Kuzu Kıymalı Ispanaklı Köfte", category: "Bebek Köfteleri", prepTime: "30 dk", startingMonth: 9, kcal: 150, imageUrl: "", ingredients: ["Kuzu Kıyma", "Ispanak", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["80 gr", "1 avuç", "2 yemek kaşığı", "1 adet"], steps: ["Ispanağı haşlayıp suyunu sıkın, ince kıyın.", "Yulafı toz haline getirin.", "Kuzu kıyma, ıspanak, yulaf ve yumurta sarısını yoğurun.", "Küçük köfteler yapıp 180°C fırında 20 dakika pişirin."], allergyWarning: "Yumurta içerir. Ispanak taze tüketilmeli; et iyice pişmeli."),
    Recipe(id: "kuzu7", name: "Kuzu Kıymalı Kabak Yemeği", category: "Bebek Köfteleri", prepTime: "30 dk", startingMonth: 9, kcal: 140, imageUrl: "", ingredients: ["Kuzu Kıyma", "Kabak", "Soğan", "Zeytinyağı"], ingredientAmounts: ["80 gr", "1 adet", "1/4 adet", "1 tatlı kaşığı"], steps: ["Soğanı çok ince rendeleyip zeytinyağında pişirin.", "Kuzu kıymayı ekleyip suyunu salıp çekene kadar pişirin.", "Doğranmış kabağı ekleyip yumuşayana kadar pişirin.", "Çatalla ezerek ılık sunun."], allergyWarning: "Et iyice pişmelidir."),
    Recipe(id: "kuzu8", name: "Kuzu Kıymalı Nohutlu Yemek", category: "Bebek Köfteleri", prepTime: "35 dk", startingMonth: 10, kcal: 165, imageUrl: "", ingredients: ["Kuzu Kıyma", "Nohut", "Havuç", "Zeytinyağı"], ingredientAmounts: ["70 gr", "60 gr", "1/2 adet", "1 tatlı kaşığı"], steps: ["Haşlanmış nohutu ezin.", "Kuzu kıymayı az suda pişirin.", "Havuç ve nohutu ekleyip pişirin.", "Ezip/yumuşak haliyle ılık sunun."], allergyWarning: "Et iyice pişmeli; nohut iyice ezilmiş olmalı."),
    Recipe(id: "kuzu9", name: "Kuzu Kıymalı Yumurtalı Köfte", category: "Bebek Köfteleri", prepTime: "28 dk", startingMonth: 9, kcal: 160, imageUrl: "", ingredients: ["Kuzu Kıyma", "Yumurta Sarısı", "Galeta Unu", "Maydanoz"], ingredientAmounts: ["90 gr", "1 adet", "2 yemek kaşığı", "1 tutam"], steps: ["İnce kıyılmış maydanozu kuzu kıymayla karıştırın.", "Yumurta sarısı ve galeta unuyla yoğurun.", "Küçük köfteler yapın.", "180°C fırında 20-22 dakika pişirip ılık sunun."], allergyWarning: "Yumurta ve glüten (galeta unu) içerir."),
    Recipe(id: "kuzu10", name: "Kuzu Kıymalı Tatlı Patates Köftesi", category: "Bebek Köfteleri", prepTime: "30 dk", startingMonth: 9, kcal: 155, imageUrl: "", ingredients: ["Kuzu Kıyma", "Tatlı Patates", "Yulaf", "Yumurta Sarısı"], ingredientAmounts: ["80 gr", "1/2 adet", "2 yemek kaşığı", "1 adet"], steps: ["Tatlı patatesi haşlayıp ezin.", "Toz yulaf, kuzu kıyma ve yumurta sarısıyla yoğurun.", "Küçük köfteler yapın.", "180°C fırında 20-22 dakika pişirip ılık sunun."], allergyWarning: "Yumurta içerir. Et iyice pişmelidir."),
  ]);

  return recipes;
}

final List<Recipe> globalRecipesDatabase = _generateAllRecipes();
