import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../data/extras_store.dart';
import '../data/tracking_store.dart';
import '../widgets/disclaimer.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);
const _danger = Color(0xFFFF4D6A);

class ReportScreen extends StatelessWidget {
  final Map<String, dynamic> baby;
  final String parentName;
  const ReportScreen({super.key, required this.baby, this.parentName = ""});

  @override
  Widget build(BuildContext context) {
    final id = (baby["babyId"] as String?) ?? "";
    final name = baby["name"]?.toString() ?? "Bebek";
    final states = globalBabyFoodStates[id] ?? {};
    final tried = states.entries.where((e) => (e.value as Map)["tried"] == true).map((e) => e.key).toList();
    final reactions = states.entries.where((e) => (e.value as Map)["status"] == "reaksiyon").toList();
    final meds = medsFor(id).where((m) => m["active"] == true).toList();
    final growth = growthFor(id).toList()..sort((a, b) => (a["date"] as String).compareTo(b["date"] as String));
    final latest = growth.isNotEmpty ? growth.last : null;

    String reactionLine(MapEntry e) {
      final m = e.value as Map;
      final syms = (m["reactionSymptoms"] as List?)?.join(", ") ?? "";
      return "${e.key}${syms.isNotEmpty ? " ($syms)" : ""}";
    }

    String plain() {
      final b = StringBuffer();
      b.writeln("BabyBites — Gelişim Raporu");
      b.writeln("Bebek: $name • ${baby["gender"] ?? ""} • ${baby["dob"] ?? ""}");
      if (latest != null) b.writeln("Son ölçüm: ${latest["weight"]} kg, ${latest["height"]} cm (${latest["date"]})");
      b.writeln("");
      b.writeln("Denenen gıdalar (${tried.length}): ${tried.join(", ")}");
      b.writeln("");
      b.writeln("Reaksiyonlar (${reactions.length}):");
      for (final e in reactions) {
        b.writeln(" - ${reactionLine(e)}");
      }
      b.writeln("");
      b.writeln("Aktif takviye/ilaç (${meds.length}):");
      for (final m in meds) {
        b.writeln(" - ${m["name"]} ${m["dose"] ?? ""} ${m["schedule"] ?? ""}");
      }
      b.writeln("");
      b.writeln("Not: Bilgilendirme amaçlıdır, tıbbi tavsiye değildir.");
      return b.toString();
    }

    Widget section(String title, IconData icon, Color color, List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text))]),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        );

    Widget line(String t) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.4)));

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
            icon: const Icon(Icons.copy, color: _primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: plain()));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rapor metni kopyalandı.")));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          section("Bebek Bilgisi", Icons.child_care, _primary, [
            line("Ad: $name"),
            line("Cinsiyet: ${baby["gender"] ?? "-"}"),
            line("Doğum: ${baby["dob"] ?? "-"}"),
            if (latest != null) line("Son ölçüm: ${latest["weight"]} kg • ${latest["height"]} cm (${latest["date"]})") else line("Güncel: ${baby["weight"]} kg • ${baby["height"]} cm"),
          ]),
          section("Denenen Gıdalar (${tried.length})", Icons.restaurant, _green, [
            if (tried.isEmpty) line("Henüz denenen gıda yok.") else line(tried.join(", ")),
          ]),
          section("Reaksiyonlar (${reactions.length})", Icons.warning_amber_rounded, _danger, [
            if (reactions.isEmpty) line("Reaksiyon kaydı yok.") else ...reactions.map((e) => line("• ${reactionLine(e)}")),
          ]),
          section("Aktif Takviye / İlaç (${meds.length})", Icons.medication_outlined, const Color(0xFF7A5CFF), [
            if (meds.isEmpty) line("Aktif takviye/ilaç yok.") else ...meds.map((m) => line("• ${m["name"]}  ${m["dose"] ?? ""}  ${m["schedule"] ?? ""}")),
          ]),
          const MedicalDisclaimer(text: "Bu rapor bilgilendirme amaçlıdır, tıbbi tanı/tavsiye değildir. Çocuk doktorunuzla paylaşabilirsiniz."),
          const SizedBox(height: 12),
          Center(child: Text(parentName.isNotEmpty ? "Hazırlayan: $parentName" : "BabyBites", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))),
        ],
      ),
    );
  }
}
