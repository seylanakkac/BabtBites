import 'package:flutter/material.dart';
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

/// Çocukluk çağı aşı takvimi: yaşa göre aşılar, yapıldı/bekliyor takibi ve
/// yaklaşan aşılar için yerel bildirim.
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggle(Vaccine v, Set<String> done) async {
    final isDone = done.contains(v.id);
    setState(() => isDone ? done.remove(v.id) : done.add(v.id));
    widget.onChanged?.call();
    // Yapıldı işaretlenince hatırlatmayı iptal et; geri alınınca kullanıcı
    // dilerse "Hatırlat" ile yeniden kurar.
    if (!isDone && LocalReminders.available) {
      await LocalReminders.cancel(_reminderId(v.id));
    }
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

  @override
  Widget build(BuildContext context) {
    final done = vaccinesDoneFor(widget.babyId);
    final national = kVaccines.where((v) => !v.optional).toList();
    final optional = kVaccines.where((v) => v.optional).toList();
    final nationalDone = national.where((v) => done.contains(v.id)).length;
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
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        children: [
          Text("${widget.ageMonths} aylık • $nationalDone/${national.length} yapıldı (ulusal takvim)", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
          const SizedBox(height: 12),
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
                  ...items.map((v) {
                    final isDone = done.contains(v.id);
                    final overdue = !isDone && widget.ageMonths >= m + 2;
                    return InkWell(
                      onTap: () => _toggle(v, done),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
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
                                    if (overdue) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _red.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: const Text("Zamanı geçti", style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _red))),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(v.against, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
                children: optional.map((v) {
                  final isDone = done.contains(v.id);
                  return InkWell(
                    onTap: () => _toggle(v, done),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: isDone ? _green : const Color(0xFFD0D0D6)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text("${v.name} — ${v.dose}", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text, decoration: isDone ? TextDecoration.lineThrough : null))),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Text("~${v.month}. ay", style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _primary))),
                                ]),
                                const SizedBox(height: 2),
                                Text(v.against, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const MedicalDisclaimer(text: "Bu takvim genel bilgilendirme amaçlıdır ve güncellenebilir. Aşı kararları ve güncel takvim için çocuk doktorunuza / aile sağlığı merkezine danışın."),
        ],
      ),
    );
  }
}
