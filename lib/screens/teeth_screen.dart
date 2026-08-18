import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../data/teeth.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);
const _gum = Color(0xFFF7D9DE);

/// Diş çıkarma takibi: 20 süt dişinden oluşan görsel ağız haritası. Dokununca
/// diş "çıktı" olarak işaretlenir; yaşına göre beklenen dişler vurgulanır.
class TeethScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  final int ageMonths;
  final VoidCallback? onChanged;
  const TeethScreen({
    super.key,
    required this.babyId,
    required this.babyName,
    required this.ageMonths,
    this.onChanged,
  });

  @override
  State<TeethScreen> createState() => _TeethScreenState();
}

class _TeethScreenState extends State<TeethScreen> {
  String? _selected;

  List<Tooth> _arch(String arch) {
    final list = kTeeth.where((t) => t.arch == arch).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Widget _tooth(Tooth t, Set<String> erupted) {
    final isErupted = erupted.contains(t.id);
    // Yaşına göre şu sıralar beklenen (henüz çıkmamış) diş.
    final expectedNow = !isErupted &&
        widget.ageMonths >= t.minMonth &&
        widget.ageMonths <= t.maxMonth;
    final radius = t.arch == "upper"
        ? const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(10))
        : const BorderRadius.vertical(top: Radius.circular(10), bottom: Radius.circular(4));
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = t.id;
          isErupted ? erupted.remove(t.id) : erupted.add(t.id);
        });
        widget.onChanged?.call();
      },
      child: Container(
        width: 24,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: isErupted ? Colors.white : Colors.white.withOpacity(0.35),
          borderRadius: radius,
          border: Border.all(
            color: isErupted
                ? _green
                : (expectedNow ? _primary : const Color(0xFFCBB5B9)),
            width: isErupted || expectedNow ? 2 : 1,
          ),
        ),
        child: isErupted
            ? const Icon(Icons.check, size: 13, color: _green)
            : (t.id == _selected
                ? const Icon(Icons.touch_app, size: 12, color: _primary)
                : null),
      ),
    );
  }

  Widget _archRow(String arch, Set<String> erupted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: _gum, borderRadius: BorderRadius.circular(14)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _arch(arch).map((t) => _tooth(t, erupted)).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erupted = teethEruptedFor(widget.babyId);
    Tooth? sel;
    if (_selected != null) {
      for (final t in kTeeth) {
        if (t.id == _selected) {
          sel = t;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text("${widget.babyName} — Diş Takibi", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Text("${widget.ageMonths} aylık • ${erupted.length}/20 diş çıktı", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
          const SizedBox(height: 4),
          const Text("Dişe dokununca 'çıktı' olarak işaretlenir.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
          const SizedBox(height: 16),
          const Text("Üst dişler", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 6),
          _archRow("upper", erupted),
          const SizedBox(height: 12),
          _archRow("lower", erupted),
          const SizedBox(height: 6),
          const Text("Alt dişler", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 16),
          // Seçili diş bilgisi.
          if (sel != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
              child: Row(children: [
                Icon(erupted.contains(sel.id) ? Icons.check_circle : Icons.child_care, color: erupted.contains(sel.id) ? _green : _primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sel.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                      const SizedBox(height: 2),
                      Text("Tipik çıkış: ${sel.minMonth}–${sel.maxMonth} ay • ${erupted.contains(sel.id) ? "çıktı" : "henüz çıkmadı"}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                    ],
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          // Açıklama satırı.
          Row(children: [
            _legendDot(_green, "Çıktı"),
            const SizedBox(width: 14),
            _legendDot(_primary, "Bu yaşta beklenen"),
          ]),
          const SizedBox(height: 16),
          const MedicalDisclaimer(text: "Diş çıkarma yaşları geneldir ve bebekten bebeğe aylarca değişebilir. Belirgin gecikme veya sorunlarda diş hekimine/çocuk doktoruna danışın."),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), border: Border.all(color: c, width: 2))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
    ]);
  }
}
