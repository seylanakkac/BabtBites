import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../data/milestones.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);

class MilestonesScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  final int ageMonths;
  final VoidCallback? onChanged;
  const MilestonesScreen({super.key, required this.babyId, required this.babyName, required this.ageMonths, this.onChanged});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  static const _buckets = [
    ["0–3 ay", 0, 3],
    ["4–6 ay", 4, 6],
    ["7–9 ay", 7, 9],
    ["10–12 ay", 10, 12],
    ["12–18 ay", 12, 18],
    ["18–24 ay", 18, 24],
  ];

  Color _catColor(String c) {
    switch (c) {
      case "Diş":
        return const Color(0xFF7A5CFF);
      case "Beslenme":
        return _primary;
      case "Dil/Sosyal":
        return const Color(0xFFFF4D6A);
      default:
        return const Color(0xFF2BB673);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = milestonesDoneFor(widget.babyId);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text("${widget.babyName} — Gelişim Takvimi", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("${widget.ageMonths} aylık • ${done.length}/${kMilestones.length} tamamlandı", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
          const SizedBox(height: 14),
          ..._buckets.map((b) {
            final label = b[0] as String;
            final lo = b[1] as int, hi = b[2] as int;
            final items = kMilestones.where((m) => m.minMonth >= lo && m.minMonth <= hi).toList();
            if (items.isEmpty) return const SizedBox.shrink();
            final isCurrent = widget.ageMonths >= lo && widget.ageMonths <= hi;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isCurrent ? _primary.withOpacity(0.5) : const Color(0xFFE2E2E6).withOpacity(0.6), width: isCurrent ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Text("Şu an", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _primary))),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  ...items.map((m) {
                    final isDone = done.contains(m.id);
                    return InkWell(
                      onTap: () { setState(() => isDone ? done.remove(m.id) : done.add(m.id)); widget.onChanged?.call(); },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: isDone ? _green : const Color(0xFFD0D0D6)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(m.title, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, decoration: isDone ? TextDecoration.lineThrough : null))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _catColor(m.category).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(m.category, style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _catColor(m.category)))),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const MedicalDisclaimer(text: "Gelişim basamakları geneldir ve bebekten bebeğe değişir. Endişeleriniz için çocuk doktorunuza danışın."),
        ],
      ),
    );
  }
}
