import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Displays a bundled legal document (Markdown asset) with light formatting.
class LegalScreen extends StatelessWidget {
  final String title;
  final String assetPath;
  const LegalScreen({super.key, required this.title, required this.assetPath});

  static const _text = Color(0xFF2D2D3A);
  static const _light = Color(0xFFA8A8B3);
  static const _bg = Color(0xFFFAF9F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A45)));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + MediaQuery.of(context).padding.bottom),
            children: _render(snap.data!),
          );
        },
      ),
    );
  }

  // Very light Markdown rendering: headings, bullets, quotes, rules, paragraphs.
  List<Widget> _render(String md) {
    final widgets = <Widget>[];
    String clean(String s) => s.replaceAll('**', '').replaceAll('`', '').trim();

    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(clean(line.substring(4)), style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(clean(line.substring(3)), style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(clean(line.substring(2)), style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: _text)),
        ));
      } else if (line.trim() == '---') {
        widgets.add(const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: Color(0xFFE2E2E6))));
      } else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8C879).withOpacity(0.5))),
          child: Text(clean(line.substring(2)), style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF8A7A4A), height: 1.4)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: _light)),
              Expanded(child: Text(clean(line.substring(2)), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.45))),
            ],
          ),
        ));
      } else if (line.startsWith('  - ') || line.startsWith('  * ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle_outlined, size: 5, color: _light)),
              Expanded(child: Text(clean(line.trimLeft().substring(2)), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.45))),
            ],
          ),
        ));
      } else if (line.startsWith('*') && line.endsWith('*')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(clean(line), style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontStyle: FontStyle.italic, color: _light, height: 1.4)),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(clean(line), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.5)),
        ));
      }
    }
    return widgets;
  }
}
