import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/extras_store.dart';
import '../data/teeth.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);

// Ağız görselinin renkleri.
const _lip = Color(0xFFE58B92); // dudak
const _cavity = Color(0xFF6E2B39); // ağız boşluğu (koyu)
const _tongue = Color(0xFFD98A97); // dil
const _gum = Color(0xFFF2C4CB); // diş eti bandı

/// Diş çıkarma takibi: ağız içindeki 20 süt dişini gerçekçi biçimde gösteren
/// görsel harita. Dişe dokununca "çıktı" işaretlenir ve çıkış tarihi kaydedilir;
/// yaşına göre beklenen dişler vurgulanır. Sıradaki diş ipucu ve diş çıkarma
/// belirtileri de gösterilir.
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

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  void _toggleTooth(Tooth t) {
    final erupted = teethEruptedFor(widget.babyId);
    final dates = teethDatesFor(widget.babyId);
    setState(() {
      _selected = t.id;
      if (erupted.contains(t.id)) {
        erupted.remove(t.id);
        dates.remove(t.id);
      } else {
        erupted.add(t.id);
        dates[t.id] = DateTime.now().toIso8601String().split('T').first;
      }
    });
    widget.onChanged?.call();
  }

  Future<void> _editToothDate(Tooth t) async {
    final dates = teethDatesFor(widget.babyId);
    final cur = DateTime.tryParse(dates[t.id] ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: "Dişin çıktığı tarih",
    );
    if (picked != null) {
      setState(() => dates[t.id] = picked.toIso8601String().split('T').first);
      widget.onChanged?.call();
    }
  }

  /// Henüz çıkmamış, tipik çıkış yaşı en erken olan diş = sırada beklenen.
  Tooth? _nextTooth(Set<String> erupted) {
    final pending = kTeeth.where((t) => !erupted.contains(t.id)).toList()
      ..sort((a, b) => a.minMonth.compareTo(b.minMonth));
    return pending.isEmpty ? null : pending.first;
  }

  @override
  Widget build(BuildContext context) {
    final erupted = teethEruptedFor(widget.babyId);
    final dates = teethDatesFor(widget.babyId);
    final next = _nextTooth(erupted);
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
          const Text("Ağızdaki dişe dokununca 'çıktı' olarak işaretlenir ve tarihi kaydedilir.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
          const SizedBox(height: 16),
          // ---- Ağız içi görsel harita ----
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
            child: Column(
              children: [
                const Text("Üst çene", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
                const SizedBox(height: 4),
                _MouthDiagram(
                  erupted: erupted,
                  ageMonths: widget.ageMonths,
                  selected: _selected,
                  onTap: _toggleTooth,
                ),
                const SizedBox(height: 4),
                const Text("Alt çene", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ---- Sıradaki diş ipucu ----
          if (next != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _primary.withOpacity(0.35))),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: _primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.child_care, color: _primary, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Sırada beklenen diş", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
                      const SizedBox(height: 2),
                      Text(next.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                      const SizedBox(height: 2),
                      Text("Tipik çıkış: ${next.minMonth}–${next.maxMonth} ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
                    ],
                  ),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _green.withOpacity(0.35))),
              child: const Row(children: [
                Icon(Icons.celebration, color: _green, size: 22),
                SizedBox(width: 10),
                Expanded(child: Text("Tüm süt dişleri çıktı 🎉", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
              ]),
            ),
          const SizedBox(height: 14),
          // ---- Seçili diş bilgisi ----
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
                      if (erupted.contains(sel.id)) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _editToothDate(sel!),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: _green.withOpacity(0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: _green.withOpacity(0.35))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.event_available, size: 13, color: _green),
                              const SizedBox(width: 4),
                              Text(dates[sel.id] != null ? "Çıkış: ${_fmtDate(dates[sel.id]!)}" : "tarih ekle", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          // ---- Açıklama (renk anahtarı) ----
          Row(children: [
            _legendDot(_green, "Çıktı"),
            const SizedBox(width: 14),
            _legendDot(_primary, "Bu yaşta beklenen"),
          ]),
          const SizedBox(height: 16),
          // ---- Çıkış tarihi geçmişi (kronolojik) ----
          _history(erupted, dates),
          const SizedBox(height: 16),
          // ---- Diş çıkarma belirtileri ve öneriler ----
          _symptomsCard(),
          const SizedBox(height: 16),
          const MedicalDisclaimer(text: "Diş çıkarma yaşları geneldir ve bebekten bebeğe aylarca değişebilir. Yüksek ateş, ishal gibi belirtiler diş çıkarmaya bağlanmamalı; sürerse veya belirgin gecikme/sorun olursa diş hekimine/çocuk doktoruna danışın."),
        ],
      ),
    );
  }

  Widget _history(Set<String> erupted, Map<String, String> dates) {
    // Tarihi olan çıkmış dişleri tarihe göre sırala.
    final withDate = kTeeth.where((t) => erupted.contains(t.id) && dates[t.id] != null).toList()
      ..sort((a, b) => (dates[a.id] ?? '').compareTo(dates[b.id] ?? ''));
    if (withDate.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Çıkış geçmişi", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 8),
          ...withDate.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: _green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _text))),
                  Text(_fmtDate(dates[t.id]!), style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: _light)),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _symptomsCard() {
    const symptoms = [
      "Salya (tükürük) artışı ve çeneye/boyuna pişik",
      "Her şeyi ısırma, kaşıma isteği",
      "Diş etinde şişlik, kızarıklık veya hassasiyet",
      "Huzursuzluk, ağlama ve uyku düzeninde bozulma",
      "İştahsızlık; hafif (yüksek olmayan) ısı artışı olabilir",
    ];
    const tips = [
      "Temiz parmakla veya yumuşak fırçayla diş etine hafif masaj",
      "Buzdolabında soğutulmuş (dondurulmuş DEĞİL) diş kaşıyıcı verin",
      "Salyayı sık silip cildi kuru tutun (pişik önlenir)",
      "İlk diş çıkınca yumuşak bebek diş fırçasıyla temizliğe başlayın",
      "Boyuna takılan kehribar kolyeler boğulma/takılma riski taşır; önerilmez",
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.healing_outlined, size: 18, color: _primary),
            SizedBox(width: 8),
            Text("Diş çıkarma belirtileri", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          ]),
          const SizedBox(height: 8),
          ...symptoms.map((s) => _bullet(s, _primary)),
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.tips_and_updates_outlined, size: 18, color: _green),
            SizedBox(width: 8),
            Text("Rahatlatma önerileri", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
          ]),
          const SizedBox(height: 8),
          ...tips.map((s) => _bullet(s, _green)),
        ],
      ),
    );
  }

  Widget _bullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _text, height: 1.35))),
      ]),
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

