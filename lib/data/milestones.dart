// Development & teeth milestones (general guidance; every baby differs).

class Milestone {
  final String id;
  final String title;
  final String category; // Motor | Diş | Beslenme | Dil/Sosyal
  final int minMonth;
  final int maxMonth;
  const Milestone(this.id, this.title, this.category, this.minMonth, this.maxMonth);
}

const List<Milestone> kMilestones = [
  // 0–3 ay
  Milestone("m1", "Başını dik tutmaya başlar", "Motor", 0, 3),
  Milestone("m2", "Gülümser, seslere tepki verir", "Dil/Sosyal", 0, 3),
  Milestone("m3", "Yalnızca anne sütü/mama ile beslenir", "Beslenme", 0, 6),
  // 4–6 ay
  Milestone("m4", "Destekli oturur", "Motor", 4, 6),
  Milestone("m5", "Nesneleri kavrar, ağzına götürür", "Motor", 4, 6),
  Milestone("m6", "Ek gıdaya hazır oluş işaretleri", "Beslenme", 5, 6),
  Milestone("m7", "İlk ek gıdalar / püreler", "Beslenme", 6, 7),
  // 7–9 ay
  Milestone("m8", "Desteksiz oturur", "Motor", 7, 9),
  Milestone("m9", "Emekler", "Motor", 8, 10),
  Milestone("m10", "İlk dişler (alt kesiciler) çıkar", "Diş", 6, 10),
  Milestone("m11", "Parmak besinlere geçer", "Beslenme", 8, 10),
  Milestone("m12", "\"ba-ba\", \"ma-ma\" heceler", "Dil/Sosyal", 8, 10),
  // 10–12 ay
  Milestone("m13", "Tutunarak ayağa kalkar", "Motor", 9, 12),
  Milestone("m14", "Pinça kavrama (parmak uçlarıyla)", "Motor", 9, 12),
  Milestone("m15", "Tutunarak yürür / ilk adımlar", "Motor", 11, 13),
  Milestone("m16", "Kaşığı kendi tutmaya çalışır", "Beslenme", 10, 12),
  Milestone("m17", "Üst kesici dişler çıkar", "Diş", 9, 12),
  // 12–18 ay
  Milestone("m18", "Bağımsız yürür", "Motor", 12, 15),
  Milestone("m19", "Birkaç kelime söyler", "Dil/Sosyal", 12, 18),
  Milestone("m20", "Aile sofrasına katılır, parça besinler", "Beslenme", 12, 18),
  Milestone("m21", "İlk azı dişleri çıkar", "Diş", 12, 18),
  // 18–24 ay
  Milestone("m22", "Koşar, destekli merdiven çıkar", "Motor", 18, 24),
  Milestone("m23", "2 kelimeli cümleler kurar", "Dil/Sosyal", 18, 24),
  Milestone("m24", "Kaşıkla kendi başına yer", "Beslenme", 18, 24),
  Milestone("m25", "Köpek/azı dişleri tamamlanır", "Diş", 18, 30),
];
