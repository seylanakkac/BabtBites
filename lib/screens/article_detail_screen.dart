import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'articles_screen.dart';
import '../data/user_profile_store.dart';
import '../widgets/disclaimer.dart';
import '../widgets/sponsored_badge.dart';
import '../widgets/expert_badge.dart';
import '../widgets/image_helpers.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _green = Color(0xFF1E8C5A);

/// Makale detayı — popup yerine TAM SAYFA (tarif detayı gibi). Bilimsel,
/// görsel/video içeren yazılar için tam genişlikte okuma deneyimi + Kaynaklar.
class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final a = article;
    final sources = a.sources
        .where((s) => (s["title"] ?? "").trim().isNotEmpty || (s["url"] ?? "").trim().isNotEmpty)
        .toList();
    final expert = expertTypeForAuthor(a.author);

    final body = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPhotoUrl(a.imageUrl))
            SizedBox(width: double.infinity, height: 220, child: photoOrFallback(a.imageUrl, fallback: _coverFallback(), fit: BoxFit.cover))
          else
            _coverFallback(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.sponsored) ...[SponsoredBadge(label: a.sponsorLabel), const SizedBox(height: 12)],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(a.category),
                    if (a.readTime.trim().isNotEmpty) _meta("${a.readTime} okuma"),
                    if (a.updatedDate.trim().isNotEmpty) _meta("Son güncelleme: ${a.updatedDate}"),
                    if (sources.isNotEmpty) _scienceBadge(),
                  ],
                ),
                const SizedBox(height: 14),
                Text(a.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w800, color: _text, height: 1.2)),
                if (a.author.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.edit_note, size: 18, color: _light),
                      const SizedBox(width: 6),
                      Flexible(child: Text("Hazırlayan: ${a.author}", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _light))),
                      if (expert != null) ...[const SizedBox(width: 8), ExpertBadge(type: expert, fontSize: 11)],
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFEDEDED)),
                const SizedBox(height: 18),
                ...renderArticleBlocks(a),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _sourcesSection(sources),
                ],
                const SizedBox(height: 16),
                const MedicalDisclaimer(),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _text,
        title: const Text("Makale", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: LayoutBuilder(
        builder: (ctx, c) => c.maxWidth >= 900
            ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body))
            : body,
      ),
    );
  }

  Widget _coverFallback() => Container(
        width: double.infinity,
        height: 160,
        color: _primary.withOpacity(0.10),
        alignment: Alignment.center,
        child: Text(article.emoji, style: const TextStyle(fontSize: 56)),
      );

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: _primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _primary)),
      );

  Widget _meta(String t) => Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: _light, fontWeight: FontWeight.w500));

  Widget _scienceBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: _green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 13, color: _green),
            SizedBox(width: 4),
            Text("Bilimsel kaynaklı", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
          ],
        ),
      );

  Widget _sourcesSection(List<Map<String, String>> sources) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF2F7F4), borderRadius: BorderRadius.circular(14), border: Border.all(color: _green.withOpacity(0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.menu_book_outlined, size: 18, color: _green),
              SizedBox(width: 8),
              Text("Kaynaklar", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
            ]),
            const SizedBox(height: 10),
            ...sources.asMap().entries.map((e) {
              final i = e.key;
              final title = (e.value["title"] ?? "").trim();
              final url = (e.value["url"] ?? "").trim();
              final label = title.isNotEmpty ? title : url;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${i + 1}. ", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: url.isNotEmpty
                          ? InkWell(
                              onTap: () => _open(url),
                              child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF2563EB), height: 1.4, decoration: TextDecoration.underline)),
                            )
                          : Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.4)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
}
