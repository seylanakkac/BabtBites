import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/food_database.dart';
import 'image_helpers.dart';
import 'web_embed.dart';

const _primary = Color(0xFFFF7A45);
const _danger = Color(0xFFFF4D6A);

/// Tarif için Instagram hikayesi (9:16) paylaşımı: önizleme kartı + "Paylaş".
/// Web Share API ile görseli paylaşır (mobil), linki de panoya kopyalar.
Future<void> showRecipeStoryShare(BuildContext context, Recipe recipe) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _StoryShareDialog(recipe: recipe),
  );
}

String recipeShareUrl(Recipe recipe) => "https://babybites.com.tr/#/r/${recipe.id}";

class _StoryShareDialog extends StatefulWidget {
  final Recipe recipe;
  const _StoryShareDialog({required this.recipe});

  @override
  State<_StoryShareDialog> createState() => _StoryShareDialogState();
}

class _StoryShareDialogState extends State<_StoryShareDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Hikaye için yüksek çözünürlük.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final r = widget.recipe;
    final url = recipeShareUrl(r);
    // Linki panoya kopyala (kullanıcı hikayede link sticker olarak ekleyebilir).
    await Clipboard.setData(ClipboardData(text: url));
    // Görseli yakalamadan önce bir kare bekle (ağ görseli yerleşsin).
    await Future.delayed(const Duration(milliseconds: 120));
    final bytes = await _capture();
    var shared = false;
    if (bytes != null) {
      shared = await shareImageViaWebShareApi(
        bytes,
        text: "${r.name} • BabyBites\n$url",
        filename: "babybites_${r.id}.png",
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (shared) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Hikayene ekleyebilirsin! Link panoya kopyalandı (link sticker olarak yapıştırabilirsin)."),
        duration: Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Bu tarayıcı görsel paylaşımını desteklemiyor. Link panoya kopyalandı."),
        duration: Duration(seconds: 4),
      ));
    }
  }

  /// Bağlantıyı panoya kopyalar (her platformda çalışır).
  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: recipeShareUrl(widget.recipe)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Bağlantı kopyalandı. Hikayene 'bağlantı' çıkartması olarak ekleyebilirsin."),
      duration: Duration(seconds: 3),
    ));
  }

  /// Web: hikaye görselini (9:16 PNG) indirir; kullanıcı Instagram hikayesine
  /// galeriden yükleyebilir. Bağlantıyı da panoya kopyalar.
  Future<void> _download() async {
    setState(() => _busy = true);
    final r = widget.recipe;
    await Clipboard.setData(ClipboardData(text: recipeShareUrl(r)));
    await Future.delayed(const Duration(milliseconds: 120));
    final bytes = await _capture();
    var ok = false;
    if (bytes != null) ok = await downloadImage(bytes, filename: "babybites_${r.id}.png");
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? "Görsel indirildi 📥 Instagram > Hikaye > galeriden bu görseli seç. Bağlantı da kopyalandı."
          : "Görsel oluşturulamadı. Bağlantı panoya kopyalandı."),
      duration: const Duration(seconds: 5),
    ));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Kart 9:16; ekrana sığacak şekilde ölçekle.
    final maxH = media.size.height * 0.62;
    double w = media.size.width * 0.74;
    if (w * 16 / 9 > maxH) w = maxH * 9 / 16;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: w,
                height: w * 16 / 9,
                child: _storyCard(widget.recipe),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Bağlantıyı Kopyala (her zaman görünür).
          SizedBox(
            width: w,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _copyLink,
              icon: const Icon(Icons.link, size: 18, color: Colors.white),
              label: const Text("Bağlantıyı Kopyala", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: w,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Kapat", style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : (kIsWeb ? _download : _share),
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(kIsWeb ? Icons.download_rounded : Icons.ios_share, size: 18, color: Colors.white),
                    label: const Text(kIsWeb ? "Görseli İndir" : "Instagram'da Paylaş", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyCard(Recipe recipe) {
    final hasPhoto = isPhotoUrl(recipe.imageUrl);
    final bg = hasPhoto
        ? photoOrFallback(recipe.imageUrl, fallback: _gradientBg(), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
        : _gradientBg();

    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        // Okunabilirlik için koyu degrade.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.35), Colors.transparent, Colors.black.withOpacity(0.78)],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
        // Üst: logo + marka.
        Positioned(
          top: 16,
          left: 16,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/logo.png', width: 34, height: 34, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 34, height: 34)),
              ),
              const SizedBox(width: 8),
              const Text("BabyBites", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
            ],
          ),
        ),
        // Alt: tarif bilgisi.
        Positioned(
          left: 18,
          right: 18,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
                child: Text("${recipe.startingMonth}+ ay • ${recipe.prepTime}",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              Text(recipe.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 26, height: 1.1, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 8)])),
              const SizedBox(height: 8),
              if (recipe.author.trim().isNotEmpty)
                Text("Hazırlayan: ${recipe.author}",
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text("Tarifin tamamı: babybites.com.tr",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primary, _danger]),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_menu, size: 90, color: Colors.white30),
      );
}
