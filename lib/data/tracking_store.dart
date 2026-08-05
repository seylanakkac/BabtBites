// Per-baby tracking state (food journey + reminders).
//
// The app tracks each baby's food journey separately. These globals are the
// single source of truth; Food.tried/Food.isFavorite in globalFoodsDatabase
// are only a projection of the *active* baby (see _syncGlobalFlagsToActiveBaby
// in home_screen). All data here is JSON-serialisable and persisted by
// StorageService under the `baby_food_states` and `reminders` keys.

/// babyId -> (foodName -> state map).
/// State map shape:
/// { "tried": bool, "favorite": bool,
///   "status": "sorunsuz" | "reaksiyon" | null,
///   "triedDate": "yyyy-MM-dd" | null,
///   "reactionNote": String | null,
///   "retryDate": "yyyy-MM-dd" | null,
///   "taste": "sevdi" | "sevmedi" | null }   // bebeğin beğenisi
final Map<String, Map<String, dynamic>> globalBabyFoodStates = {};

/// babyId -> (recipeId -> "sevdi" | "sevmedi").
///
/// Gıdaların beğenisi [globalBabyFoodStates] içindeki "taste" alanında tutulur;
/// tariflerin ayrı bir kaydı yok, bu yüzden burada. İkisi de BEBEK BAŞINA:
/// "favori" (ebeveynin yer imi) ile karıştırılmamalı — bu, bebeğin tepkisi.
final Map<String, Map<String, String>> globalBabyRecipeTastes = {};

/// Şu anda seçili bebeğin kimliği.
///
/// HomeScreen aktif bebeği her değiştirdiğinde günceller. Bebek kimliğini
/// parametre olarak taşımayan ekranların (derin bağlantıyla açılan tarif
/// detayı, örnek menü, kullanıcı profili) beğeni yazabilmesi için gerekli.
/// Boşken beğeni arayüzü hiç gösterilmez — sahipsiz kayıt oluşmaz.
String globalActiveBabyId = "";

/// Beğeni seçenekleri: (anahtar, emoji, etiket).
const List<(String, String, String)> kTasteOptions = [
  ("sevdi", "😍", "Sevdi"),
  ("sevmedi", "😖", "Sevmedi"),
];

/// Bir gıdanın beğenisi; yoksa null.
String? foodTaste(String babyId, String foodName) {
  final v = readFoodState(babyId, foodName)?["taste"]?.toString() ?? "";
  return v.isEmpty ? null : v;
}

/// Gıda beğenisini yazar; [value] null ise işareti kaldırır.
void setFoodTaste(String babyId, String foodName, String? value) {
  final st = ensureFoodState(babyId, foodName);
  if (value == null) {
    st.remove("taste");
  } else {
    st["taste"] = value;
  }
}

/// Bir tarifin beğenisi; yoksa null.
String? recipeTaste(String babyId, String recipeId) =>
    globalBabyRecipeTastes[babyId]?[recipeId];

/// Tarif beğenisini yazar; [value] null ise işareti kaldırır.
void setRecipeTaste(String babyId, String recipeId, String? value) {
  final forBaby = globalBabyRecipeTastes.putIfAbsent(babyId, () => {});
  if (value == null) {
    forBaby.remove(recipeId);
  } else {
    forBaby[recipeId] = value;
  }
}

/// Beğeni anahtarının emojisi (bilinmeyen → boş).
String tasteEmoji(String? key) {
  for (final o in kTasteOptions) {
    if (o.$1 == key) return o.$2;
  }
  return "";
}

/// Beğeni anahtarının etiketi (bilinmeyen → boş).
String tasteLabel(String? key) {
  for (final o in kTasteOptions) {
    if (o.$1 == key) return o.$3;
  }
  return "";
}

/// Bebeğin sevdiği gıdaların adları.
Set<String> likedFoodNames(String babyId) {
  final forBaby = globalBabyFoodStates[babyId];
  if (forBaby == null) return {};
  return forBaby.entries
      .where((e) => (e.value as Map)["taste"] == "sevdi")
      .map((e) => e.key)
      .toSet();
}

