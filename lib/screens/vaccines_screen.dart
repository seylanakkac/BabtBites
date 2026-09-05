import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/extras_store.dart';
import '../data/vaccines.dart';
import '../services/local_reminders.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);
const _red = Color(0xFFFF4D6A);

/// Çocukluk çağı aşı takvimi: yaşa göre aşılar, yapıldı/bekliyor takibi,
/// yapılan aşıya tarih + not, sıradaki aşı kartı, kaydı paylaşma ve yaklaşan
/// aşılar için yerel bildirim.
class VaccinesScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  final int ageMonths;
  final DateTime? dob;
  final VoidCallback? onChanged;
  const VaccinesScreen({
    super.key,
    required this.babyId,
    required this.babyName,
    required this.ageMonths,
    required this.dob,
    this.onChanged,
  });

  @override
  State<VaccinesScreen> createState() => _VaccinesScreenState();
}

class _VaccinesScreenState extends State<VaccinesScreen> {
  static const _monthLabels = {
    0: "Doğumda",
    1: "1. ayın sonu",
    2: "2. ayın sonu",
    4: "4. ayın sonu",
    6: "6. ayın sonu",
    12: "12. ay (1 yaş)",
    18: "18. ay",
    24: "24. ay (2 yaş)",
    48: "48. ay (4 yaş)",
  };

  /// Bu aşının cihazda kullanılacak sabit bildirim kimliği (idempotent).
  int _reminderId(String vaccineId) =>
      LocalReminders.dailyIdFor(widget.babyId, vaccineId);

  DateTime? _dueDate(int month) {
    final dob = widget.dob;
    if (dob == null) return null;
    return dob.add(Duration(days: (month * 30.44).round()));
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  String _today() => DateTime.now().toIso8601String().split('T').first;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggle(Vaccine v, Set<String> done) async {
    final isDone = done.contains(v.id);
    final dates = vaccineDatesFor(widget.babyId);
    setState(() {
      if (isDone) {
        done.remove(v.id);
        dates.remove(v.id); // not KORUNUR; işaret geri konunca tarih tekrar sorulur
      } else {
        done.add(v.id);
        dates[v.id] = _today(); // varsayılan bugün; kullanıcı düzenleyebilir
      }
    });
    widget.onChanged?.call();
    // Yapıldı işaretlenince hatırlatmayı iptal et; geri alınınca kullanıcı
    // dilerse "Hatırlat" ile yeniden kurar.
    if (!isDone && LocalReminders.available) {
      await LocalReminders.cancel(_reminderId(v.id));
    }
  }

  Future<void> _editDate(Vaccine v) async {
    final dates = vaccineDatesFor(widget.babyId);
    final cur = DateTime.tryParse(dates[v.id] ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: "Aşının yapıldığı tarih",
    );
    if (picked != null) {
      setState(() => dates[v.id] = picked.toIso8601String().split('T').first);
      widget.onChanged?.call();
    }
  }

  Future<void> _editNote(Vaccine v) async {
    final notes = vaccineNotesFor(widget.babyId);
    final ctrl = TextEditingController(text: notes[v.id] ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("${v.name} — not", style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 200,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Yan etki, ateş, marka…", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text("Kaydet")),
        ],
      ),
    );
    if (res != null) {
      setState(() {
        final t = res.trim();
        if (t.isEmpty) {
          notes.remove(v.id);
        } else {
          notes[v.id] = t;
        }
      });
      widget.onChanged?.call();
    }
  }

  /// Ulusal takvimde yapılmamış, ay'ı en küçük olan aşı = sıradaki.
  Vaccine? _nextVaccine(Set<String> done) {
    final pending = kVaccines.where((v) => !v.optional && !done.contains(v.id)).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    return pending.isEmpty ? null : pending.first;
  }

  /// Yapılmamış ve tarihi gelecekte olan aşılar için yerel bildirim kurar.
  Future<void> _scheduleReminders() async {
    if (!LocalReminders.available) {
      _toast("Bu platformda hatırlatma kurulamıyor.");
      return;
    }
    if (widget.dob == null) {
      _toast("Hatırlatma için bebeğin doğum tarihi gerekli (Profil'den ekleyin).");
      return;
    }
    final ok = await LocalReminders.requestPermission();
    if (!ok) {
      _toast("Bildirim izni verilmedi.");
      return;
    }
    final done = vaccinesDoneFor(widget.babyId);
    final now = DateTime.now();
    var count = 0;
    for (final v in kVaccines) {
      if (v.optional) continue; // özel aşılar bilgi amaçlı — hatırlatma kurulmaz
      if (done.contains(v.id)) continue;
      final due = _dueDate(v.month);
      if (due == null || !due.isAfter(now)) continue;
      final id = await LocalReminders.scheduleIn(
        after: due.difference(now),
        title: "Aşı zamanı yaklaşıyor 💉",
        body: "${widget.babyName} için ${v.name} (${v.dose}) zamanı geldi.",
        id: _reminderId(v.id),
      );
      if (id != null) count++;
    }
    _toast(count > 0
        ? "$count yaklaşan aşı için hatırlatma kuruldu."
        : "Kurulacak yaklaşan aşı bulunamadı.");
  }

