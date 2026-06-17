import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/extras_store.dart';
import '../data/tracking_store.dart';
import '../services/file_storage.dart';
import '../services/storage_service.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);
const _danger = Color(0xFFFF4D6A);

class ReportScreen extends StatefulWidget {
  final Map<String, dynamic> baby;
  final String parentName;
  const ReportScreen({super.key, required this.baby, this.parentName = ""});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String get _id => (widget.baby["babyId"] as String?) ?? "";
  String get _name => widget.baby["name"]?.toString() ?? "Bebek";

  List<String> get _tried {
    final states = globalBabyFoodStates[_id] ?? {};
    return states.entries.where((e) => (e.value as Map)["tried"] == true).map((e) => e.key).toList();
  }

  List<MapEntry> get _reactions {
    final states = globalBabyFoodStates[_id] ?? {};
    return states.entries.where((e) => (e.value as Map)["status"] == "reaksiyon").toList();
  }

  List<Map<String, dynamic>> get _meds => medsFor(_id).where((m) => m["active"] == true).toList();

  Map<String, dynamic>? get _latestGrowth {
    final growth = growthFor(_id).toList()..sort((a, b) => (a["date"] as String).compareTo(b["date"] as String));
    return growth.isNotEmpty ? growth.last : null;
  }

  String _reactionLine(MapEntry e) {
    final m = e.value as Map;
    final syms = (m["reactionSymptoms"] as List?)?.join(", ") ?? "";
    return "${e.key}${syms.isNotEmpty ? " ($syms)" : ""}";
  }

