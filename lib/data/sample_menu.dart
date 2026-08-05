import 'admin_store.dart';

/// Haftanın günleri — örnek menülerde ve kullanıcının takvimine kopyalarken
/// aynı sıra kullanılır (Pazartesi = haftanın ilk günü).
const List<String> kWeekDays = [
  "Pazartesi",
  "Salı",
  "Çarşamba",
  "Perşembe",
  "Cuma",
  "Cumartesi",
  "Pazar",
];

/// Admin'in hazırladığı örnek haftalık menü.
///
/// Kullanıcılar inceleyip tek tek tarif ekleyebilir ya da tüm haftayı kendi
/// takvimlerine kopyalayabilir. Veri `globalAdminConfig["sampleMenus"]`
/// altında tutulur; bu alan `admin_config` anahtarının parçası olduğu için
/// CatalogSync ile herkese senkronlanır (yeni sürüm gerekmez).
class SampleMenu {
  final String id;
  final String title;

  /// 1-12 arası ay; 0 = her ay geçerli.
  final int month;

  /// Hedef bebek yaşı (ay). 0 = belirtilmemiş.
  final int ageMonths;

  final String note;

  /// gün adı → öğün adı → kalemler
  final Map<String, Map<String, List<String>>> days;

  const SampleMenu({
    required this.id,
    required this.title,
    this.month = 0,
    this.ageMonths = 0,
    this.note = "",
    this.days = const {},
  });

  /// Menüdeki toplam kalem sayısı (kartta "12 öğün" gibi göstermek için).
  int get itemCount =>
      days.values.fold(0, (a, slots) => a + slots.values.fold(0, (b, l) => b + l.length));

  bool get isEmpty => itemCount == 0;

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "month": month,
        "ageMonths": ageMonths,
        "note": note,
        "days": days.map((d, slots) => MapEntry(d, slots.map((s, l) => MapEntry(s, l)))),
      };

  /// Bozuk/eksik kayıt uygulamayı düşürmesin diye her alan savunmacı çözülür.
  static SampleMenu fromJson(Map<String, dynamic> j) {
    final rawDays = j["days"];
    final days = <String, Map<String, List<String>>>{};
    if (rawDays is Map) {
      rawDays.forEach((d, slots) {
        if (slots is! Map) return;
        final m = <String, List<String>>{};
        slots.forEach((s, items) {
          if (items is! List) return;
          m[s.toString()] = items.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        });
        days[d.toString()] = m;
      });
    }
    int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse("$v") ?? 0);
    return SampleMenu(
      id: (j["id"] ?? "").toString(),
      title: (j["title"] ?? "").toString(),
      month: asInt(j["month"]),
      ageMonths: asInt(j["ageMonths"]),
      note: (j["note"] ?? "").toString(),
      days: days,
    );
  }
}

/// Yayınlanmış örnek menüler.
List<SampleMenu> sampleMenus() {
  final raw = globalAdminConfig["sampleMenus"];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => SampleMenu.fromJson(Map<String, dynamic>.from(m)))
      .where((m) => m.title.trim().isNotEmpty)
      .toList();
}

/// Ana sayfada gösterilecek menüler: içinde bulunulan aya ait olanlar önce,
/// sonra "her ay" olanlar. Boş menüler gösterilmez.
List<SampleMenu> sampleMenusForMonth(int month) {
  final all = sampleMenus().where((m) => !m.isEmpty).toList();
  final thisMonth = all.where((m) => m.month == month).toList();
  final anyMonth = all.where((m) => m.month == 0).toList();
  return [...thisMonth, ...anyMonth];
}

void setSampleMenus(List<SampleMenu> menus) {
  globalAdminConfig["sampleMenus"] = menus.map((m) => m.toJson()).toList();
}

const List<String> kMonthNames = [
  "Her ay",
  "Ocak",
  "Şubat",
  "Mart",
  "Nisan",
  "Mayıs",
  "Haziran",
  "Temmuz",
  "Ağustos",
  "Eylül",
  "Ekim",
  "Kasım",
  "Aralık",
];
