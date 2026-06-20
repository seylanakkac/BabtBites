import 'package:flutter/material.dart';
import '../data/admin_store.dart';
import '../widgets/ad_banner.dart';
import '../widgets/disclaimer.dart';
import '../widgets/image_helpers.dart';
import '../widgets/sponsored_badge.dart';
import '../widgets/web_embed.dart';
import '../widgets/web_shell.dart';
import 'premium_screen.dart';

class Article {
  final String id;
  final String title;
  final String category;
  final String readTime;
  final String summary;
  final String content;
  final String emoji;
  final String imageUrl; // optional photo (base64 data URI / URL); empty = use emoji
  final bool sponsored; // admin-flagged sponsored content
  final String sponsorLabel; // brand/sponsor name shown on the "Sponsorlu" badge
  final String author; // "Hazırlayan" — yazıyı hazırlayan
  /// Zengin içerik blokları. Boşsa düz [content] gösterilir. Blok şekilleri:
  /// {"t":"text","v":String,"color":"#RRGGBB","size":double,"bold":bool}
  /// {"t":"image","v":urlString,"w":int(40-100)}
  /// {"t":"youtube","v":urlString}  {"t":"video","v":urlString}
  final List<Map<String, dynamic>> blocks;

  const Article({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.summary,
    required this.content,
    required this.emoji,
    this.imageUrl = "",
    this.sponsored = false,
    this.sponsorLabel = "",
    this.author = "",
    this.blocks = const [],
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "category": category,
        "readTime": readTime,
        "summary": summary,
        "content": content,
        "emoji": emoji,
        "imageUrl": imageUrl,
        "sponsored": sponsored,
        "sponsorLabel": sponsorLabel,
        "author": author,
        "blocks": blocks,
      };

  factory Article.fromJson(Map<String, dynamic> j) => Article(
        id: j["id"]?.toString() ?? "",
        title: j["title"]?.toString() ?? "",
        category: j["category"]?.toString() ?? "",
        readTime: j["readTime"]?.toString() ?? "",
        summary: j["summary"]?.toString() ?? "",
        content: j["content"]?.toString() ?? "",
        emoji: j["emoji"]?.toString() ?? "📝",
        imageUrl: j["imageUrl"]?.toString() ?? "",
        sponsored: j["sponsored"] == true,
        sponsorLabel: j["sponsorLabel"]?.toString() ?? "",
        author: j["author"]?.toString() ?? "",
        blocks: (j["blocks"] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
      );
}

/// "#RRGGBB" → Color (alfa eklenir). Geçersizse [fallback].
Color articleHexColor(String hex, Color fallback) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v != null ? Color(v) : fallback;
}

/// Bir makalenin gövdesini bloklardan (veya boşsa düz [content]) render eder.
List<Widget> renderArticleBlocks(Article a) {
  const bodyColor = Color(0xFF2D2D3A);
  if (a.blocks.isEmpty) {
    return [
      Text(a.content, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: bodyColor, height: 1.5)),
    ];
  }
  final out = <Widget>[];
  for (final b in a.blocks) {
    final t = b["t"]?.toString() ?? "text";
    if (t == "image") {
      final url = b["v"]?.toString() ?? "";
      final w = (((b["w"] as num?)?.toDouble() ?? 100).clamp(20, 100)) / 100;
      if (url.isNotEmpty) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: w.toDouble(),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
            ),
          ),
        ));
      }
    } else if (t == "youtube" || t == "video") {
      final url = b["v"]?.toString() ?? "";
      if (url.isNotEmpty) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: mediaEmbed(youtube: t == "youtube", url: url)),
        ));
      }
    } else {
      final size = (b["size"] as num?)?.toDouble() ?? 15;
      final bold = b["bold"] == true;
      final color = articleHexColor(b["color"]?.toString() ?? "", bodyColor);
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(b["v"]?.toString() ?? "", style: TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, height: 1.5)),
      ));
    }
  }
  return out;
}

/// Admin-added articles, merged into the list shown by ArticlesScreen.
final List<Article> globalCustomArticles = [];

