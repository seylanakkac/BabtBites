import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../data/who_reference.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);

class GrowthScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  final String sex; // "Erkek" | "Kız"
  final DateTime? dob;
  final VoidCallback? onChanged;
  const GrowthScreen({super.key, required this.babyId, required this.babyName, required this.sex, required this.dob, this.onChanged});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  int _metric = 0; // 0 = Kilo, 1 = Boy

  double _ageMonthsAt(String iso) {
    if (widget.dob == null) return 0;
    final p = iso.split('-');
    if (p.length != 3) return 0;
    final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return d.difference(widget.dob!).inDays / 30.4;
  }

  @override
  Widget build(BuildContext context) {
    final sex = widget.sex == "Erkek" ? "Erkek" : "Kız";
    final band = _metric == 0 ? kWhoWeight[sex]! : kWhoHeight[sex]!;
    final unit = _metric == 0 ? "kg" : "cm";
    final field = _metric == 0 ? "weight" : "height";
    final records = growthFor(widget.babyId).toList()
      ..sort((a, b) => (a["date"] as String).compareTo(b["date"] as String));
    final points = <Offset>[];
    for (final r in records) {
      final v = (r[field] as num?)?.toDouble();
      if (v == null || v <= 0) continue;
      points.add(Offset(_ageMonthsAt(r["date"] as String).clamp(0, 24).toDouble(), v));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text("${widget.babyName} — Büyüme", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Metric toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
            child: Row(children: [_metricTab("Kilo", 0), _metricTab("Boy", 1)]),
          ),
          const SizedBox(height: 16),
          // Chart
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _GrowthPainter(band: band, points: points, unit: unit),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 14, runSpacing: 4, alignment: WrapAlignment.center, children: [
                  _legend(const Color(0xFFBFD8C9), "P3 (alt sınır)"),
                  _legend(const Color(0xFF2BB673), "P50 (ortalama)"),
                  _legend(const Color(0xFFBFD8C9), "P97 (üst sınır)"),
                  _legend(_primary, widget.babyName),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMeasurement,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Ölçüm Ekle", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Henüz ölçüm yok. 'Ölçüm Ekle' ile başlayın.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)))
          else
            ...records.reversed.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
                  child: Row(children: [
                    const Icon(Icons.straighten, size: 18, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_fmt(r["date"] as String), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text))),
                    Text("${r["weight"] ?? "-"} kg • ${r["height"] ?? "-"} cm", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF4D6A)), onPressed: () { setState(() => growthFor(widget.babyId).remove(r)); widget.onChanged?.call(); }),
                  ]),
                )),
          const SizedBox(height: 12),
          const MedicalDisclaimer(text: "Büyüme bantları yaklaşık WHO referansıdır, tanı aracı değildir. Değerlendirme için çocuk doktorunuza danışın."),
        ],
      ),
    );
  }

  Widget _metricTab(String label, int i) {
    final sel = _metric == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metric = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? _primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: sel ? Colors.white : _light))),
        ),
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 3, color: c),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: _light)),
      ]);

  String _fmt(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    const months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return "${int.parse(p[2])} ${months[(int.parse(p[1]) - 1).clamp(0, 11)]} ${p[0]}";
  }

  void _addMeasurement() {
    DateTime date = DateTime.now();
    final weight = TextEditingController();
    final height = TextEditingController();
    final head = TextEditingController();
    InputDecoration dec(String l) => InputDecoration(labelText: l, labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light), isDense: true, filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Yeni Ölçüm", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: _text)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: dctx,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('tr', 'TR'),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _primary, onPrimary: Colors.white, onSurface: _text)),
                    child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(MediaQuery.of(context).size.shortestSide, MediaQuery.of(context).size.longestSide)), child: child!),
                  ),
                );
                if (picked != null) setD(() => date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: _light), const SizedBox(width: 8), Text("${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text))]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec("Kilo (kg)"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec("Boy (cm)"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: head, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec("Baş çevresi (cm) — opsiyonel"), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text("İptal", style: TextStyle(fontFamily: 'Inter', color: _light))),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(weight.text.trim().replaceAll(',', '.'));
                final h = double.tryParse(height.text.trim().replaceAll(',', '.'));
                if (w == null && h == null) { Navigator.pop(dctx); return; }
                growthFor(widget.babyId).add({
                  "date": "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                  "weight": w ?? 0,
                  "height": h ?? 0,
                  "head": double.tryParse(head.text.trim().replaceAll(',', '.')) ?? 0,
                });
                widget.onChanged?.call();
                Navigator.pop(dctx);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kaydet", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) { weight.dispose(); height.dispose(); head.dispose(); });
  }
}

class _GrowthPainter extends CustomPainter {
  final WhoBand band;
  final List<Offset> points; // x: month 0..24, y: value
  final String unit;
  _GrowthPainter({required this.band, required this.points, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 30.0, padB = 20.0, padT = 8.0, padR = 6.0;
    final w = size.width - padL - padR;
    final h = size.height - padB - padT;
    final minY = band.p3.first * 0.9;
    final maxY = band.p97.last * 1.05;
    const maxX = 24.0;

    double dx(double m) => padL + (m / maxX) * w;
    double dy(double v) => padT + h - ((v - minY) / (maxY - minY)) * h;

    final axis = Paint()..color = const Color(0xFFE2E2E6)..strokeWidth = 1;
    canvas.drawLine(const Offset(padL, padT), Offset(padL, padT + h), axis);
    canvas.drawLine(Offset(padL, padT + h), Offset(padL + w, padT + h), axis);

    // X labels (months)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final m in [0, 6, 12, 18, 24]) {
      tp.text = TextSpan(text: "$m", style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: _light));
      tp.layout();
      tp.paint(canvas, Offset(dx(m.toDouble()) - tp.width / 2, padT + h + 4));
    }
    // Y labels
    for (var i = 0; i <= 4; i++) {
      final v = minY + (maxY - minY) * i / 4;
      tp.text = TextSpan(text: v.toStringAsFixed(0), style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: _light));
      tp.layout();
      tp.paint(canvas, Offset(2, dy(v) - tp.height / 2));
    }

    void drawBand(List<double> series, Color color, double stroke) {
      final p = Paint()..color = color..strokeWidth = stroke..style = PaintingStyle.stroke;
      final path = Path();
      for (var m = 0; m < series.length; m++) {
        final o = Offset(dx(m.toDouble()), dy(series[m]));
        if (m == 0) { path.moveTo(o.dx, o.dy); } else { path.lineTo(o.dx, o.dy); }
      }
      canvas.drawPath(path, p);
    }

    drawBand(band.p3, const Color(0xFFBFD8C9), 1.5);
    drawBand(band.p97, const Color(0xFFBFD8C9), 1.5);
    drawBand(band.p50, const Color(0xFF2BB673), 2);

    // Baby points
    if (points.isNotEmpty) {
      final line = Paint()..color = _primary..strokeWidth = 2.5..style = PaintingStyle.stroke;
      final dot = Paint()..color = _primary;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = Offset(dx(points[i].dx), dy(points[i].dy));
        if (i == 0) { path.moveTo(o.dx, o.dy); } else { path.lineTo(o.dx, o.dy); }
        canvas.drawCircle(o, 3.5, dot);
      }
      if (points.length > 1) canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_GrowthPainter o) => o.points != points || o.band != band;
}
