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
///   "retryDate": "yyyy-MM-dd" | null }
final Map<String, Map<String, dynamic>> globalBabyFoodStates = {};

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
///   "su": int,                  // water servings
///   "taken": { defId: bool }    // medication taken toggles
/// }
final Map<String, Map<String, dynamic>> globalDailyLogs = {};

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
    };
    forBaby[dateKey] = log;
    return log;
  }
  // Migrate / ensure keys (handles legacy int counts).
  if (log["cisList"] == null) {
    final c = (log["cis"] as num?)?.toInt() ?? 0;
    log["cisList"] = List<Map<String, dynamic>>.generate(c, (_) => {"color": "orta"});
  } else {
    log["cisList"] = (log["cisList"] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (log["kakaList"] == null) {
    final k = (log["kaka"] as num?)?.toInt() ?? 0;
    log["kakaList"] = List<Map<String, dynamic>>.generate(k, (_) => {"consistency": "Normal"});
  } else {
    log["kakaList"] = (log["kakaList"] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  log["su"] = (log["su"] as num?)?.toInt() ?? 0;
  log["taken"] ??= <String, dynamic>{};
  log["mood"] ??= "";
  log["note"] ??= "";
  return log;
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
