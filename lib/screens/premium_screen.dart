import 'package:flutter/material.dart';
import '../data/extras_store.dart';

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
    ["☁️", "Bulut yedek & çoklu cihaz", "Verilerin güvende; her cihazdan eriş."],
    ["🚫", "Reklamsız deneyim", "Kesintisiz, sade kullanım."],
    ["👶", "Sınırsız bebek profili", "Tüm çocuklarını tek hesapta yönet."],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        children: [
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
                const Text("İlk 1 ay ücretsiz, sonra ayda 100 ₺. İstediğin zaman iptal et.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
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
                    globalIsPremium = true;
                    globalTrialStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                  });
                  widget.onChanged?.call();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("1 aylık ücretsiz deneme başladı! 🎉")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text("1 Ay Ücretsiz Dene", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          if (globalIsPremium) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () { setState(() { globalIsPremium = false; globalTrialStart = null; }); widget.onChanged?.call(); },
                child: const Text("Aboneliği iptal et (demo)", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text("Not: Ödeme, uygulama mağazası (App Store / Google Play) üzerinden gerçekleşir. Bu sürüm tanıtım amaçlıdır.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _light)),
        ],
      ),
    );
  }
}
