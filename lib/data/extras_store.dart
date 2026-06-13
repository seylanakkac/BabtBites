// Extra engagement/premium state (local; persisted by StorageService).
// - Growth measurements over time (for the growth chart).
// - Milestone "done" toggles (development & teeth calendar).
// - Premium (BabyBites+) flag + trial start (real billing comes later with
//   store in-app purchase / Firebase).

/// babyId -> list of measurements.
/// Shape: { "date":"yyyy-MM-dd", "weight":double, "height":double, "head":double }
final Map<String, List<Map<String, dynamic>>> globalGrowthRecords = {};

List<Map<String, dynamic>> growthFor(String babyId) =>
    globalGrowthRecords.putIfAbsent(babyId, () => []);

/// babyId -> set of completed milestone ids.
final Map<String, Set<String>> globalMilestonesDone = {};

Set<String> milestonesDoneFor(String babyId) =>
    globalMilestonesDone.putIfAbsent(babyId, () => <String>{});

/// BabyBites+ premium flag (demo). When store IAP / Firebase is added, this is
/// driven by the real subscription state.
bool globalIsPremium = false;

/// ISO date the free trial started (or null).
String? globalTrialStart;
