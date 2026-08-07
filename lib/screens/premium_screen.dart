import 'package:flutter/material.dart';
import '../config/premium_config.dart';
import '../data/admin_store.dart';
import '../data/extras_store.dart';
import '../services/storage_service.dart';
import '../widgets/web_shell.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);

class PremiumScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const PremiumScreen({super.key, this.onChanged});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _features = [
    ["📈", "Büyüme grafiği & WHO persentil", "Boy/kilo gelişimini referans bantlarıyla izle."],
    ["📄", "Doktora özel gelişim raporu", "Denenen gıdalar, reaksiyonlar ve gelişim özetini paylaş."],
    ["🗓️", "Otomatik haftalık menü", "Yaşa ve denenenlere göre tek dokunuşla menü."],
    ["☁️", "Sınırsız yedek & geçmiş", "Tüm geçmişin bulutta. Ücretsizde son 2 ay görünür, premium'da sınırsız."],
    ["📈", "Büyüme grafiği & WHO persentil", "Boy/kilo eğrisi ve persentil takibi."],
    ["👶", "Sınırsız bebek profili", "Tüm çocuklarını tek hesapta yönet."],
  ];

  final _promoCtrl = TextEditingController();

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  void _redeemPromo() {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    final days = promoCodeDays(code);
    if (days == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kod geçersiz.")));
      return;
    }
    setState(() {
      if (days < 0) {
        // Sınırsız: süre sınırı olmadan kalıcı premium.
        globalIsPremium = true;
        globalPremiumUntil = null;
      } else {
        applyPremiumForDays(days);
      }
    });
    StorageService.instance.saveExtras();
    widget.onChanged?.call();
    _promoCtrl.clear();
    final msg = days < 0 ? "Sınırsız premium etkinleştirildi! 🎉" : "$days günlük premium etkinleştirildi! 🎉";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return webPageShell(context, child: _shelled(context));
  }

  Widget _shelled(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 28 + MediaQuery.of(context).padding.bottom),
        children: [
          // Abonelik satışı kapalıyken (kPremiumEnabled == false) yalnızca
          // bilgilendirme gösterilir; fiyat, deneme ve promosyon kodu yok
          // (App Store 3.1.1).
          if (!kPremiumEnabled) ..._infoOnlyBody(),
          if (kPremiumEnabled) ...[
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_primary, Color(0xFFFFB199)]), borderRadius: BorderRadius.circular(20)),
                  child: const Text("BabyBites+", style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                const Text("Bebeğinin gelişimini bir üst seviyeye taşı", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                const SizedBox(height: 4),
                const Text("İlk 7 gün ücretsiz, sonra ayda 199 TL. İstediğin zaman iptal et.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._features.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
                child: Row(children: [
                  Text(f[0], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f[1], style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                      const SizedBox(height: 2),
                      Text(f[2], style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                    ]),
                  ),
                  Icon(Icons.check_circle, color: _primary.withOpacity(globalIsPremium ? 1 : 0.3), size: 20),
                ]),
              )),
          const SizedBox(height: 16),
          if (globalIsPremium)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.verified, color: Color(0xFF10B981)),
                SizedBox(width: 10),
                Expanded(child: Text("BabyBites+ aktif. Tüm premium özellikler açık.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0E9F6E)))),
              ]),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final now = DateTime.now();
                  setState(() {
                    globalTrialStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                    applyPremiumForDays(7);
                  });
                  StorageService.instance.saveExtras();
                  widget.onChanged?.call();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("7 günlük ücretsiz deneme başladı! 🎉")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text("7 Gün Ücretsiz Dene", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          if (globalIsPremium) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () { setState(() { globalIsPremium = false; globalTrialStart = null; globalPremiumUntil = null; }); StorageService.instance.saveExtras(); widget.onChanged?.call(); },
                child: const Text("Aboneliği iptal et (demo)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              ),
            ),
          ],
          // Promosyon kodu — yalnızca premium olmayanlara.
          if (!globalIsPremium) ...[
            const SizedBox(height: 16),
            // Promosyon kodu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _primary.withOpacity(0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.confirmation_number_outlined, color: _primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text("Promosyon Kodu", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
                  ]),
                  const SizedBox(height: 4),
                  const Text("Elindeki kodu gir, premium otomatik açılsın.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _promoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                        onSubmitted: (_) => _redeemPromo(),
                        decoration: InputDecoration(
                          hintText: "KOD",
                          hintStyle: const TextStyle(color: _light, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFF3F3F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _redeemPromo,
                      style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Uygula", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text("Not: Ödeme, uygulama mağazası (App Store / Google Play) üzerinden gerçekleşir. Bu sürüm tanıtım amaçlıdır.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _light)),
          ],
        ],
      ),
    );
  }

  /// Abonelik kapalıyken gösterilen sade gövde.
  ///
  /// Burada eskiden "reklam izle, 1 gün reklamsız kullan" ödülü vardı; o
  /// tamamen kaldırıldı — reklamsız dönem artık hiçbir kullanıcıda yok.
  /// Satın alma / fiyat / kod da yok (App Store 3.1.1), bu yüzden ekran
  /// yalnızca bilgilendirme yapıyor.
  List<Widget> _infoOnlyBody() => [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_primary, Color(0xFFFFB199)]), borderRadius: BorderRadius.circular(20)),
                child: const Text("BabyBites+", style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              const Text("Tüm özellikler şu an ücretsiz", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
              const SizedBox(height: 6),
              const Text(
                "Gıda rehberi, tarifler, beslenme takibi ve gelişim araçlarının tamamı herkese açık. BabyBites+ ileride eklenecek yeni özellikler için hazırlanıyor.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: _light),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFF6F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: _primary.withOpacity(0.25))),
          child: const Row(
            children: [
              Icon(Icons.favorite_outline, color: _primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Uygulamayı ücretsiz tutabilmemiz reklamlar sayesinde. Desteğin için teşekkürler!",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600, color: _text),
                ),
              ),
            ],
          ),
        ),
      ];
}