  Future<void> _share(Set<String> done) async {
    final dates = vaccineDatesFor(widget.babyId);
    final notes = vaccineNotesFor(widget.babyId);
    final b = StringBuffer();
    b.writeln("BabyBites — ${widget.babyName} Aşı Kaydı");
    b.writeln("${widget.ageMonths} aylık");
    b.writeln("");
    b.writeln("YAPILAN AŞILAR");
    final doneList = kVaccines.where((v) => done.contains(v.id)).toList();
    if (doneList.isEmpty) b.writeln("- (henüz kayıt yok)");
    for (final v in doneList) {
      final d = dates[v.id];
      final n = notes[v.id];
      b.writeln("✓ ${v.name} (${v.dose})"
          "${d != null ? " — ${_fmtDate(d)}" : ""}"
          "${n != null && n.isNotEmpty ? " • not: $n" : ""}");
    }
    b.writeln("");
    b.writeln("BEKLEYEN AŞILAR (ulusal takvim)");
    final pending = kVaccines.where((v) => !v.optional && !done.contains(v.id)).toList()
      ..sort((a, b) => a.month.compareTo(b.month));
    if (pending.isEmpty) b.writeln("- (tümü tamamlandı)");
    for (final v in pending) {
      b.writeln("• ${v.name} (${v.dose}) — ~${v.month}. ay");
    }
    b.writeln("");
    b.writeln("Bu kayıt BabyBites uygulamasıyla oluşturuldu ve genel bilgilendirme amaçlıdır. Resmî aşı kaydı için aile sağlığı merkezinize danışın.");
    await Share.share(b.toString(), subject: "${widget.babyName} Aşı Kaydı");
  }

  @override
  Widget build(BuildContext context) {
    final done = vaccinesDoneFor(widget.babyId);
    final dates = vaccineDatesFor(widget.babyId);
    final notes = vaccineNotesFor(widget.babyId);
    final national = kVaccines.where((v) => !v.optional).toList();
    final optional = kVaccines.where((v) => v.optional).toList();
    final nationalDone = national.where((v) => done.contains(v.id)).length;
    final next = _nextVaccine(done);
    // Ay -> o aya ait ulusal aşılar.
    final months = <int>[];
    for (final v in national) {
      if (!months.contains(v.month)) months.add(v.month);
    }
    months.sort();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text("${widget.babyName} — Aşı Takvimi", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Kaydı paylaş",
            icon: const Icon(Icons.ios_share, color: _primary),
            onPressed: () => _share(done),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Text("${widget.ageMonths} aylık • $nationalDone/${national.length} yapıldı (ulusal takvim)", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
          const SizedBox(height: 12),
          if (next != null) _nextCard(next),
          if (LocalReminders.available)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scheduleReminders,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text("Yaklaşan aşıları hatırlat", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          const SizedBox(height: 14),
          ...months.map((m) {
            final items = national.where((v) => v.month == m).toList();
            final isCurrent = widget.ageMonths >= m && widget.ageMonths < m + 2;
            final label = _monthLabels[m] ?? "$m. ay";
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
                  ...items.map((v) => _vaccineRow(v, m, done, dates, notes)),
                ],
              ),
            );
          }),
          if (optional.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text("Özel Aşılar", style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 2),
            const Text("Ulusal takvimde yer almaz (ücretli). Bilgi amaçlıdır; otomatik hatırlatma kurulmaz. Menenjit, rotavirüs ve grip aşıları için yaptırma kararını hekiminize danışın.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: optional.map((v) => _vaccineRow(v, v.month, done, dates, notes, optional: true)).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const MedicalDisclaimer(text: "Bu takvim genel bilgilendirme amaçlıdır ve güncellenebilir. Aşı kararları ve güncel takvim için çocuk doktorunuza / aile sağlığı merkezine danışın."),
        ],
      ),
    );
  }

  /// Sıradaki (yapılmamış) aşı için belirgin kart — tarih ve kalan gün.
  Widget _nextCard(Vaccine next) {
    final due = _dueDate(next.month);
    String when;
    Color tone = _primary;
    if (due == null) {
      when = "~${next.month}. ay";
    } else {
      final days = due.difference(DateTime.now()).inDays;
      if (days > 1) {
        when = "${_fmtDate(due.toIso8601String())} • $days gün kaldı";
      } else if (days >= 0) {
        when = "${_fmtDate(due.toIso8601String())} • bugünlerde";
      } else {
        when = "${_fmtDate(due.toIso8601String())} • ${-days} gün geçti";
        tone = _red;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: tone.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.vaccines, color: tone, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sıradaki aşı", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
              const SizedBox(height: 2),
              Text("${next.name} — ${next.dose}", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
              const SizedBox(height: 2),
              Text(when, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: tone)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _vaccineRow(Vaccine v, int month, Set<String> done, Map<String, String> dates, Map<String, String> notes, {bool optional = false}) {
    final isDone = done.contains(v.id);
    final overdue = !optional && !isDone && widget.ageMonths >= month + 2;
    final note = notes[v.id];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggle(v, done),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: isDone ? _green : (overdue ? _red : const Color(0xFFD0D0D6))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text("${v.name} — ${v.dose}", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text, decoration: isDone ? TextDecoration.lineThrough : null))),
                          if (optional)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Text("~${v.month}. ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _primary)))
                          else if (overdue)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _red.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: const Text("Zamanı geçti", style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _red))),
                        ]),
                        const SizedBox(height: 2),
                        Text(v.against, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tarih + not satırı (taplar toggle'ı tetiklemez).
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isDone)
                  _chip(
                    icon: Icons.event_available,
                    label: dates[v.id] != null ? _fmtDate(dates[v.id]!) : "tarih ekle",
                    color: _green,
                    onTap: () => _editDate(v),
                  ),
                _chip(
                  icon: note != null && note.isNotEmpty ? Icons.sticky_note_2 : Icons.note_add_outlined,
                  label: note != null && note.isNotEmpty ? "notu düzenle" : "not ekle",
                  color: _light,
                  onTap: () => _editNote(v),
                ),
                if (note != null && note.isNotEmpty)
                  Text(note, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontStyle: FontStyle.italic, color: _text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color == _light ? _text : color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: color == _light ? _text : color)),
        ]),
      ),
    );
  }
}
