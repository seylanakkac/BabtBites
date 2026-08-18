import 'package:flutter/material.dart';
import '../data/feeding_steps.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);

/// Ek gıdaya geçiş gelişim basamakları — yaşa göre aşama rehberi.
class FeedingStepsScreen extends StatelessWidget {
  final String babyName;
  final int ageMonths;
  const FeedingStepsScreen({super.key, required this.babyName, required this.ageMonths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: const Text("Ek Gıda Basamakları", style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Text("$babyName • $ageMonths aylık", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
          const SizedBox(height: 14),
          ...kFeedingSteps.map((s) {
            final isCurrent = ageMonths >= s.minMonth && ageMonths <= s.maxMonth;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isCurrent ? _primary.withOpacity(0.6) : const Color(0xFFE2E2E6).withOpacity(0.6), width: isCurrent ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (isCurrent ? _primary : _light).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text("${s.minMonth}–${s.maxMonth} ay", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: isCurrent ? _primary : _light))),
                  ]),
                  if (isCurrent) ...[
                    const SizedBox(height: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Text("Şu anki aşama", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _primary))),
                  ],
                  const SizedBox(height: 8),
                  Text(s.summary, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.4)),
                  const SizedBox(height: 8),
                  ...s.tips.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("• ", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _primary, fontWeight: FontWeight.bold)),
                          Expanded(child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: _text, height: 1.35))),
                        ]),
                      )),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const MedicalDisclaimer(text: "Ek gıdaya geçiş her bebekte farklı ilerler. Başlama zamanı ve besin seçimi için çocuk doktorunuza danışın (DSÖ ~6. ayı önerir)."),
        ],
      ),
    );
  }
}