  String _plainText() {
    final b = StringBuffer();
    final latest = _latestGrowth;
    b.writeln("BabyBites — Gelişim Raporu");
    b.writeln("Bebek: $_name • ${widget.baby["gender"] ?? ""} • ${widget.baby["dob"] ?? ""}");
    if (latest != null) b.writeln("Son ölçüm: ${latest["weight"]} kg, ${latest["height"]} cm (${latest["date"]})");
    b.writeln("");
    b.writeln("Denenen gıdalar (${_tried.length}): ${_tried.join(", ")}");
    b.writeln("");
    b.writeln("Reaksiyonlar (${_reactions.length}):");
    for (final e in _reactions) {
      b.writeln(" - ${_reactionLine(e)}");
    }
    b.writeln("");
    b.writeln("Aktif takviye/ilaç (${_meds.length}):");
    for (final m in _meds) {
      b.writeln(" - ${m["name"]} ${m["dose"] ?? ""} ${m["schedule"] ?? ""}");
    }
    final history = moodNoteHistory(_id);
    if (history.isNotEmpty) {
      b.writeln("");
      b.writeln("Günlük mod & notlar:");
      for (final h in history) {
        b.writeln(" - ${h["date"]}  ${moodEmoji(h["mood"]!)}  ${h["note"]}");
      }
    }
    b.writeln("");
    b.writeln("Not: Bilgilendirme amaçlıdır, tıbbi tavsiye değildir.");
    return b.toString();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- PDF export ----
  Future<void> _downloadPdf() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
      final ttf = pw.Font.ttf(fontData);
      final latest = _latestGrowth;
      final history = moodNoteHistory(_id);

      pw.TextStyle base([double s = 11, PdfColor? c]) => pw.TextStyle(font: ttf, fontSize: s, color: c);
      pw.TextStyle head() => pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFFF7A45));

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text("BabyBites — Gelişim Raporu", style: pw.TextStyle(font: ttf, fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text("Bebek: $_name  •  ${widget.baby["gender"] ?? "-"}  •  Doğum: ${widget.baby["dob"] ?? "-"}", style: base()),
          if (latest != null)
            pw.Text("Son ölçüm: ${latest["weight"]} kg • ${latest["height"]} cm (${latest["date"]})", style: base())
          else
            pw.Text("Güncel: ${widget.baby["weight"]} kg • ${widget.baby["height"]} cm", style: base()),
          pw.SizedBox(height: 16),
          pw.Text("Denenen Gıdalar (${_tried.length})", style: head()),
          pw.SizedBox(height: 4),
          pw.Text(_tried.isEmpty ? "Henüz denenen gıda yok." : _tried.join(", "), style: base()),
          pw.SizedBox(height: 14),
          pw.Text("Reaksiyonlar (${_reactions.length})", style: head()),
          pw.SizedBox(height: 4),
          if (_reactions.isEmpty)
            pw.Text("Reaksiyon kaydı yok.", style: base())
          else
            ..._reactions.map((e) => pw.Bullet(text: _reactionLine(e), style: base())),
          pw.SizedBox(height: 14),
          pw.Text("Aktif Takviye / İlaç (${_meds.length})", style: head()),
          pw.SizedBox(height: 4),
          if (_meds.isEmpty)
            pw.Text("Aktif takviye/ilaç yok.", style: base())
          else
            ..._meds.map((m) => pw.Bullet(text: "${m["name"]}  ${m["dose"] ?? ""}  ${m["schedule"] ?? ""}", style: base())),
          if (history.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text("Günlük Mod & Notlar", style: head()),
            pw.SizedBox(height: 4),
            ...history.map((h) => pw.Bullet(text: "${h["date"]}  ${moodEmoji(h["mood"]!)}  ${h["note"]}", style: base())),
          ],
          pw.SizedBox(height: 20),
          pw.Text("Bu rapor bilgilendirme amaçlıdır, tıbbi tanı/tavsiye değildir. Çocuk doktorunuzla paylaşabilirsiniz.",
              style: base(9, PdfColors.grey600)),
          if (widget.parentName.isNotEmpty)
            pw.Text("Hazırlayan: ${widget.parentName}", style: base(9, PdfColors.grey600)),
        ],
      ));
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'gelisim-raporu-$_name.pdf');
    } catch (e) {
      _snack("PDF oluşturulamadı: $e");
    }
  }

  // ---- Upload external document (e.g. e-Nabız PDF) ----
  Future<void> _uploadPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        _snack("Dosya okunamadı.");
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        _snack("Dosya çok büyük (en fazla ~8 MB).");
        return;
      }
      final now = DateTime.now();
      final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Upload to Firebase Storage (cross-device); fall back to local base64.
      String? url;
      if (uid != null) {
        url = await FileStorage.instance.uploadBytes(
          "users/$uid/reports/${now.millisecondsSinceEpoch}_${f.name}",
          bytes,
          "application/pdf",
        );
      }
      reportFilesFor(_id).add({
        "name": f.name,
        "date": date,
        if (url != null) "url": url else "dataUri": "data:application/pdf;base64,${base64Encode(bytes)}",
      });
      await StorageService.instance.saveReportFiles();
      if (!mounted) return;
      setState(() {});
      _snack(url != null ? "Belge buluta yüklendi." : "Belge yüklendi (yerel).");
    } catch (e) {
      _snack("Yükleme başarısız: $e");
    }
  }

  Future<void> _openFile(String dataUri) async {
    try {
      await launchUrl(Uri.parse(dataUri), webOnlyWindowName: '_blank');
    } catch (_) {
      _snack("Belge açılamadı.");
    }
  }

  void _deleteFile(Map<String, dynamic> file) {
    final url = file["url"]?.toString() ?? "";
    if (url.isNotEmpty) FileStorage.instance.deleteUrl(url); // best-effort
    reportFilesFor(_id).remove(file);
    StorageService.instance.saveReportFiles();
    setState(() {});
  }

  String _fileSource(Map<String, dynamic> f) =>
      (f["url"] ?? f["dataUri"])?.toString() ?? "";

  Widget _section(String title, IconData icon, Color color, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)))]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _line(String t) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.4)));

  @override
  Widget build(BuildContext context) {
    final latest = _latestGrowth;
    final history = moodNoteHistory(_id);
    final files = reportFilesFor(_id);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: const Text("Gelişim Raporu 📄", style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Metni kopyala",
            icon: const Icon(Icons.copy, color: _light),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _plainText()));
              _snack("Rapor metni kopyalandı.");
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Download / share PDF
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: const Text("PDF İndir / Paylaş", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 16),
          _section("Bebek Bilgisi", Icons.child_care, _primary, [
            _line("Ad: $_name"),
            _line("Cinsiyet: ${widget.baby["gender"] ?? "-"}"),
            _line("Doğum: ${widget.baby["dob"] ?? "-"}"),
            if (latest != null) _line("Son ölçüm: ${latest["weight"]} kg • ${latest["height"]} cm (${latest["date"]})") else _line("Güncel: ${widget.baby["weight"]} kg • ${widget.baby["height"]} cm"),
          ]),
          _section("Denenen Gıdalar (${_tried.length})", Icons.restaurant, _green, [
            if (_tried.isEmpty) _line("Henüz denenen gıda yok.") else _line(_tried.join(", ")),
          ]),
          _section("Reaksiyonlar (${_reactions.length})", Icons.warning_amber_rounded, _danger, [
            if (_reactions.isEmpty) _line("Reaksiyon kaydı yok.") else ..._reactions.map((e) => _line("• ${_reactionLine(e)}")),
          ]),
          _section("Aktif Takviye / İlaç (${_meds.length})", Icons.medication_outlined, const Color(0xFF7A5CFF), [
            if (_meds.isEmpty) _line("Aktif takviye/ilaç yok.") else ..._meds.map((m) => _line("• ${m["name"]}  ${m["dose"] ?? ""}  ${m["schedule"] ?? ""}")),
          ]),
          // Daily mood & notes history
          _section("Günlük Mod & Notlar (${history.length})", Icons.mood, const Color(0xFFB7791F), [
            if (history.isEmpty)
              _line("Henüz mod/not kaydı yok. Takvim'den günlük olarak ekleyebilirsin.")
            else
              ...history.take(30).map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(moodEmoji(h["mood"]!).isEmpty ? "📝" : moodEmoji(h["mood"]!), style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h["date"]!, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _light)),
                              if ((h["note"] ?? "").trim().isNotEmpty)
                                Text(h["note"]!, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ]),
          // Uploaded documents (e-Nabız PDFs etc.)
          _section("Belgeler / E-Nabız (${files.length})", Icons.folder_open_outlined, const Color(0xFF3B9EDB), [
            const Text("E-Nabız gibi uygulamalardan indirdiğin PDF belgeleri buraya yükleyebilirsin.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
            const SizedBox(height: 10),
            if (files.isEmpty)
              _line("Henüz belge yüklenmedi.")
            else
              ...files.map((f) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: _danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f["name"]?.toString() ?? "Belge", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
                              Text(f["date"]?.toString() ?? "", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                            ],
                          ),
                        ),
                        IconButton(tooltip: "Aç", icon: const Icon(Icons.open_in_new, size: 18, color: _primary), onPressed: () => _openFile(_fileSource(f))),
                        IconButton(tooltip: "Sil", icon: const Icon(Icons.delete_outline, size: 18, color: _danger), onPressed: () => _deleteFile(f)),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploadPdf,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text("PDF Yükle (E-Nabız vb.)", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.6)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
          const MedicalDisclaimer(text: "Bu rapor bilgilendirme amaçlıdır, tıbbi tanı/tavsiye değildir. Çocuk doktorunuzla paylaşabilirsiniz."),
          const SizedBox(height: 12),
          Center(child: Text(widget.parentName.isNotEmpty ? "Hazırlayan: ${widget.parentName}" : "BabyBites", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))),
        ],
      ),
    );
  }
}
