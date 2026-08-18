// Ek gıdaya geçiş gelişim basamakları (yaşa göre). Genel rehberdir; her bebek
// farklı ilerler. Ek gıdaya başlama kararı ve besin seçimi için çocuk
// doktoruna danışılmalıdır (DSÖ ~6. ay önerir).

class FeedingStep {
  final String id;
  final String title;
  final int minMonth;
  final int maxMonth;
  final String emoji;
  final String summary;
  final List<String> tips;
  const FeedingStep(this.id, this.title, this.minMonth, this.maxMonth,
      this.emoji, this.summary, this.tips);
}

const List<FeedingStep> kFeedingSteps = [
  FeedingStep(
    "fs0",
    "Yalnızca süt dönemi",
    0,
    5,
    "🍼",
    "İlk ~6 ay yalnızca anne sütü (veya mama). Ek gıdaya henüz erken.",
    [
      "Anne sütü ilk 6 ay tek başına yeterlidir.",
      "Su, çay, ek besin bu dönemde önerilmez.",
      "Ek gıdaya geçiş için hazır oluş işaretlerini bekleyin.",
    ],
  ),
  FeedingStep(
    "fs1",
    "Ek gıdaya hazır oluş",
    5,
    6,
    "✅",
    "Genelde 6. ay civarı. Hazır oluş işaretleri bir arada görülmeli.",
    [
      "Baş ve boynunu dik tutabiliyor.",
      "Destekle oturabiliyor.",
      "Dil-itme (besini dışarı itme) refleksi azalmış.",
      "Yemeğe ilgi gösteriyor, ağzını açıyor.",
    ],
  ),
  FeedingStep(
    "fs2",
    "İlk ek gıdalar (püre)",
    6,
    7,
    "🥣",
    "Tek besinli, pürüzsüz püreler. Yeni besinleri 3 gün arayla deneyin.",
    [
      "Sebze/meyve püreleri, iyi pişmiş tahıllar.",
      "Her yeni besinde 3 gün bekleyip alerji gözleyin.",
      "Tuz ve şeker eklemeyin.",
      "Az miktarla başlayın; süt ana besin olmaya devam eder.",
    ],
  ),
  FeedingStep(
    "fs3",
    "Ezme ve parmak besinleri",
    8,
    10,
    "🥑",
    "Kıvamı kalınlaştırın; yumuşak parmak besinleriyle kendi kendine yeme.",
    [
      "Ezilmiş/küçük yumuşak parçalar (avokado, muz, iyi pişmiş sebze).",
      "Bebeğin kendi eliyle tutup yemesine izin verin.",
      "Boğulma riskli besinlerden kaçının (bütün üzüm, fındık, sert parçalar).",
      "Protein kaynaklarını (yumurta, et, mercimek) ekleyin.",
    ],
  ),
  FeedingStep(
    "fs4",
    "Küçük parçalar ve kaşık",
    10,
    12,
    "🥄",
    "Aile yemeğine yakın kıvam; kaşığı kendi tutmayı dener.",
    [
      "Küçük, yumuşak lokmalar; çeşitliliği artırın.",
      "Kaşıkla kendi yeme denemelerini destekleyin (dağıtması normal).",
      "Öğün düzenine geçin (3 ana + ara).",
      "Bardaktan su içmeyi tanıtın.",
    ],
  ),
  FeedingStep(
    "fs5",
    "Aile sofrası",
    12,
    24,
    "🍽️",
    "Artık aile sofrasına katılır. 12. aydan sonra inek sütü verilebilir.",
    [
      "Aynı yemekten (tuzu/şekeri az) uygun kıvamda verin.",
      "12 aydan sonra tam yağlı inek sütüne geçilebilir.",
      "Öğün ve atıştırmalıkları düzene oturtun.",
      "Bal 12 aydan önce KESİNLİKLE verilmez.",
    ],
  ),
];
