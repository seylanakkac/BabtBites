import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/food_database.dart';
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

  /// "Paylaş": önce hikaye görselini native paylaşım ekranıyla paylaşmayı dener;
  /// tarayıcı dosya paylaşımını desteklemiyorsa BAĞLANTIYI paylaşım ekranıyla açar
  /// (yine native menü çıkar); o da yoksa linki panoya kopyalar.
  Future<void> _share() async {
    setState(() => _busy = true);
    final r = widget.recipe;
    final url = recipeShareUrl(r);
    await Clipboard.setData(ClipboardData(text: url)); // her ihtimale karşı kopyala
    await Future.delayed(const Duration(milliseconds: 120));
    final bytes = await _capture();
    var sharedImage = false;
    if (bytes != null) {
      sharedImage = await shareImageViaWebShareApi(
        bytes,
        text: "${r.name} • BabyBites\n$url",
        filename: "babybites_${r.id}.png",
      );
    }
    var sharedLink = false;
    if (!sharedImage) {
      sharedLink = await shareViaWebShareApi(
        title: "BabyBites",
        text: "${r.name} • BabyBites",
        url: url,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (sharedImage) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Hazır! Hikayene ekleyebilirsin. 🎉"),
        duration: Duration(seconds: 3),
      ));
    } else if (sharedLink) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Paylaşım menüsü açıldı (bağlantı). Bağlantı panoya da kopyalandı."),
        duration: Duration(seconds: 3),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Tarayıcın paylaşımı desteklemiyor. Bağlantı panoya kopyalandı."),
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
                    onPressed: _busy ? null : _share,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.ios_share, size: 18, color: Colors.white),
                    label: const Text("Paylaş", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
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
    // Paylaşım/indirme görseli her zaman MARKALI DEGRADE arka plan kullanır.
    // Ağdan gelen tarif fotoğrafı (CORS) canvas'ı kirletip toImage()'i bozuyordu;
    // bu yüzden yakalama bütün tarayıcılarda güvenilir olsun diye degrade kullanılır.
    final bg = _gradientBg();

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
