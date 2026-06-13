import 'nutrition_database.dart';

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
      );

  /// Resolves the cart/shopping unit for a food name (built-in or custom).
  static String unitFor(String name) {
    final m = globalFoodsDatabase.where((f) => f.name.toLowerCase() == name.toLowerCase()).toList();
    return m.isNotEmpty ? m.first.cartUnit : "adet";
  }
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
      );
}

/// Admin-added foods/recipes (raw JSON), merged into the databases on startup.
final List<Map<String, dynamic>> globalCustomFoods = [];
final List<Map<String, dynamic>> globalCustomRecipes = [];

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
    final detail = kDetailedNutrition[food.name.toLowerCase().trim()];
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

/// Aggregated detailed nutrition for a recipe, summed across its ingredient
/// foods (each via [nutritionForFood]). Energy uses the recipe's stored kcal
/// when available; carbohydrate falls back to [atwaterCarb] if it summed to 0.
Map<String, double> nutritionForRecipe(Recipe recipe) {
  final sum = {for (final k in kNutrientKeys) k: 0.0};
  for (final ing in recipe.ingredients) {
    Food? f;
    for (final cand in globalFoodsDatabase) {
      if (cand.name.toLowerCase() == ing.toLowerCase()) {
        f = cand;
        break;
      }
    }
    if (f == null) continue;
    final n = nutritionForFood(f);
    for (final k in kNutrientKeys) {
      sum[k] = sum[k]! + (n[k] ?? 0);
    }
  }
  if (recipe.kcal > 0) sum["Enerji"] = recipe.kcal;
  if ((sum["Karbonhidrat"] ?? 0) == 0) {
    sum["Karbonhidrat"] = atwaterCarb(sum["Enerji"]!, sum["Protein"]!, sum["Yağ"]!);
  }
  return sum;
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
      imageUrl: "assets/images/puree_plate.png",
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
      imageUrl: "assets/images/omelet_plate.png",
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
      imageUrl: "assets/images/puree_plate.png",
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
      imageUrl: "assets/images/salmon_plate.png",
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
      imageUrl: "assets/images/omelet_plate.png",
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
        imageUrl: "assets/images/puree_plate.png",
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
        imageUrl: "assets/images/puree_plate.png",
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
        imageUrl: "assets/images/porridge_plate.png",
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
        imageUrl: "assets/images/omelet_plate.png",
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
        imageUrl: "assets/images/puree_plate.png",
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
        imageUrl: "assets/images/salmon_plate.png",
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
      imageUrl: "assets/images/puree_plate.png",
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

  return recipes;
}

final List<Recipe> globalRecipesDatabase = _generateAllRecipes();
