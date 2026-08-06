import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'image_helpers.dart';
import 'web_embed.dart';

/// Genel amaçlı paylaşım kartı (makale, rehber, örnek menü…).
///
/// NEDEN GÖRSEL: Instagram ve Facebook, URL şemasıyla METİN/BAĞLANTI kabul
/// etmiyor. `instagram://` ya da `sharer.php` açmak kullanıcıyı boş bir
/// uygulamaya götürüyordu — "gidiyor ama bir şey olmuyor" şikâyeti buydu.
/// Tek çalışan yol: içeriği bir GÖRSELE dönüştürüp işletim sisteminin
/// paylaşım sayfasına vermek. Instagram görseli "Hikayene Ekle / Akış"
/// seçenekleriyle kabul ediyor.
///
/// Tarif tarafında aynı yaklaşım zaten kullanılıyordu (recipe_story_share);
/// bu, tarif dışı içerikler için sadeleştirilmiş sürümü.
Future<void> showStoryShare(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String url,
  String emoji = "🍼",
  String imageUrl = "",
  String badge = "BabyBites",
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _StoryShareSheet(
      title: title,
      subtitle: subtitle,
      url: url,
      emoji: emoji,
      imageUrl: imageUrl,
      badge: badge,
    ),
  );
}

class _StoryShareSheet extends StatefulWidget {
  final String title, subtitle, url, emoji, imageUrl, badge;
  const _StoryShareSheet({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.emoji,
    required this.imageUrl,
    required this.badge,
  });

  @override
  State<_StoryShareSheet> createState() => _StoryShareSheetState();
}

class _StoryShareSheetState extends State<_StoryShareSheet> {
  static const _primary = Color(0xFFFF7A45);
  static const _text = Color(0xFF2D2D3A);
  static const _light = Color(0xFFA8A8B3);

  final _boundaryKey = GlobalKey();
  bool _story = true; // true: 9:16 hikaye, false: 1:1 gönderi
  bool _busy = false;
  bool _photoBlocked = false;

  bool get _hasPhoto => isPhotoUrl(widget.imageUrl) && !_photoBlocked;

  Future<Uint8List?> _capture() async {
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    // Bağlantıyı panoya da koy: kullanıcı görseli paylaştıktan sonra
    // açıklamaya yapıştırmak isteyebilir.
    await Clipboard.setData(ClipboardData(text: widget.url));
    await Future.delayed(const Duration(milliseconds: 150));

    var bytes = await _capture();
    // Fotoğraf CORS/yükleme yüzünden yakalanamadıysa degradeye düşüp yeniden dene.
    if (bytes == null && _hasPhoto) {
      setState(() => _photoBlocked = true);
      await Future.delayed(const Duration(milliseconds: 250));
      bytes = await _capture();
    }

    var ok = false;
    if (bytes != null) {
      // METİNSİZ paylaş: görselle birlikte URL gönderilince Instagram bunu
      // "bağlantı paylaş → DM" olarak yorumluyor ve hikaye seçeneği çıkmıyor.
      ok = await shareImageViaWebShareApi(bytes, filename: "babybites_${_story ? 'story' : 'post'}.png");
    }
    var linked = false;
    if (!ok) {
      linked = await shareViaWebShareApi(title: widget.badge, text: widget.title, url: widget.url);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text(_story
            ? "Hazır! Instagram'da \"Hikayene Ekle\"yi seç. 🎉"
            : "Hazır! Instagram'da \"Akış\"ı seç. 🎉"),
        duration: const Duration(seconds: 4),
      ));
    } else if (linked) {
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text("Paylaşım menüsü açıldı. Bağlantı panoya da kopyalandı."),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text("Paylaşım açılamadı. Bağlantı panoya kopyalandı."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - 80).clamp(180.0, 260.0);
    final cardH = _story ? cardW * 16 / 9 : cardW;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Text("Paylaşım Kartı 📤", style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 2),
            const Text("Görsel olarak paylaş — Instagram hikaye ve akışta çalışır.",
                textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: _light)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _formatTab("Hikaye", "9:16", true),
                const SizedBox(width: 8),
                _formatTab("Gönderi", "1:1", false),
              ],
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: _boundaryKey,
              child: SizedBox(width: cardW, height: cardH, child: _card()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.ios_share, size: 18),
                label: Text(_busy ? "Hazırlanıyor…" : "Paylaş",
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // HER ZAMAN ÇALIŞAN yedek yol: paylaşım sayfası Instagram'ı hedef
            // olarak göstermese bile kullanıcı görseli kaydedip bağlantıyı
            // kopyalayarak elle paylaşabilir.
            Row(
              children: [
                Expanded(child: _secondary(Icons.download_rounded, "Fotoğrafı Kaydet", _busy ? null : _save)),
                const SizedBox(width: 8),
                Expanded(child: _secondary(Icons.link, "Bağlantıyı Kopyala", _busy ? null : _copyLink)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Görseli cihaza kaydeder (web'de indirir).
  Future<void> _save() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 120));
    var bytes = await _capture();
    if (bytes == null && _hasPhoto) {
      setState(() => _photoBlocked = true);
      await Future.delayed(const Duration(milliseconds: 250));
      bytes = await _capture();
    }
    final ok = bytes != null && await saveImageToGallery(bytes, filename: "babybites_${_story ? 'story' : 'post'}.png");
    if (!mounted) return;
    setState(() => _busy = false);
    final why = lastShareError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? "Fotoğraf kaydedildi 📸 Instagram'ı açıp hikayene ekleyebilirsin."
          : "Kaydedilemedi${why == null ? "" : " ($why)"}."),
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Bağlantı kopyalandı 🔗"),
    ));
  }

  Widget _secondary(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: BorderSide(color: _primary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _formatTab(String label, String ratio, bool story) {
    final sel = _story == story;
    return GestureDetector(
      onTap: () => setState(() => _story = story),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? _primary : const Color(0xFFF3F3F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text("$label · $ratio",
            style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.bold, color: sel ? Colors.white : _text)),
      ),
    );
  }

  Widget _card() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A6C), _primary, Color(0xFFE85D2F)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasPhoto)
              Opacity(
                opacity: 0.30,
                child: photoOrFallback(widget.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.badge,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: _primary)),
                  ),
                  const Spacer(),
                  if (!_hasPhoto) Text(widget.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
                    ),
                  ),
                  if (widget.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, height: 1.3, color: Colors.white.withOpacity(0.92)),
                    ),
                  ],
                  const Spacer(),
                  Text("babybites.com.tr",
                      style: TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),
          ],
        ),
      );
}