/// Ağız içindeki iki diş kavsini (üst/alt) gerçekçi biçimde çizen ve
/// dokunulabilir dişler yerleştiren görsel. Dişler bir elips profili boyunca
/// dizilir; üst kavis aşağı (gülümseme), alt kavis yukarı (kaş) doğru kavislenir.
class _MouthDiagram extends StatelessWidget {
  final Set<String> erupted;
  final int ageMonths;
  final String? selected;
  final void Function(Tooth) onTap;
  const _MouthDiagram({
    required this.erupted,
    required this.ageMonths,
    required this.selected,
    required this.onTap,
  });

  List<Tooth> _arch(String arch) {
    final list = kTeeth.where((t) => t.arch == arch).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w * 0.82; // dental kavis için hafif yatay oval
      final cx = w / 2;
      final archWidth = w * 0.70;
      final archHeight = h * 0.21;

      // Tam elips (yuvarlatılmış dörtgeni elipse çeviren yarıçap).
      BorderRadius ellipse(double bw, double bh) =>
          BorderRadius.all(Radius.elliptical(bw / 2, bh / 2));

      final children = <Widget>[
        // Dudaklar (dış elips).
        Positioned.fill(
          child: Container(decoration: BoxDecoration(color: _lip, borderRadius: ellipse(w, h))),
        ),
        // Ağız boşluğu (iç elips, koyu).
        Positioned(
          left: w * 0.06, top: h * 0.06, right: w * 0.06, bottom: h * 0.06,
          child: Container(decoration: BoxDecoration(color: _cavity, borderRadius: ellipse(w * 0.88, h * 0.88))),
        ),
        // Dil (alt-orta, dişlerin arkasında).
        Positioned(
          left: w * 0.30, right: w * 0.30, top: h * 0.60, bottom: h * 0.12,
          child: Container(decoration: BoxDecoration(color: _tongue, borderRadius: BorderRadius.vertical(top: Radius.circular(w * 0.18), bottom: Radius.circular(w * 0.1)))),
        ),
        // Diş eti bandı (dişlerin arkasında hafif pembe kavis).
        ..._gumBand(cx, h * 0.45, archWidth, archHeight, true, w),
        ..._gumBand(cx, h * 0.55, archWidth, archHeight, false, w),
      ];

      // Üst dişler: aşağı kavisli (orta kesiciler altta/önde, azılar yukarıda).
      for (final t in _arch("upper")) {
        final u = (t.order - 4.5) / 4.5; // -1..1
        final x = cx + u * (archWidth / 2);
        final y = h * 0.45 - archHeight * (1 - math.sqrt((1 - u * u).clamp(0.0, 1.0)));
        children.add(_toothWidget(t, x, y, u * 0.45, w));
      }
      // Alt dişler: yukarı kavisli.
      for (final t in _arch("lower")) {
        final u = (t.order - 4.5) / 4.5;
        final x = cx + u * (archWidth / 2);
        final y = h * 0.55 + archHeight * (1 - math.sqrt((1 - u * u).clamp(0.0, 1.0)));
        children.add(_toothWidget(t, x, y, -u * 0.45, w));
      }

      return SizedBox(
        width: w,
        height: h,
        child: Stack(clipBehavior: Clip.none, children: children),
      );
    });
  }

  /// Diş etini kavis boyunca dişlerin biraz arkasında (dudağa doğru) ima eden
  /// hafif pembe bant. Diş kavsiyle AYNI formülü kullanır, dışa doğru kaydırır.
  List<Widget> _gumBand(double cx, double baseY, double archWidth, double archHeight, bool upper, double w) {
    final out = <Widget>[];
    const n = 20;
    final dot = w * 0.11;
    for (var i = 0; i <= n; i++) {
      final u = (i / n) * 2 - 1; // -1..1
      final x = cx + u * (archWidth / 2);
      final dy = archHeight * (1 - math.sqrt((1 - u * u).clamp(0.0, 1.0)));
      // Dişler baseY ± dy'de; diş eti biraz DAHA dışarıda (dudağa doğru).
      final y = upper ? baseY - dy - w * 0.02 : baseY + dy + w * 0.02;
      out.add(Positioned(
        left: x - dot / 2, top: y - dot / 2,
        child: Container(width: dot, height: dot, decoration: const BoxDecoration(color: _gum, shape: BoxShape.circle)),
      ));
    }
    return out;
  }

  Widget _toothWidget(Tooth t, double x, double y, double rot, double w) {
    final isErupted = erupted.contains(t.id);
    final expectedNow = !isErupted && ageMonths >= t.minMonth && ageMonths <= t.maxMonth;
    final isSel = t.id == selected;

    // Diş tipine göre boyut (azılar geniş, kesiciler dar).
    final isMolar = t.type == "m1" || t.type == "m2";
    final tw = (isMolar ? w * 0.078 : (t.type == "canine" ? w * 0.056 : w * 0.05)).clamp(16.0, 60.0);
    final th = (isMolar ? w * 0.072 : w * 0.092).clamp(22.0, 60.0);

    final border = isErupted ? _green : (expectedNow ? _primary : const Color(0xFFC9A9AF));
    final fill = isErupted
        ? Colors.white
        : (expectedNow ? _primary.withOpacity(0.20) : Colors.white.withOpacity(0.78));

    // Dokunma alanını en az 40px tut.
    final hitW = math.max(tw + 6, 34.0);
    final hitH = math.max(th + 6, 38.0);

    return Positioned(
      left: x - hitW / 2,
      top: y - hitH / 2,
      child: GestureDetector(
        onTap: () => onTap(t),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: hitW,
          height: hitH,
          child: Center(
            child: Transform.rotate(
              angle: rot,
              child: Container(
                width: tw,
                height: th,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(tw * 0.35), bottom: Radius.circular(tw * 0.5)),
                  border: Border.all(color: border, width: isSel ? 3 : (isErupted || expectedNow ? 2 : 1)),
                  boxShadow: isErupted ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 3, offset: const Offset(0, 1))] : null,
                ),
                child: isErupted
                    ? const Icon(Icons.check, size: 12, color: _green)
                    : (isSel ? const Icon(Icons.touch_app, size: 11, color: _primary) : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