/// Built-in + admin-added articles, with admin overrides applied and deleted
/// ones hidden. Shared by ArticlesScreen and the admin panel.
List<Article> getAllArticles() {
  final all = <Article>[..._ArticlesScreenState._builtInArticles(), ...globalCustomArticles];
  return all
      .where((a) => !globalDeletedArticles.contains(a.id))
      .map((a) => globalArticleOverrides.containsKey(a.id) ? Article.fromJson(globalArticleOverrides[a.id]!) : a)
      .toList();
}

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "Tümü";

  // List of categories
  // Categories are admin-configurable; "Tümü" is always first.
  List<String> get _categories => ["Tümü", ...articleCategories];

  // 50 ek gıda / baby feeding articles database
  static const List<Article> _articles = [
    Article(
      id: "a1",
      title: "3 Gün Kuralı Nedir ve Nasıl Uygulanır?",
      category: "Alerji",
      readTime: "3 dk",
      summary: "Yeni besinlerle tanışırken alerji riskini en aza indiren altın kuralı öğrenin.",
      emoji: "🥦",
      content: "Ek gıdaya geçerken bebeklerin yeni tanıştığı besinlere karşı alerjik bir reaksiyon gösterip göstermediğini anlamak için uygulanan en güvenli yöntem 3 gün kuralıdır.\n\n"
          "Nasıl Uygulanır?\n"
          "1. Bebeğinize yeni bir gıdayı (örneğin havuç) ilk gün 1 çay kaşığı kadar verin.\n"
          "2. İkinci gün miktarı 1 tatlı kaşığına çıkarın.\n"
          "3. Üçüncü gün ise 1 yemek kaşığı kadar sunabilirsiniz.\n"
          "4. Bu 3 gün boyunca başka hiçbir yeni gıda tanıtmayın. Daha önce güvenle yediği gıdaları vermeye devam edebilirsiniz.\n\n"
          "Dikkat Edilmesi Gerekenler:\n"
          "Ciltte döküntü, kızarıklık, kusma veya ishal gibi belirtileri takip edin. Bir reaksiyon görürseniz gıdayı hemen kesin ve doktorunuza başvurun.",
    ),
    Article(
      id: "a2",
      title: "Bebekler İçin İlk Ek Gıdalar Neler Olmalıdır?",
      category: "Başlangıç",
      readTime: "4 dk",
      summary: "6. ayda bebeğinize sunabileceğiniz en güvenli ve besleyici ilk sebze ve meyveler.",
      emoji: "🥕",
      content: "Bebeklerin sindirim sistemi 6. aya kadar sadece anne sütü veya formül mamayı sindirebilecek olgunluktadır. 6. aydan itibaren ise demir depolarının desteklenmesi ve farklı tatlarla tanışma amacıyla ek gıdaya başlanır.\n\n"
          "İlk Tercih Edilmesi Gereken Sebzeler:\n"
          "- Balkabağı: Lifli yapısı ve tatlı tadıyla bebekler çok sever.\n"
          "- Havuç: A vitamini deposudur, buharda haşlanıp püre yapılabilir.\n"
          "- Kabak: Sindirimi en kolay sebzelerdendir.\n\n"
          "İlk Tercih Edilmesi Gereken Meyveler:\n"
          "- Avokado: Sağlıklı yağlar açısından çok zengindir, pişirilmeden ezilebilir.\n"
          "- Elma ve Armut: Buharda haşlanarak yumuşak püreler elde edilir.\n\n"
          "Tavsiye: İlk gıdaları mutlaka pürüzsüz püre veya yumuşak ezilmiş olarak, baharatsız ve tuzsuz sunun.",
    ),
    Article(
      id: "a3",
      title: "BLW (Bebek Liderliğinde Beslenme) Nedir?",
      category: "BLW Yöntemi",
      readTime: "5 dk",
      summary: "Bebeğinizin kendi kendine beslenmesini destekleyen popüler BLW yöntemine dair ipuçları.",
      emoji: "👶",
      content: "BLW (Baby Led Weaning), bebeğin kaşıkla beslenmesi yerine kendi elleriyle besinleri kavramasına ve kendi hızında yemesine izin veren beslenme yöntemidir.\n\n"
          "BLW'nin Faydaları:\n"
          "- Motor becerilerini ve el-göz koordinasyonunu geliştirir.\n"
          "- Doyma hissini kendisi kontrol ettiği için obezite riskini azaltır.\n"
          "- Aile sofrasına katılımı kolaylaştırır.\n\n"
          "BLW Gıdaları Nasıl Hazırlanır?\n"
          "Gıdalar bebeğin avucundan taşacak şekilde uzun ve kalın parmak şeritler halinde kesilmelidir. Buharda veya fırında, iki parmak arasında hafifçe ezilecek kadar yumuşak ama dağılmayacak dirilikte pişirilmelidir.\n\n"
          "Önemli: BLW uygularken bebek kesinlikle sofrada yalnız bırakılmamalıdır.",
    ),
    Article(
      id: "a4",
      title: "Bebeklerde Alerji Riski Yüksek 8 Besin",
      category: "Alerji",
      readTime: "4 dk",
      summary: "Ek gıda sürecinde dikkatle yaklaşılması gereken en yaygın alerjen gıdalar.",
      emoji: "🥚",
      content: "Bebek beslenmesinde bazı besinler diğerlerine göre çok daha yüksek alerji riski taşır. Bunlar tanıtılırken son derece dikkatli olunmalı ve mutlaka 3 gün kuralı uygulanmalıdır.\n\n"
          "En Yaygın 8 Alerjen Besin:\n"
          "1. İnek Sütü (1 yaşından önce doğrudan içirilmemelidir)\n"
          "2. Yumurta (Özellikle beyazı yüksek alerjendir, sarısı 8. ayda başlanabilir)\n"
          "3. Balık ve Deniz Ürünleri\n"
          "4. Glüten içeren Tahıllar (Buğday vb.)\n"
          "5. Kuruyemişler (Yer fıstığı, ceviz vb. mutlaka ince çekilmiş sunulmalıdır)\n"
          "6. Soya Ürünleri\n"
          "7. Susam\n"
          "8. Kereviz\n\n"
          "Öneri: Bu besinleri sabah saatlerinde deneyin ki gün içinde olası reaksiyonları gözlemleme şansınız olsun.",
    ),
    Article(
      id: "a5",
      title: "Bebeklerde Su Tüketimi Ne Zaman Başlamalı?",
      category: "Başlangıç",
      readTime: "3 dk",
      summary: "Ek gıdayla birlikte başlayan su ihtiyacını doğru miktarlarda karşılayın.",
      emoji: "💧",
      content: "İlk 6 ay anne sütü veya formül mama alan bebeklerin ekstra su ihtiyacı yoktur; çünkü anne sütünün %80'den fazlası sudur. Ancak 6. aydan itibaren ek gıdanın başlamasıyla su verilmesi gerekir.\n\n"
          "Neden Su Verilmelidir?\n"
          "Ek gıdalar daha katı olduğu için böbreklere binen yükü azaltmak ve kabızlığı önlemek adına suya ihtiyaç duyulur.\n\n"
          "Ne Kadar Verilmelidir?\n"
          "- 6-12 ay arasında: Günlük 60-120 ml (yarım çay bardağı kadar) su yeterlidir.\n"
          "- Su yemeklerin arkasından veya aralarında küçük yudumlarla sunulabilir.\n\n"
          "Not: Suyun mutlaka kaynatılıp ılıtılmış temiz içme suyu olmasına özen gösterin.",
    ),
    Article(
      id: "a6",
      title: "Yumurta Sarısı Bebeklere Nasıl Tanıtılır?",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Harika bir demir ve protein deposu olan yumurta sarısını bebeğinize güvenle sunun.",
      emoji: "🍳",
      content: "Yumurta, bebeklerin beyin gelişimi ve büyümesi için hayati besin maddeleri içerir. Yumurtanın beyazı yüksek alerji riski nedeniyle 1 yaşına kadar önerilmezken, sarısı 7. veya 8. aydan itibaren verilebilir.\n\n"
          "Nasıl Pişirilmeli ve Sunulmalı?\n"
          "1. Yumurtayı katılaşana kadar iyice haşlayın. Akından sarısını tamamen ayırın.\n"
          "2. İlk gün yumurta sarısının 1/8'i (çeyreğinin yarısı) kadarını anne sütü veya su ile ezerek püre halinde sunun.\n"
          "3. Reaksiyon olmazsa miktarı kademeli artırarak 1 tam yumurta sarısına ulaşın.\n\n"
          "Uyarı: Asla çiğ veya az pişmiş (kayısı kıvamı) yumurta sarısı vermeyin.",
    ),
    Article(
      id: "a7",
      title: "Bebek Yoğurdu Nasıl Mayalanır?",
      category: "Besinler",
      readTime: "4 dk",
      summary: "Kalsiyum ve probiyotik kaynağı ev yapımı bebek yoğurdunun püf noktaları.",
      emoji: "🥛",
      content: "Yoğurt, bebeklerin kemik gelişimi ve bağırsak florası için mükemmel bir besindir. Hazır satılan yoğurtlar yerine evde mayalamak en sağlıklısıdır.\n\n"
          "Nasıl Mayalanır?\n"
          "1. Günlük pastorize sütü veya kaynatılmış temiz taze sütü 40-45 dereceye (serçe parmağınızı ısırmayacak sıcaklık) getirin.\n"
          "2. Küçük bir kavanoza sütü alın. İçine 1 tatlı kaşığı ev yoğurdu mayası ekleyip hafifçe karıştırın.\n"
          "3. Kavanozun kapağını kapatıp etrafını kalın bir örtüyle sarın.\n"
          "4. Ilık bir ortamda 4-6 saat mayalanmaya bırakın, ardından buzdolabına kaldırıp 1 gün dinlendirin.\n\n"
          "Öneri: Bebek yoğurdunu küçük porsiyonlar halinde günlük veya gün aşırı mayalamak tazelik açısından önemlidir.",
    ),
    Article(
      id: "a8",
      title: "1 Yaşından Önce Bebeklere Verilmemesi Gerekenler",
      category: "Alerji",
      readTime: "4 dk",
      summary: "Bebek sağlığı için ciddi tehdit oluşturan yasaklı gıdaların listesi.",
      emoji: "🚫",
      content: "1 yaşına kadar bebeklerin organları ve sindirim sistemleri bazı maddeleri işleyemez. Bu gıdalar ciddi sağlık sorunlarına neden olabilir:\n\n"
          "Yasaklı Gıdalar Listesi:\n"
          "1. Bal: Botulizm adlı ölümcül zehirlenmeye yol açabilir.\n"
          "2. Tuz: Bebeklerin böbrekleri tuzu süzemez, böbrek yetmezliğine yol açabilir.\n"
          "3. Şeker: Diş çürümesi ve obeziteyi tetikler, doğal besinlerin tadını almalarını engeller.\n"
          "4. İnek Sütü: Doğrudan içilmesi kansızlık ve bağırsak kanamasına neden olabilir.\n"
          "5. Yumurta Beyazı: Yüksek alerjendir.\n"
          "6. Bakla: Favizm denilen ani kan yıkımına sebep olabilir.\n"
          "7. Çay ve Kafein: Demir emilimini engeller.\n"
          "8. Paketli ve İşlenmiş Gıdalar.",
    ),
    Article(
      id: "a9",
      title: "Bebeklerde Ek Gıdaya Geçiş Belirtileri Nelerdir?",
      category: "Başlangıç",
      readTime: "3 dk",
      summary: "Bebeğinizin ek gıdaya hazır olduğunu gösteren gelişimsel işaretler.",
      emoji: "💡",
      content: "Sadece 6 ayın dolmuş olması ek gıdaya başlamak için tek başına yeterli olmayabilir. Bebeğin gelişimsel olarak da hazır olması gerekir:\n\n"
          "Hazır Oluş Belirtileri:\n"
          "- Bebeğin destekli de olsa mama sandalyesinde dik oturabilmesi.\n"
          "- Dil çıkarma refleksinin (besinleri diliyle dışarı itme) azalmış veya kaybolmuş olması.\n"
          "- Karşısında yemek yiyenleri izlemesi, yiyeceklere uzanması ve ağzını açması.\n"
          "- Baş kontrolünün tam olması, kafasını dik tutabilmesi.\n\n"
          "Eğer bebek bu belirtileri göstermiyorsa zorlanmamalı, birkaç gün beklenmelidir.",
    ),
    Article(
      id: "a10",
      title: "Kabızlık Problemi ve Çözüm Önerileri",
      category: "Rutinler",
      readTime: "4 dk",
      summary: "Ek gıdayla birlikte sıkça görülen kabızlığı doğal yöntemlerle aşın.",
      emoji: "🍑",
      content: "Bebeklerin bağırsakları katı gıdalarla yeni karşılaştığı için ek gıdanın ilk haftalarında kabızlık yaşanması çok yaygındır.\n\n"
          "Kabızlığı Önlemek İçin:\n"
          "- Lifli Gıdalar Sunun: Armut, gün kurusu kayısı püresi, balkabağı ve kabak bağırsakları çalıştırır.\n"
          "- Su Tüketimini İhmal Etmeyin: Yemek sonraları mutlaka su sunun.\n"
          "- Zeytinyağı Ekleyin: Pürelerine ve çorbalarına pişme sonrası 1 tatlı kaşığı sızma zeytinyağı ekleyin.\n"
          "- Masaj Yapın: Bebeğin karnına saat yönünde dairesel masajlar yapın ve bacaklarını bisiklet çevirme hareketiyle hareket ettirin.\n\n"
          "Dikkat: Pirinç, muz ve patates kabızlığı artırabilir, bu süreçte sınırlandırılmalıdır.",
    ),
    Article(
      id: "a11",
      title: "Demir Eksikliği ve Ek Gıdadaki Önemi",
      category: "Besinler",
      readTime: "4 dk",
      summary: "Bebeklerde demir depolarını dolduracak en iyi ek gıdalar.",
      emoji: "🥩",
      content: "Bebekler doğarken vücutlarında 6 ay yetecek kadar demir deposu ile doğarlar. 6. aydan itibaren bu depolar tükenir ve anne sütündeki demir miktarı yetersiz kalır. Bu nedenle ek gıdada demir yönünden zengin besinler sunulmalıdır.\n\n"
          "Demir Deposu En İyi Besinler:\n"
          "- Kırmızı Et: 8. aydan itibaren çorbalara kıyma olarak eklenmelidir.\n"
          "- Yumurta Sarısı: Anne sütünden sonra biyoyararlanımı en yüksek demir kaynağıdır.\n"
          "- Yeşil Yapraklı Sebzeler: Ispanak ve pazı.\n"
          "- Mercimek ve Pekmez (8+ ay).\n\n"
          "Tüyo: Demir emilimini artırmak için demir zengin besinlerin yanında C vitamini içeren besinler (örneğin brokoli, kırmızı biber veya portakal) sunulabilir. (Havuç A vitamini kaynağıdır, C vitamini için tercih edilmez.)",
    ),
    // --- Vitaminler ve Mineraller (bebekler için yararları) ---
    Article(
      id: "v1",
      title: "D Vitamini Bebekler İçin Neden Önemli?",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Kemik gelişimi ve bağışıklık için D vitamininin rolü ve damla takviyesi.",
      emoji: "☀️",
      content: "D vitamini, kalsiyum ve fosforun bağırsaklardan emilmesini sağlayarak kemiklerin ve dişlerin sağlıklı gelişmesinde rol oynar. Eksikliğinde raşitizm (kemik yumuşaması) görülebilir.\n\n"
          "Bebekler için yararları:\n"
          "- Kemik ve diş gelişimini destekler.\n"
          "- Bağışıklık sistemini güçlendirir.\n\n"
          "Kaynak ve takviye:\n"
          "Güneş ışığıyla ciltte üretilir; ancak bebeklerde yeterli olmadığından Sağlık Bakanlığı doğumdan itibaren günde 400 IU (genellikle 3 damla) D vitamini takviyesi önerir. Takviyeyi doktor önerisiyle sürdürün.",
    ),
    Article(
      id: "v2",
      title: "Demir Mineralinin Bebeklerdeki Önemi",
      category: "Besinler",
      readTime: "4 dk",
      summary: "Beyin gelişimi ve kansızlığı önlemek için demirin rolü ve kaynakları.",
      emoji: "🩸",
      content: "Demir, kanın oksijen taşımasını sağlayan hemoglobinin yapı taşıdır ve beyin gelişiminde kritik rol oynar. Bebekler doğumdaki demir deposunu yaklaşık 6 ayda tüketir.\n\n"
          "Bebekler için yararları:\n"
          "- Beyin ve bilişsel gelişimi destekler.\n"
          "- Demir eksikliği anemisini (kansızlık) önler; eksiklikte halsizlik, solgunluk ve iştahsızlık görülür.\n\n"
          "En iyi kaynaklar:\n"
          "Kırmızı et, yumurta sarısı, mercimek, ıspanak. Emilimi artırmak için yanında C vitamini (brokoli, biber, portakal) sunun. Çay demir emilimini azalttığı için öğünle verilmemelidir.",
    ),
    Article(
      id: "v3",
      title: "Kalsiyum: Güçlü Kemik ve Dişler",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Kemik ve diş gelişimi için kalsiyumun yararları ve kaynakları.",
      emoji: "🦴",
      content: "Kalsiyum, kemik ve dişlerin temel yapı taşıdır; ayrıca kas ve sinir fonksiyonları için gereklidir.\n\n"
          "Bebekler için yararları:\n"
          "- Güçlü kemik ve diş gelişimi.\n"
          "- Kalp ritmi ve kas çalışması.\n\n"
          "Kaynaklar:\n"
          "Yoğurt, az tuzlu peynir, süt ürünleri, tahin (susam ezmesi) ve brokoli. D vitamini kalsiyum emilimini artırır. 1 yaşından önce inek sütü ana içecek olarak verilmemelidir.",
    ),
    Article(
      id: "v4",
      title: "Çinko Minerali ve Bağışıklık",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Büyüme ve bağışıklık için çinkonun rolü ve kaynakları.",
      emoji: "🛡️",
      content: "Çinko; bağışıklık sistemi, büyüme ve yara iyileşmesi için gerekli bir mineraldir.\n\n"
          "Bebekler için yararları:\n"
          "- Bağışıklığı güçlendirir, enfeksiyonlara direnci artırır.\n"
          "- Büyüme ve hücre yenilenmesini destekler; eksikliğinde büyüme geriliği ve iştahsızlık olabilir.\n\n"
          "Kaynaklar:\n"
          "Kırmızı et, yumurta, mercimek-nohut gibi baklagiller, yoğurt ve tam tahıllar.",
    ),
    Article(
      id: "v5",
      title: "A Vitamini: Görme ve Bağışıklık",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Göz sağlığı, cilt ve bağışıklık için A vitamininin yararları.",
      emoji: "🥕",
      content: "A vitamini; görme sağlığı, bağışıklık ve cilt/mukoza gelişimi için önemlidir.\n\n"
          "Bebekler için yararları:\n"
          "- Sağlıklı görme ve göz gelişimi.\n"
          "- Bağışıklık ve cilt sağlığı.\n\n"
          "Kaynaklar:\n"
          "Havuç, balkabağı, tatlı patates, ıspanak ve kayısı (beta-karoten) ile yumurta sarısı. Turuncu-sarı sebze ve meyveler zengin kaynaktır.",
    ),
    Article(
      id: "v6",
      title: "C Vitamini ve Demir Emilimi",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Bağışıklığı destekleyen ve demir emilimini artıran C vitamini.",
      emoji: "🍊",
      content: "C vitamini güçlü bir antioksidandır; bağışıklığı destekler ve bitkisel kaynaklı demirin emilimini artırır.\n\n"
          "Bebekler için yararları:\n"
          "- Bağışıklık sistemini güçlendirir.\n"
          "- Demir emilimini artırır, kollajen üretimine yardımcı olur.\n\n"
          "Kaynaklar:\n"
          "Kırmızı/yeşil biber, brokoli, portakal-mandalina, çilek (8+ ay) ve kivi. Isıyla kolay kaybolduğu için sebzeleri fazla pişirmeyin.",
    ),
    Article(
      id: "v7",
      title: "Omega-3 (DHA): Beyin ve Göz Gelişimi",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Beyin ve görme gelişimi için omega-3 yağ asitlerinin önemi.",
      emoji: "🐟",
      content: "Omega-3 yağ asitleri, özellikle DHA, bebeğin beyin ve göz (retina) gelişiminde temel rol oynar.\n\n"
          "Bebekler için yararları:\n"
          "- Beyin ve sinir sistemi gelişimi.\n"
          "- Göz ve görme gelişimi.\n\n"
          "Kaynaklar:\n"
          "Yağlı balıklar (somon, sardalya) 8-9. aydan itibaren kılçıkları temizlenerek; ceviz ezmesi ve keten tohumu. Haftada 1-2 kez balık önerilir.",
    ),
    Article(
      id: "v8",
      title: "B12 Vitamini: Sinir Sistemi ve Kan",
      category: "Besinler",
      readTime: "3 dk",
      summary: "Sinir sistemi ve kan hücreleri için B12'nin önemi ve kaynakları.",
      emoji: "🧠",
      content: "B12 vitamini, sinir sistemi sağlığı ve kırmızı kan hücrelerinin üretimi için gereklidir.\n\n"
          "Bebekler için yararları:\n"
          "- Sinir sistemi gelişimi.\n"
          "- Kansızlığın (anemi) önlenmesi.\n\n"
          "Kaynaklar:\n"
          "Yalnızca hayvansal besinlerde bulunur: kırmızı et, yumurta, süt ürünleri ve balık. Vegan beslenen bebeklerde mutlaka doktor önerisiyle takviye edilmelidir.",
    ),
  ];

  // Built-in articles (fixed + generated). Static so the admin panel can list
  // and edit them too via the top-level getAllArticles().
  static List<Article> _builtInArticles() {
    final List<Article> allArticles = List.from(_articles);
    final List<Map<String, String>> dynamicArticlesData = [
      {"title": "Bebeklerde Gaz Yapan Sebzeler ve Çözümleri", "cat": "Besinler", "time": "3 dk", "emoji": "🥦", "summary": "Brokoli ve karnabahar gibi gaz yapıcı sebzeleri pişirme tüyoları.", "content": "Brokoli, karnabahar, lahana ve kuru baklagiller (mercimek, nohut) lif ve belirli şekerler içerdiği için bağırsakta gaza yol açabilir.\n\nÇözümler:\n- Bu sebzeleri iyice pişirin; buharda yumuşatmak sindirimi kolaylaştırır.\n- Az miktarla başlayın, bebeğin tepkisine göre artırın.\n- Baklagilleri ıslatıp kabuğunu ayıklayarak ve iyi pişirerek verin.\n- Yoğurtla birlikte sunmak bağırsak florasına yardımcı olur.\n\nGaz şiddetliyse o besini bir süre ara verip daha ileride tekrar deneyin."},
      {"title": "Ek Gıdada Kaşık Seçimi Nasıl Olmalıdır?", "cat": "Başlangıç", "time": "3 dk", "emoji": "🥄", "summary": "Bebeğin hassas diş etlerine uygun kaşık seçimi ve besleme teknikleri.", "content": "İlk kaşık, bebeğin hassas diş etlerini incitmeyecek kadar yumuşak olmalıdır.\n\nNelere dikkat edilmeli:\n- Yumuşak silikon uçlu, küçük ve sığ kaşıklar tercih edin.\n- BPA içermeyen, ısıya dayanıklı malzeme olsun.\n- Kaşığı ağzına zorla sokmayın; dudaklarına dokundurup kendisinin almasını bekleyin.\n\nİleride bebeğin kendi tutması için sap kısmı kalın, kavraması kolay kaşıklar idealdir."},
      {"title": "Bebek Köftesi Yaparken Nelere Dikkat Edilmeli?", "cat": "Besinler", "time": "4 dk", "emoji": "🧆", "summary": "Demir deposu, yumuşacık bebek köftelerinin tarif sırları.", "content": "Köfte, kırmızı etin demirini bebeğe sunmanın pratik bir yoludur ve genellikle 8. aydan itibaren önerilir.\n\nİpuçları:\n- Yağsız, çift çekim dana veya kuzu kıyması kullanın.\n- Tuz ve baharat (acı) eklemeyin; rendelenmiş soğan, maydanoz ve biraz haşlanmış patates yumuşaklık katar.\n- Buharda veya fırında pişirin; kızartmayın.\n- Boğulmayı önlemek için küçük, yumuşak ve iki parmak arasında ezilebilecek kıvamda olmalı.\n\nC vitamini içeren bir sebzeyle (brokoli vb.) birlikte sunmak demir emilimini artırır."},
      {"title": "Bebeklerde Gece Beslenmesi Ne Zaman Kesilmeli?", "cat": "Rutinler", "time": "4 dk", "emoji": "🌙", "summary": "Kesintisiz uyku ve ağız sağlığı için gece beslenmesini sonlandırma rehberi.", "content": "6. aydan sonra çoğu bebeğin gece beslenmesine fizyolojik ihtiyacı azalır; gündüz yeterli kalori alıyorsa gece öğünleri kademeli azaltılabilir.\n\nNasıl yapılır:\n- Gündüz öğünlerini ve son öğünü doyurucu tutun.\n- Gece uyanmalarında önce sallama, ninni gibi yöntemlerle yatıştırmayı deneyin.\n- Süreci aniden değil, miktarı/sıklığı azaltarak yapın.\n\nÖnemli: Diş çürüğünü önlemek için diş çıktıktan sonra gece sürekli emzik/biberonla şekerli sıvı verilmemelidir. Her bebeğin temposu farklıdır; zorlamayın."},
      {"title": "Ek Gıdaya Geçişte Blender Kullanımı Doğru mu?", "cat": "Başlangıç", "time": "3 dk", "emoji": "🌪️", "summary": "Pütürlü gıdalara geçişte blender yerine çatal ezmesinin önemi.", "content": "İlk haftalarda pürüzsüz püre için blender kullanmak normaldir. Ancak bebek büyüdükçe sürekli çok pürüzsüz besin vermek çiğneme becerisini geciktirebilir.\n\nÖneri:\n- 6. ay: pürüzsüz püre (blender uygun).\n- 8-9. ay: çatalla ezilmiş, pütürlü kıvama geçin.\n- 10-12. ay: küçük yumuşak parçalar.\n\nKademeli kıvam artışı, bebeğin çiğneme ve dil becerilerini geliştirir."},
      {"title": "Kabak ve Balkabağının Bebeklere Faydaları", "cat": "Besinler", "time": "3 dk", "emoji": "🎃", "summary": "A vitamini ve lif deposu kabakların ek gıdadaki yeri.", "content": "Kabak ve balkabağı, sindirimi en kolay ilk ek gıdalardandır ve 6. aydan itibaren verilebilir.\n\nFaydaları:\n- Balkabağı A vitamini (beta-karoten) açısından zengindir; göz ve bağışıklık sağlığını destekler.\n- Lif içeriği kabızlığı önlemeye yardımcı olur.\n- Tatlımsı tadıyla bebekler tarafından kolay kabul edilir.\n\nBuharda pişirilip püre yapılır; istenirse anne sütü veya zeytinyağı ile zenginleştirilir."},
      {"title": "Bebeklere Balık Ne Zaman ve Nasıl Verilmeli?", "cat": "Besinler", "time": "4 dk", "emoji": "🐟", "summary": "Somon ve levrek gibi omega-3 zengini balıkların tanıtım ayı ve kılçık temizleme rehberi.", "content": "Balık, beyin gelişimi için omega-3 (DHA) açısından çok değerlidir ve genellikle 8-9. aydan itibaren tanıtılır.\n\nNasıl verilmeli:\n- Somon, levrek, sardalya gibi cıva düzeyi düşük balıkları tercih edin.\n- Kılçıkları tek tek ve dikkatle ayıklayın; bu en kritik adımdır.\n- İyice pişirin (çiğ/az pişmiş vermeyin) ve püre/ufalanmış olarak sunun.\n- Yüksek alerjen olduğu için 3 gün kuralıyla, sabah saatlerinde başlayın.\n\nHaftada 1-2 kez balık önerilir."},
      {"title": "Ek Gıda Alışveriş Listesi Hazırlama Rehberi", "cat": "Başlangıç", "time": "3 dk", "emoji": "🛒", "summary": "Organik, katkısız ve mevsiminde ek gıda alışveriş tüyoları.", "content": "Bebek için alışverişte tazelik, mevsim ve güvenilirlik önceliklidir.\n\nİpuçları:\n- Mevsiminde sebze-meyve alın; hem daha besleyici hem daha ekonomiktir.\n- Mümkünse güvenilir/organik üretici tercih edin, etiketleri okuyun.\n- Tuz, şeker, katkı maddesi içeren paketli ürünlerden kaçının.\n- Eti taze ve yağsız, balığı kılçık temizliği yapılabilir bütünlükte seçin.\n\nEvde iyice yıkayıp gerekirse kabuğunu soyarak tarım ilacı kalıntısını azaltın."},
      {"title": "Bebeklerde İştahsızlık ve Çözüm Yolları", "cat": "Rutinler", "time": "4 dk", "emoji": "🥺", "summary": "Diş çıkarma dönemi ve geçici iştahsızlıklarda anne babaların yapması gerekenler.", "content": "Bebeklerde geçici iştahsızlık sık görülür; diş çıkarma, hastalık veya hızlı büyüme dönemleri arası yavaşlama buna yol açabilir.\n\nNe yapmalı:\n- Zorla yedirmeyin; baskı iştahsızlığı artırır.\n- Öğünleri küçük porsiyonlar ve renkli sunumlarla cazip hale getirin.\n- Öğün arası atıştırma ve şekerli içeceklerden kaçının.\n- Aile sofrasına dahil edin; taklitle iştah artar.\n\nKilo kaybı, sürekli ret veya halsizlik varsa doktora başvurun."},
      {"title": "BLW Yönteminde Boğulma Korkusu Nasıl Aşılır?", "cat": "BLW Yöntemi", "time": "4 dk", "emoji": "⚠️", "summary": "Öğürme refleksi ile boğulma arasındaki farklar ve güvenli yatış pozisyonları.", "content": "BLW'de en büyük endişe boğulmadır; ancak öğürme (gag) refleksi ile boğulma farklıdır.\n\nFarkı bilin:\n- Öğürme; sesli, yüzü kızarır ve koruyucu bir reflekstir, normaldir.\n- Boğulma; sessizdir, nefes alamaz, morarır — acil müdahale gerektirir.\n\nGüvenlik kuralları:\n- Bebek her zaman dik oturmalı ve asla yalnız bırakılmamalı.\n- Besinler iki parmak arasında ezilebilecek yumuşaklıkta olmalı.\n- Üzüm, fındık gibi yuvarlak/sert gıdalar bütün verilmemeli.\n\nEbeveynlerin bebek ilk yardımı (Heimlich) öğrenmesi önerilir."},
      {"title": "Kemik Suyu Bebeklere Nasıl ve Ne Zaman Verilir?", "cat": "Besinler", "time": "4 dk", "emoji": "🍲", "summary": "İlikli kemik suyu hazırlama ve bebek çorbalarına lezzet katma yolları.", "content": "Kemik suyu, çorbalara doğal lezzet ve mineral katmak için kullanılır; genellikle 7-8. aydan itibaren çorbalarda tercih edilir.\n\nHazırlık:\n- Güvenilir kaynaktan ilikli/etli kemik kullanın.\n- Tuz ve baharat eklemeden, kısık ateşte uzun süre kaynatın.\n- Soğuyunca üstte donan yağ tabakasını alın.\n\nKemik suyunu tek başına ana öğün gibi görmeyin; çorba, püre ve yemeklerin tabanı olarak kullanın. Ana protein ve demir için ete/sebzelere ihtiyaç vardır."},
      {"title": "Ek Gıdada Baharat ve Otların Kullanımı", "cat": "Rutinler", "time": "3 dk", "emoji": "🌿", "summary": "Nane, dereotu ve kimyon gibi baharatların ek gıdaya giriş zamanları.", "content": "Bebek yemekleri tatsız olmak zorunda değil; tuz ve şeker olmadan da otlarla lezzet katılabilir.\n\nKullanım:\n- 6. aydan itibaren az miktarda maydanoz, dereotu, nane eklenebilir.\n- Kimyon, tarçın gibi hafif baharatlar küçük miktarlarda denenebilir.\n- Tuz, şeker ve acı (pul biber vb.) 1 yaşına kadar eklenmez.\n- Her yeni baharatı/otu da 3 gün kuralıyla tanıtın.\n\nFarklı tatlar, ileride daha az seçici bir damak gelişimine yardımcı olur."},
      {"title": "Yulafın Bebek Beslenmesindeki Etkisi", "cat": "Besinler", "time": "3 dk", "emoji": "🌾", "summary": "Beta-glukan lifi zengini yulaf lapasının bebek gelişimine katkısı.", "content": "Yulaf, ek gıdada sık tercih edilen besleyici bir tahıldır ve 6. aydan itibaren verilebilir.\n\nFaydaları:\n- Beta-glukan lifi tok tutar ve bağırsakları düzenler.\n- Demir, çinko ve B vitaminleri içerir.\n- Glüten oranı buğdaya göre düşüktür (saf yulaf).\n\nİnce yulaf ezmesiyle anne sütü/su veya meyve püresi katarak lapa yapılır. Tok tuttuğu için özellikle gece öğünlerinde idealdir."},
      {"title": "Bebeklerde Alerji Belirtileri Nelerdir?", "cat": "Alerji", "time": "3 dk", "emoji": "🔬", "summary": "Kurdeşen, egzama, hırıltı ve sindirim sistemi reaksiyonlarını tanımak.", "content": "Besin alerjisi belirtileri genellikle besinden dakikalar-saatler sonra ortaya çıkar.\n\nSık görülen belirtiler:\n- Ciltte kızarıklık, kurdeşen, kaşıntı, egzama alevlenmesi.\n- Ağız çevresinde şişlik.\n- Kusma, ishal, karın ağrısı.\n- Burun akıntısı, hapşırma.\n\nACİL durum (anafilaksi): Nefes almakta güçlük, hırıltı, dilde/dudakta şişme, ciltte yaygın morarma → derhal 112'yi arayın. Hafif belirtilerde gıdayı kesip doktora danışın."},
      {"title": "Mevsiminde Beslenmenin Önemi", "cat": "Rutinler", "time": "3 dk", "emoji": "☀️", "summary": "Hangi ayda hangi sebze meyve taze verilmeli?", "content": "Mevsiminde tüketilen sebze ve meyveler hem daha besleyici hem de kalıntı açısından daha güvenlidir.\n\nNeden önemli:\n- Mevsiminde olan ürün vitamin-mineral açısından daha zengindir.\n- Sera/erken ürünlere göre daha az tarım ilacı içerebilir.\n- Daha taze, lezzetli ve ekonomiktir.\n\nUygulamadaki 'Mevsiminde Beslenme' bölümünden hangi besinin hangi mevsim ve kaç aydan itibaren uygun olduğunu görebilirsiniz."},
      {"title": "Bebek Peyniri (Lor) Evde Nasıl Yapılır?", "cat": "Besinler", "time": "4 dk", "emoji": "🧀", "summary": "Sadece süt ve limon suyu ile tuzsuz lor peyniri yapımı.", "content": "Tuzsuz ev lor peyniri, kalsiyum ve protein kaynağı olarak 8-9. aydan itibaren verilebilir.\n\nYapılışı:\n1. Güvenilir taze sütü kaynatın.\n2. Hafif ılıdıktan sonra azar azar limon suyu ekleyip karıştırın; süt kesilip taneler oluşur.\n3. Tülbentten süzün, soğuk su ile durulayın (limon tadını alır).\n\nElde edilen lor tuzsuzdur; pürelere veya tek başına kıvamı yumuşatılarak sunulabilir. Hazır tuzlu peynirler 1 yaşına kadar uygun değildir."},
      {"title": "Ek Gıda Döneminde Dışkı Değişiklikleri", "cat": "Rutinler", "time": "3 dk", "emoji": "💩", "summary": "Katı gıdaya geçince bebeğin dışkısının renk ve kıvam değiştirmesi normal mi?", "content": "Ek gıdaya başlayınca dışkının renk, koku ve kıvamının değişmesi normaldir.\n\nNormal değişiklikler:\n- Daha koyu, daha kokulu ve kıvamlı dışkı.\n- Pancar (kırmızı), ıspanak (yeşil), havuç (turuncu) gibi besinler dışkıyı renklendirebilir.\n- Sindirilmemiş küçük gıda parçaları görülebilir (çiğneme/sindirim henüz gelişiyor).\n\nDikkat: Sulu-fışkırır ishal, kanlı/mukuslu dışkı, çok sert ve ağrılı kabızlık varsa doktora başvurun."},
      {"title": "Bebeklerde İrmikli Muhallebi", "cat": "Besinler", "time": "3 dk", "emoji": "🥣", "summary": "Tok tutan, kilo alımına yardımcı irmikli gece muhallebileri.", "content": "İrmikli muhallebi, tok tutan ve kilo alımını destekleyen bir gece öğünüdür (genellikle 8+ ay).\n\nHazırlık:\n- Süt/anne sütü içinde az miktar irmiği kısık ateşte pişirin.\n- Şeker eklemeyin; tatlandırmak için piştikten sonra meyve püresi veya (8+ ay) az pekmez katın.\n- Pekmezi kaynatmayın; ocaktan aldıktan sonra ekleyin (demir için).\n\nKıvamı yaşa göre ayarlayın; çok yoğun değil, kaşıkla kolay yutulur olmalı."},
      {"title": "Avokado Püresi ve Kombinasyonları", "cat": "Besinler", "time": "3 dk", "emoji": "🥑", "summary": "Muzlu, labneli ve anne sütlü avokado ezmesi alternatifleri.", "content": "Avokado, sağlıklı yağlar ve beyin gelişimi için ideal bir ilk besindir; pişirmeden, çiğ olarak ezilir (6+ ay).\n\nKombinasyonlar:\n- Avokado + anne sütü/formül mama: en yumuşak ilk püre.\n- Avokado + muz: tatlı ve enerji verici.\n- Avokado + labne (8+ ay): kremamsı, kalsiyum katkılı.\n\nKararması hızlı olduğundan hazırladıktan hemen sonra sunun; üzerine birkaç damla limon kararmayı geciktirir."},
      {"title": "Diş Çıkarma Döneminde Beslenme", "cat": "Rutinler", "time": "4 dk", "emoji": "🦷", "summary": "Hassas diş etlerini rahatlatacak soğuk meyve fileleri ve yumuşak gıdalar.", "content": "Diş çıkarma döneminde diş etleri ağrıyabilir ve bebek geçici iştahsızlık yaşayabilir.\n\nRahatlatıcı öneriler:\n- Soğuk (buzlu değil) yoğurt, püre rahatlatır.\n- Meyve fileli diş kaşıyıcıya konmuş soğutulmuş muz/elma diş etini rahatlatır.\n- Temiz, soğutulmuş diş kaşıyıcı halkalar kullanılabilir.\n\nZorla yedirmeyin; bu dönem geçicidir. Aşırı huzursuzluk, yüksek ateş veya ishal başka bir nedeni işaret edebilir, doktora danışın."},
      {"title": "Anne Sütü ile Ek Gıda Dengesi", "cat": "Başlangıç", "time": "4 dk", "emoji": "🤱", "summary": "Ana öğün anne sütü, ara öğün tadım şeklinde giden 6-9 ay dengesi.", "content": "Ek gıda anne sütünün yerine geçmez; onu tamamlar. İlk dönem 'tatma ve tanışma' dönemidir.\n\nDenge:\n- 6-8 ay: ana besin hâlâ anne sütü/mamadır; ek gıdalar küçük tadımlarla artar.\n- 9-12 ay: ek gıda öğünleri belirginleşir, ara öğünler eklenir.\n- Emzirme talep oldukça sürdürülür.\n\nKural: Önce emzirip sonra ek gıda yerine, zamanla ek gıdayı bağımsız öğün hâline getirin. Dünya Sağlık Örgütü 2 yaşına kadar emzirmeyi önerir."},
      {"title": "Bebeklerde Glüten Tanıtımı Ne Zaman Olmalı?", "cat": "Alerji", "time": "4 dk", "emoji": "🌾", "summary": "Çölyak hastalığı riski ve glüten içeren tahılların ek gıdaya kademeli girişi.", "content": "Glüten; buğday, arpa ve çavdarda bulunan bir proteindir. Güncel öneri, glütenin çok geç değil, ek gıdayla birlikte (yaklaşık 6. ay) küçük miktarlarda tanıtılmasıdır.\n\nNasıl:\n- İrmik, bebek bisküvisi gibi küçük miktarla başlayın.\n- 3 gün kuralı ile diğer yeni besinlerden ayrı tanıtın.\n- Çölyak veya glüten hassasiyeti aile öyküsü varsa doktorunuza danışın.\n\nÇölyak belirtileri (sürekli ishal, şişkinlik, kilo alamama) varsa hekime başvurun."},
      {"title": "Meyve Suyu Yerine Meyve Püresi", "cat": "Besinler", "time": "3 dk", "emoji": "🍎", "summary": "Lif kaybını önlemek ve obeziteden kaçınmak için püre tercih etmenin önemi.", "content": "Bebeklere meyve suyu yerine bütün meyve püresi önerilir.\n\nNeden:\n- Meyve suyu sıkılırken lif kaybolur; geriye yoğun şeker kalır.\n- Sıvı şeker diş çürüğü ve aşırı kalori (obezite) riskini artırır.\n- Püre, lif sayesinde tok tutar ve bağırsakları düzenler.\n\nÖneri: 1 yaşından önce meyve suyu verilmemesi; meyveleri ezerek/püre yaparak sunulması en sağlıklısıdır."},
      {"title": "Seyahatlerde Ek Gıda Hazırlığı", "cat": "Rutinler", "time": "3 dk", "emoji": "✈️", "summary": "Termoslar, taşınabilir mama kapları ve pratik kavanoz maması tarifleri.", "content": "Seyahatte hijyen ve soğuk zincir önemlidir.\n\nİpuçları:\n- Yemekleri ısı koruyan termos/mama kabında taşıyın.\n- Çabuk bozulmayan seçenekler tercih edin: muz, avokado, yulaf, bebek bisküvisi.\n- Kısa seyahatler için evde hazırlanıp soğutulmuş porsiyonları buz aküsüyle taşıyın.\n- Temiz kaşık, mama önlüğü ve ıslak mendil bulundurun.\n\nUzun süre dışarıda kalacak taze yemekleri (et, balık, süt ürünü) soğutmadan tüketmeyin."},
      {"title": "Bebeklerde Ceviz ve Badem Tüketimi", "cat": "Besinler", "time": "4 dk", "emoji": "🥜", "summary": "Kuruyemiş alerjisi ve beyin gelişimi için ceviz/badem ezmesi sunumu.", "content": "Ceviz ve badem omega-3 ve sağlıklı yağ açısından zengindir; beyin gelişimini destekler.\n\nGüvenli sunum:\n- ASLA bütün/parça halinde vermeyin — boğulma riski yüksektir.\n- İnce çekilmiş toz veya pürüzsüz ezme olarak püre/yoğurda karıştırın.\n- Yüksek alerjen oldukları için 3 gün kuralıyla, sabah saatlerinde başlayın.\n- Ailede kuruyemiş alerjisi varsa önce doktora danışın.\n\nGüncel görüş, alerjenleri çok geciktirmeden (yaklaşık 6 aydan itibaren uygun formda) tanıtmanın alerji riskini azaltabileceği yönündedir."},
      {"title": "Ek Gıda Kapları Seçerken Nelere Bakılmalı?", "cat": "Başlangıç", "time": "3 dk", "emoji": "🍱", "summary": "BPA içermeyen cam ve silikon saklama kaplarının önemi.", "content": "Bebek mamasını saklama ve ısıtmada kap güvenliği önemlidir.\n\nÖneriler:\n- BPA içermeyen, gıdaya uygun cam veya silikon kaplar tercih edin.\n- Porsiyonluk bölmeli kaplar dondurarak saklamayı kolaylaştırır.\n- Plastiği mikrodalgada ısıtmaktan kaçının; cam tercih edin.\n- Kapları her kullanımdan sonra iyice yıkayın.\n\nDondurulan mamayı buzdolabında çözün, bir kez ısıtın ve tekrar dondurmayın."},
      {"title": "Bebeklerin Kendi Kendine Kaşık Tutması", "cat": "BLW Yöntemi", "time": "4 dk", "emoji": "🥄", "summary": "9-12 aylık bebeklerin kaşık tutma hevesini desteklemek.", "content": "Bebekler genellikle 9-12 ay arasında kaşığa ilgi duyar ve kendi yemeye çalışır.\n\nDesteklemek için:\n- Bebeğe kendi kaşığını verin, siz de ayrı bir kaşıkla yardımcı olun.\n- Kalın saplı, kavraması kolay kaşıklar seçin.\n- Yoğurt, püre gibi kaşıkta kalan kıvamlı yiyeceklerle başlatın.\n- Dökülmeyi ve dağınıklığı doğal karşılayın; bu öğrenmenin parçasıdır.\n\nMama önlüğü ve altına serilen örtü işinizi kolaylaştırır. Sabırlı olun, motor beceriler zamanla gelişir."},
      {"title": "Dana Kıyması Çorbalara Ne Zaman Eklenmeli?", "cat": "Besinler", "time": "3 dk", "emoji": "🥩", "summary": "Yağsız kıymanın 7-8. ayda çorbalara katılması ve demir.", "content": "Kırmızı et, ek gıdanın en değerli demir kaynaklarındandır ve genellikle 7-8. aydan itibaren çorbalara eklenir.\n\nNasıl:\n- Yağsız, çift çekim dana veya kuzu kıyması kullanın.\n- Sebze çorbasının içinde iyice pişirin; ardından blenderdan geçirip pürüzsüz yapın.\n- Tuz eklemeyin.\n- Yanında C vitamini içeren sebze (brokoli, biber) demir emilimini artırır.\n\nKademeli olarak kıvamı pütürlüye doğru çıkarabilirsiniz."},
      {"title": "Gazı ve Şişkinliği Önleyen Bebek Masajı", "cat": "Rutinler", "time": "3 dk", "emoji": "💆", "summary": "Beslenme sonrası gaz sancılarını gideren karın masajı hareketleri.", "content": "Karın masajı, gaz sancısı çeken bebeği rahatlatabilir.\n\nNasıl yapılır:\n- Bebeği sırt üstü yatırın, ellerinizi ısıtın.\n- Karnına göbek çevresinde saat yönünde yumuşak dairesel hareketler yapın.\n- 'Bisiklet hareketi': bacaklarını sırayla karnına doğru çekip uzatın.\n- Beslenme sonrası gazını çıkarmak için dik tutup sırtını sıvazlayın.\n\nMasajı aç ya da çok tok karnına değil, beslenmeden bir süre sonra yapın. Sürekli şiddetli ağlama/şişlik varsa doktora danışın."},
      {"title": "Ek Gıdada Gıda Güvenliği ve Temizlik", "cat": "Başlangıç", "time": "3 dk", "emoji": "🌱", "summary": "Tarım ilacı kalıntısını azaltma ve hijyen yöntemleri.", "content": "Bebeğin bağışıklığı gelişmekte olduğundan gıda hijyeni kritiktir.\n\nUygulamalar:\n- Sebze-meyveleri bol suda iyice yıkayın; gerekirse kabuğunu soyun.\n- Karbonat/sirkeli suda kısa bekletmek kalıntıyı azaltabilir.\n- Et, balık ve yumurtayı iyice pişirin.\n- Mama hazırlarken elleri ve mutfak yüzeylerini temiz tutun, ayrı doğrama tahtası kullanın.\n\nHazırlanan mamayı oda sıcaklığında uzun süre bekletmeyin; buzdolabında saklayın."},
      {"title": "Yumurta Akı Neden 1 Yaş Sonrasında Önerilir?", "cat": "Alerji", "time": "3 dk", "emoji": "🥚", "summary": "Yumurta akındaki ovalbumin proteini ve alerjen seviyesi.", "content": "Yumurtanın sarısı ile akı farklı alerji profillerine sahiptir.\n\nNeden ak daha geç:\n- Yumurta akındaki başlıca protein (ovalbumin) güçlü bir alerjendir.\n- Sarısı daha düşük alerjen olduğu için genellikle 8. aydan itibaren önce o verilir.\n- Ak, geleneksel öneride 1 yaşından sonra denenir.\n\nNot: Güncel bazı kılavuzlar tüm yumurtanın daha erken tanıtılabileceğini söyler; ailede yumurta alerjisi öyküsü varsa mutlaka doktorunuza danışın ve 3 gün kuralı uygulayın."},
      {"title": "Pirinç Ununun Yeri ve Alternatifleri", "cat": "Besinler", "time": "3 dk", "emoji": "🍚", "summary": "Boş kalori yerine yulaf ve tam tahıl unu kullanımı.", "content": "Pirinç unu kıvam vermek için kullanılır; ancak besin değeri düşük olduğu için tek başına ağırlık verilmemelidir.\n\nAlternatifler:\n- Yulaf ezmesi: lif, demir ve çinko açısından zengindir.\n- Tam buğday/tam tahıl unları daha besleyicidir.\n- Çeşitlilik: sadece pirince bağlı kalmayın.\n\nNot: Pirincin doğal arsenik içeriği nedeniyle de tek tip tüketim yerine tahılları çeşitlendirmek önerilir."},
      {"title": "Bebeklerin Yemek Seçmesiyle Baş Etme", "cat": "Rutinler", "time": "4 dk", "emoji": "🥦", "summary": "Bir gıdayı tekrar tekrar sunmanın ve baskı yapmamanın önemi.", "content": "Bebeklerin yeni besinleri reddetmesi normaldir; tat alımı tekrarla gelişir.\n\nStratejiler:\n- Reddedilen bir besini bırakmayın; farklı şekillerde (püre, parça, başka besinle) 10-15 kez sunun.\n- Baskı, ödül-ceza ve zorlama yapmayın; bu seçiciliği artırır.\n- Aile sofrasında aynı yemeği yiyin; taklit güçlü bir öğretmendir.\n- Açken yeni besini sunun.\n\nSabır anahtardır; süreç haftalar alabilir."},
      {"title": "Bebeklerde Susuzluk (Dehidrasyon) Belirtileri", "cat": "Rutinler", "time": "3 dk", "emoji": "💧", "summary": "Yetersiz su alımında bez ıslaklığı ve cilt kuruluğu takibi.", "content": "Özellikle sıcak havalarda ve hastalıkta (ishal/kusma) dehidrasyona dikkat edilmelidir.\n\nBelirtiler:\n- Islak bez sayısında azalma (günde 6'dan az), koyu idrar.\n- Ağız-dudak kuruluğu, ağlarken gözyaşının azalması.\n- Halsizlik, çökük bıngıldak (fontanel).\n\nÖneri: 6 aydan sonra öğünlerle birlikte küçük yudumlarla su sunun. Belirti varsa ve ishal/kusma sürüyorsa vakit kaybetmeden doktora başvurun."},
      {"title": "Muz Kabız Yapar mı? Doğru Muz Tüketimi", "cat": "Besinler", "time": "3 dk", "emoji": "🍌", "summary": "Yeşil muzun kabız, olgun muzun sindirimi kolaylaştırması.", "content": "Muzun etkisi olgunluğuna göre değişir.\n\nBilmeniz gerekenler:\n- Ham/yeşilimsi muz dirençli nişasta açısından zengindir ve kabız yapabilir.\n- İyice olgun, kabuğu benekli muz daha kolay sindirilir ve kabızlık yapma olasılığı düşüktür.\n- Aşırı miktarda muz, kabızlık eğilimi olan bebeklerde dengelenmelidir.\n\nKabızlık varsa muzu armut, kayısı gibi lifli meyvelerle dengeleyin ve su tüketimini ihmal etmeyin."},
      {"title": "Muhallebide Pekmez Ne Zaman Eklenmeli?", "cat": "Rutinler", "time": "3 dk", "emoji": "🍯", "summary": "Pekmezin ısıtılmaması ve piştikten sonra eklenmesi kuralı.", "content": "Pekmez (özellikle üzüm/dut pekmezi) demir ve mineral kaynağıdır; genellikle 8+ ayda az miktarda kullanılır.\n\nKural:\n- Pekmezi pişirme sırasında KAYNATMAYIN; ısı, içindeki bazı değerleri azaltır.\n- Muhallebi/lapayı ocaktan aldıktan ve biraz soğuttuktan sonra az miktar ekleyin.\n- Şeker yerine doğal tatlandırıcı olarak çok az kullanın; aşırıya kaçmayın.\n\nNot: Bal değildir — bal 1 yaşına kadar yasaktır; pekmezle karıştırmayın."},
      {"title": "BLW İçin En Uygun İlk Sebzeler", "cat": "BLW Yöntemi", "time": "3 dk", "emoji": "🥕", "summary": "Buharda haşlanmış parmak havuç ve kabakların BLW hazırlığı.", "content": "BLW'de ilk sebzeler bebeğin kavrayıp ezebileceği güvenlikte olmalıdır.\n\nİdeal ilk sebzeler:\n- Buharda yumuşatılmış parmak havuç, kabak, tatlı patates, brokoli sapı.\n- İki parmak arasında ezilebilecek yumuşaklıkta ama dağılmayacak dirilikte pişirin.\n- Avucundan taşacak şekilde uzun (parmak boyu) kesin ki kavrayabilsin.\n\nBebek mutlaka dik otururken ve gözetim altında yemeli; yuvarlak/sert çiğ sebzeler verilmemelidir."},
      {"title": "Bebeklerin Çiğneme Refleksi Nasıl Gelişir?", "cat": "BLW Yöntemi", "time": "4 dk", "emoji": "👅", "summary": "Dişsiz bebeklerin damaklarıyla yiyecekleri ezme becerisi.", "content": "Bebekler dişleri çıkmadan da çiğneyebilir; bunu güçlü diş etleri ve damaklarıyla yaparlar.\n\nNasıl gelişir:\n- Önce dil ile öne-arkaya itme (emme) hâkimdir.\n- Pütürlü ve yumuşak parça gıdalarla çiğneme/yutma koordinasyonu gelişir.\n- Hep pürüzsüz püre vermek bu beceriyi geciktirebilir.\n\nÖneri: 8-9. aydan itibaren kademeli olarak pütürlü ve yumuşak parçalı besinlere geçin. Öğürme refleksi bu süreçte normaldir ve koruyucudur."},
      {"title": "Ek Gıda Döneminde Günlük Örnek Menü", "cat": "Rutinler", "time": "4 dk", "emoji": "📅", "summary": "Yaklaşık 8 aylık bir bebek için örnek beslenme akışı.", "content": "Aşağıdaki akış örnektir; her bebeğin ihtiyacı farklıdır. Anne sütü/mama talep oldukça sürdürülür.\n\nÖrnek gün (~8 ay):\n- Sabah: Anne sütü/mama + yulaf lapası veya yumurta sarısı.\n- Ara öğün: Meyve püresi (elma, armut) veya yoğurt.\n- Öğle: Etli/mercimekli sebze çorbası + zeytinyağı.\n- İkindi: Avokado/muz ezmesi.\n- Akşam: Sebze püresi (kabak, havuç) + tavuk/kıyma.\n- Gece: Anne sütü/mama.\n\nÖğünler arası su sunun; tuz-şeker eklemeyin. Yeni besinleri 3 gün kuralıyla tanıtın."}
    ];

    int counter = 12;
    for (var d in dynamicArticlesData) {
      allArticles.add(
        Article(
          id: "a${counter++}",
          title: d["title"]!,
          category: d["cat"]!,
          readTime: d["time"]!,
          summary: d["summary"]!,
          emoji: d["emoji"]!,
          content: d["content"]!,
        ),
      );
    }
    return allArticles;
  }

  @override
  Widget build(BuildContext context) {
    return webPageShell(context, maxWidth: 1000, child: _shelled(context));
  }

  Widget _shelled(BuildContext context) {
    const primaryColor = Color(0xFFFF7A45); // Vibrant Apricot/Coral
    const textColor = Color(0xFF2D2D3A); // Darker grey
    const lightTextColor = Color(0xFFA8A8B3);
    const borderGreyColor = Color(0xFFE2E2E6);

    final fullArticles = getAllArticles();

    // Filter articles based on search and category
    final filteredArticles = fullArticles.where((art) {
      final matchesCategory = _selectedCategory == "Tümü" || art.category == _selectedCategory;
      final matchesSearch = art.title.toLowerCase().contains(_searchQuery) ||
          art.summary.toLowerCase().contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Ek Gıda Rehberi 📝",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: borderGreyColor.withOpacity(0.8)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Makale veya başlık ara...",
                  hintStyle: const TextStyle(color: Color(0xFFA8A8B3), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFA8A8B3)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFFA8A8B3), size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = "";
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Categories horizontal scrolling chips
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : borderGreyColor.withOpacity(0.8),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Articles count badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
            child: Row(
              children: [
                Text(
                  "Toplam ${filteredArticles.length} makale listeleniyor",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: lightTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: MedicalDisclaimer(),
          ),

          // Articles List View
          Expanded(
            child: filteredArticles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          "Aradığınız kriterlere uygun makale bulunamadı.",
                          style: TextStyle(color: lightTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 520, mainAxisExtent: 180, crossAxisSpacing: 16),
                    itemCount: filteredArticles.length + (filteredArticles.length ~/ 3),
                    itemBuilder: (context, index) {
                      // One ad banner after every 3 article cards (repeating).
                      final full = filteredArticles.length ~/ 3;
                      int artIdx;
                      if (index < full * 4) {
                        final within = index % 4;
                        if (within == 3) {
                          return AdBanner(
                            onUpgrade: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PremiumScreen(onChanged: () {})),
                            ),
                          );
                        }
                        artIdx = (index ~/ 4) * 3 + within;
                      } else {
                        artIdx = full * 3 + (index - full * 4);
                      }
                      final article = filteredArticles[artIdx];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showArticleDetails(article),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderGreyColor.withOpacity(0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cover photo or category emoji badge
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: isPhotoUrl(article.imageUrl)
                                      ? photoOrFallback(article.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover)
                                      : Center(
                                          child: Text(
                                            article.emoji,
                                            style: const TextStyle(fontSize: 24),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                // Text details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              article.category,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            article.readTime,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: lightTextColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (article.sponsored) ...[
                                        const SizedBox(height: 6),
                                        SponsoredBadge(label: article.sponsorLabel),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        article.title,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        article.summary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: textColor.withOpacity(0.7),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) => Navigator.of(context).pop(i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextColor,
        selectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), activeIcon: Icon(Icons.restaurant), label: "Gıdalar"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: "Takvim"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: "Sepet"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }

  void _showArticleDetails(Article article) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${article.emoji} ", style: const TextStyle(fontSize: 24)),
              Expanded(
                child: Text(
                  article.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2D2D3A),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.sponsored) ...[
                  SponsoredBadge(label: article.sponsorLabel),
                  const SizedBox(height: 12),
                ],
                // Cover photo (if provided)
                if (isPhotoUrl(article.imageUrl)) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: photoOrFallback(article.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Info chips row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A45).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7A45),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${article.readTime} okuma süresi",
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFFA8A8B3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (article.author.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("Hazırlayan: ${article.author}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA8A8B3))),
                ],
                const SizedBox(height: 16),
                ...renderArticleBlocks(article),
                const SizedBox(height: 4),
                const MedicalDisclaimer(),
              ],
            ),
          ),
          actions: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Kapat",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A45),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
