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

/// babyId -> list of uploaded report/document files (e.g. e-Nabız PDFs).
/// Item shape: { "name": String, "date": "yyyy-MM-dd", "dataUri": "data:application/pdf;base64,..." }
/// Stored LOCALLY only for now (files are large); moves to Firebase Storage in Faz 4.
final Map<String, List<Map<String, dynamic>>> globalReportFiles = {};

/// Uploaded documents for a baby (mutable list, created if absent).
List<Map<String, dynamic>> reportFilesFor(String babyId) =>
    globalReportFiles.putIfAbsent(babyId, () => []);

/// Temporary ad-free window earned by watching a rewarded ad (ISO8601), or null.
/// While active (and the user isn't premium), ad banners are hidden.
String? globalAdFreeUntil;

/// True if a rewarded ad-free window is currently active.
bool adFreeActive() {
  final s = globalAdFreeUntil;
  if (s == null) return false;
  final until = DateTime.tryParse(s);
  return until != null && until.isAfter(DateTime.now());
}
