import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/web_shell.dart';

/// Uygulamadaki sağlık/beslenme bilgilerinin dayandığı kaynakların listesi.
///
/// App Store Review Guideline 1.4.1: tıbbi bilgi içeren uygulamalar, verdikleri
/// bilgilerin kaynaklarına atıf yapmak zorundadır ve bu atıflar kullanıcının
/// kolayca bulabileceği yerde olmalıdır. Bu ekrana, tıbbi bilgi gösterilen her
/// yerdeki [MedicalDisclaimer] bileşeninden "Kaynaklar" bağlantısıyla ulaşılır.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static const _primary = Color(0xFFFF7A45);
  static const _text = Color(0xFF2D2D3A);
  static const _light = Color(0xFFA8A8B3);
  static const _bg = Color(0xFFFAF9F6);

  /// (Kurum, ne için kullanıldığı, bağlantı)
  static const _sources = <List<String>>[
    [
      "Dünya Sağlık Örgütü (WHO) — Tamamlayıcı Beslenme",
      "Ek gıdaya geçiş zamanı, öğün sıklığı ve besin çeşitliliğine ilişkin genel öneriler.",
      "https://www.who.int/health-topics/complementary-feeding",
    ],
    [
      "WHO — Çocuk Büyüme Standartları",
      "Büyüme grafiğindeki boy/kilo persentil bantları ve değerlendirme aralıkları.",
      "https://www.who.int/tools/child-growth-standards",
    ],
    [
      "T.C. Sağlık Bakanlığı — Halk Sağlığı Genel Müdürlüğü",
      "Türkiye'ye özgü bebek ve çocuk beslenmesi önerileri, ek gıdaya geçiş rehberleri.",
      "https://hsgm.saglik.gov.tr",
    ],
    [
      "American Academy of Pediatrics (HealthyChildren.org)",
      "Alerjen gıdaların tanıtılması, 3 gün kuralı ve boğulma riski taşıyan gıdalar/kesim şekilleri.",
      "https://www.healthychildren.org",
    ],
    [
      "USDA FoodData Central",
      "Gıdaların ve tariflerin besin değerleri (kalori, protein, yağ, karbonhidrat, vitamin/mineral).",
      "https://fdc.nal.usda.gov",
    ],
  ];

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bağlantı açılamadı: $url")),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bağlantı açılamadı: $url")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => webPageShell(context, child: _body(context));

  Widget _body(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Bilgi Kaynaklarımız",
            style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28 + MediaQuery.of(context).padding.bottom),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8C879).withOpacity(0.5)),
            ),
            child: const Text(
              "BabyBites'taki beslenme ve gelişim bilgileri aşağıdaki kurumların yayımladığı "
              "rehberlere dayanır. Bu bilgiler genel bilgilendirme amaçlıdır ve tıbbi tavsiye "
              "yerine geçmez. Bebeğinizin beslenmesi ve sağlığıyla ilgili kararlar için mutlaka "
              "çocuk doktorunuza danışın.",
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF8A7A4A), height: 1.45),
            ),
          ),
          const SizedBox(height: 18),
          ..._sources.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.7)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(context, s[2]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s[0],
                                  style: const TextStyle(
                                      fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                            ),
                            const Icon(Icons.open_in_new, size: 16, color: _primary),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(s[1],
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light, height: 1.4)),
                        const SizedBox(height: 8),
                        Text(s[2],
                            style: const TextStyle(
                                fontFamily: 'Inter', fontSize: 11, color: _primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 6),
          const Text(
            "Uzman rozetli içerikler, ilgili sağlık profesyoneli tarafından hazırlanmış veya "
            "incelenmiştir. Kullanıcıların paylaştığı tarifler kaynak kapsamı dışındadır.",
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light, height: 1.4),
          ),
        ],
      ),
    );
  }
}