/// Bebeğin sevdiği tariflerin kimlikleri.
Set<String> likedRecipeIds(String babyId) {
  final forBaby = globalBabyRecipeTastes[babyId];
  if (forBaby == null) return {};
  return forBaby.entries.where((e) => e.value == "sevdi").map((e) => e.key).toSet();
}

/// babyId -> list of reminder maps.
/// Reminder shape:
/// { "id": String, "type": "retry", "foodName": String,
///   "date": "yyyy-MM-dd", "title": String, "done": bool }
final Map<String, List<Map<String, dynamic>>> globalReminders = {};

/// babyId -> list of supplement/medication definitions.
/// Def shape: { "id", "name", "dose", "schedule", "type"("takviye"|"ilac"), "active" }
final Map<String, List<Map<String, dynamic>>> globalBabyMeds = {};

/// babyId -> dateKey(yyyy-MM-dd) -> daily log.
/// Log shape: {
///   "cisList":  [ {"color": "koyu"|"orta"|"açık"} ],   // one per wet diaper
///   "kakaList": [ {"consistency": "Sulu"|"Yumuşak"|"Normal"|"Katı"} ], // per poop
///   "su": int,                  // water intake in millilitres (ml)
///   "taken": { defId: bool },   // medication taken toggles
///   "feeds": [ ... ],           // emzirme/sağılmış süt/mama kayıtları
///   "mealStatus": { slot: "hepsi"|"biraz"|"tadi"|"yemedi" }  // öğünü yedi mi
/// }
final Map<String, Map<String, dynamic>> globalDailyLogs = {};

/// Kullanıcının kendi eklediği formül mama adları (admin listesine ek olarak
/// beslenme takibi açılır menüsünde görünür). Kullanıcı verisi olarak senkronlanır.
final List<String> globalUserFormulaNames = [];

/// A (baby, day) feeding list — emzirme / sağılmış süt / mama kayıtları.
/// Entry shape: {"type":"emzirme"|"sagilmis"|"formul", "formula":String,
///               "amount":String, "unit":String, "breast":String,
///               "duration":String, "time":"HH:mm"}
/// Miktar (ml) hem "formul" hem "sagilmis" için geçerli — sağılmış anne sütü de
/// biberonla verildiğinden ölçülebiliyor.
///
/// Döndürülen liste CANLI: üzerine `add`/`removeAt` yapmak günlüğe yazar.
List<Map<String, dynamic>> feedsFor(String babyId, String dateKey) {
  final log = dailyLog(babyId, dateKey);
  return (log["feeds"] as List).cast<Map<String, dynamic>>();
}

/// All supplement/med definitions for a baby (mutable list, created if absent).
List<Map<String, dynamic>> medsFor(String babyId) =>
    globalBabyMeds.putIfAbsent(babyId, () => []);

/// The mutable daily-log map for a (baby, day). Ensures all keys exist and
/// migrates the old `{cis:int, kaka:int}` shape to the per-diaper lists.
Map<String, dynamic> dailyLog(String babyId, String dateKey) {
  final forBaby = globalDailyLogs.putIfAbsent(babyId, () => {});
  var log = forBaby[dateKey] as Map<String, dynamic>?;
  if (log == null) {
    log = <String, dynamic>{
      "cisList": <Map<String, dynamic>>[],
      "kakaList": <Map<String, dynamic>>[],
      "su": 0,
      "taken": <String, dynamic>{},
      "mood": "", // "uzgun" | "normal" | "mutlu" — baby's general mood that day
      "note": "", // mother's free-text note for the day
      "feeds": <Map<String, dynamic>>[], // emzirme/sağılmış süt/mama kayıtları
      "mealStatus": <String, dynamic>{}, // öğün -> "hepsi"|"biraz"|"tadi"|"yemedi"
    };
    forBaby[dateKey] = log;
    return log;
  }
  // Migrate / ensure keys (handles legacy int counts).
  //
  // ⚠️ NORMALLEŞTİRME YALNIZCA BİR KEZ: eskiden bu üç liste HER çağrıda
  // `.map(...).toList()` ile yeniden üretiliyordu; yani `dailyLog()` her
  // çağrıldığında liste KİMLİĞİ değişiyordu. Bir ekran listeyi alıp elinde
  // tutarken (ör. "Beslenme Ekle" penceresi açıkken) araya bir yeniden çizim
  // girince eldeki liste öksüz kalıyor, "Kaydet" o öksüz listeye yazdığı için
  // kayıt ne ekranda görünüyor ne de diske yazılıyordu — kullanıcı tarafında
  // "buton çalışmıyor" olarak görülen hata buydu.
  //
  // Çözüm: liste zaten doğru tipteyse dokunma. `.map((e) => Map<String,
  // dynamic>.from(e)).toList()` sonucu `List<Map<String, dynamic>>` olduğundan
  // ilk dönüşümden sonra bu kontrol hep true döner → kimlik sabit kalır.
  final cis = log["cisList"];
  if (cis == null) {
    final c = (log["cis"] as num?)?.toInt() ?? 0;
    log["cisList"] = List<Map<String, dynamic>>.generate(c, (_) => {"color": "orta"});
  } else if (cis is! List<Map<String, dynamic>>) {
    log["cisList"] = (cis as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  final kaka = log["kakaList"];
  if (kaka == null) {
    final k = (log["kaka"] as num?)?.toInt() ?? 0;
    log["kakaList"] = List<Map<String, dynamic>>.generate(k, (_) => {"consistency": "Normal"});
  } else if (kaka is! List<Map<String, dynamic>>) {
    log["kakaList"] = (kaka as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  log["su"] = (log["su"] as num?)?.toInt() ?? 0;
  log["taken"] ??= <String, dynamic>{};
  log["mood"] ??= "";
  log["note"] ??= "";
  final feeds = log["feeds"];
  if (feeds == null) {
    log["feeds"] = <Map<String, dynamic>>[];
  } else if (feeds is! List<Map<String, dynamic>>) {
    log["feeds"] = (feeds as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  final ms = log["mealStatus"];
  if (ms == null) {
    log["mealStatus"] = <String, dynamic>{};
  } else if (ms is! Map<String, dynamic>) {
    log["mealStatus"] = Map<String, dynamic>.from(ms as Map);
  }
  return log;
}

// ---- Öğün tamamlama durumu (kahvaltı/öğle/… için "yedi mi?") ----

/// Geçerli durum anahtarları ve kullanıcıya görünen karşılıkları.
/// Sıra bilinçli: en olumludan en olumsuza.
const List<(String, String, String)> kMealStatusOptions = [
  ("hepsi", "😋", "Hepsini yedi"),
  ("biraz", "🙂", "Bir kısmını yedi"),
  ("tadi", "😐", "Tadına baktı"),
  ("yemedi", "🙁", "Yemedi"),
];

/// Bir (bebek, gün, öğün) için kayıtlı durum; yoksa null.
String? mealStatus(String babyId, String dateKey, String slot) {
  final v = (dailyLog(babyId, dateKey)["mealStatus"] as Map)[slot];
  final s = v?.toString() ?? "";
  return s.isEmpty ? null : s;
}

/// Durumu yazar; [value] null ise kaydı siler (yanlış dokunuş geri alınabilsin).
void setMealStatus(String babyId, String dateKey, String slot, String? value) {
  final m = dailyLog(babyId, dateKey)["mealStatus"] as Map;
  if (value == null) {
    m.remove(slot);
  } else {
    m[slot] = value;
  }
}

/// Durum anahtarının emojisi (bilinmeyen anahtar → boş).
String mealStatusEmoji(String? key) {
  for (final o in kMealStatusOptions) {
    if (o.$1 == key) return o.$2;
  }
  return "";
}

/// Durum anahtarının etiketi (bilinmeyen anahtar → boş).
String mealStatusLabel(String? key) {
  for (final o in kMealStatusOptions) {
    if (o.$1 == key) return o.$3;
  }
  return "";
}

/// Days (newest first) that have a recorded mood or note, for the report.
/// Returns a list of { "date", "mood", "note" }.
List<Map<String, String>> moodNoteHistory(String babyId) {
  final forBaby = globalDailyLogs[babyId];
  if (forBaby == null) return [];
  final out = <Map<String, String>>[];
  forBaby.forEach((dateKey, log) {
    final m = (log as Map)["mood"]?.toString() ?? "";
    final n = log["note"]?.toString() ?? "";
    if (m.isNotEmpty || n.trim().isNotEmpty) {
      out.add({"date": dateKey, "mood": m, "note": n});
    }
  });
  out.sort((a, b) => b["date"]!.compareTo(a["date"]!));
  return out;
}

/// Emoji for a stored mood key.
String moodEmoji(String mood) {
  switch (mood) {
    case "uzgun":
      return "😢";
    case "normal":
      return "😐";
    case "mutlu":
      return "😄";
    default:
      return "";
  }
}

/// Returns the mutable state map for a (baby, food), creating it if absent.
Map<String, dynamic> ensureFoodState(String babyId, String foodName) {
  final forBaby = globalBabyFoodStates.putIfAbsent(babyId, () => {});
  return (forBaby[foodName] as Map<String, dynamic>?) ??
      (forBaby[foodName] = <String, dynamic>{
        "tried": false,
        "favorite": false,
        "status": null,
        "triedDate": null,
        "reactionNote": null,
        "retryDate": null,
      });
}

/// Reads a (baby, food) state without creating it. Returns null if untracked.
Map<String, dynamic>? readFoodState(String babyId, String foodName) {
  final forBaby = globalBabyFoodStates[babyId];
  if (forBaby == null) return null;
  return forBaby[foodName] as Map<String, dynamic>?;
}

bool isTried(String babyId, String foodName) =>
    readFoodState(babyId, foodName)?["tried"] == true;

bool isFavorite(String babyId, String foodName) =>
    readFoodState(babyId, foodName)?["favorite"] == true;

/// Names of every food the baby has tried.
Set<String> triedFoodNames(String babyId) {
  final forBaby = globalBabyFoodStates[babyId];
  if (forBaby == null) return {};
  return forBaby.entries
      .where((e) => (e.value as Map)["tried"] == true)
      .map((e) => e.key)
      .toSet();
}

int triedCount(String babyId) => triedFoodNames(babyId).length;

/// Count of foods that produced an allergic reaction.
int reactionCount(String babyId) {
  final forBaby = globalBabyFoodStates[babyId];
  if (forBaby == null) return 0;
  return forBaby.values
      .where((s) => (s as Map)["status"] == "reaksiyon")
      .length;
}

/// Adds or updates a "retry" reminder for a reacted food. Pass [millis] for a
/// unique id (use DateTime.now().millisecondsSinceEpoch from the caller).
void upsertRetryReminder(
  String babyId,
  String foodName,
  String retryDateIso,
  int millis,
) {
  final list = globalReminders.putIfAbsent(babyId, () => []);
  final existing = list.firstWhere(
    (r) => r["type"] == "retry" && r["foodName"] == foodName,
    orElse: () => <String, dynamic>{},
  );
  if (existing.isNotEmpty) {
    existing["date"] = retryDateIso;
    existing["done"] = false;
    existing["title"] = "$foodName'i tekrar dene";
  } else {
    list.add({
      "id": "r_${millis}_${list.length}",
      "type": "retry",
      "foodName": foodName,
      "date": retryDateIso,
      "title": "$foodName'i tekrar dene",
      "done": false,
    });
  }
}

/// Removes any retry reminder tied to a food (e.g. when reaction is cleared).
void removeRetryReminder(String babyId, String foodName) {
  globalReminders[babyId]
      ?.removeWhere((r) => r["type"] == "retry" && r["foodName"] == foodName);
}

/// Reminders for a baby on a specific date (yyyy-MM-dd), not yet done.
List<Map<String, dynamic>> remindersForDay(String babyId, String dateIso) {
  final list = globalReminders[babyId];
  if (list == null) return [];
  return list
      .where((r) => r["date"] == dateIso && r["done"] != true)
      .toList();
}

/// Upcoming reminders (today or later), sorted ascending by date.
List<Map<String, dynamic>> upcomingReminders(String babyId, String todayIso) {
  final list = globalReminders[babyId];
  if (list == null) return [];
  final upcoming = list
      .where((r) => r["done"] != true && (r["date"] as String).compareTo(todayIso) >= 0)
      .toList();
  upcoming.sort((a, b) => (a["date"] as String).compareTo(b["date"] as String));
  return upcoming;
}
