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
const _text = Color(0xFF2D2D3A);

/// Paylaşım biçimi. Instagram hikayesi 9:16, akış gönderisi 1:1 ister; yanlış
/// orandaki görsel kırpılıyor veya kenarları boş kalıyordu.
enum ShareFormat { story, post }

/// Tarif paylaşım kartı: tarif fotoğrafı + adı. Hikaye (9:16) veya gönderi
/// (1:1) olarak paylaşılır; paylaşım menüsünden Instagram seçilebilir.
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
  ShareFormat _format = ShareFormat.story;

  /// Web'de ağdan gelen tarif fotoğrafı canvas'ı "kirletiyor" (CORS) ve
  /// toImage() patlıyor. Yakalama başarısız olursa fotoğrafsız (markalı
  /// degrade) karta düşüp tekrar deniyoruz — böylece native'de gerçek fotoğraf
  /// görünür, web'de de paylaşım hiç çalışmamaktansa degradeyle çalışır.
  bool _photoBlocked = false;

  bool get _hasPhoto => !_photoBlocked && isPhotoUrl(widget.recipe.imageUrl);

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
    final r = widget.recipe;
    final url = recipeShareUrl(r);
    await Clipboard.setData(ClipboardData(text: url)); // her ihtimale karşı
    await Future.delayed(const Duration(milliseconds: 150));

    var bytes = await _capture();
    // Fotoğraflı kart yakalanamadıysa (web/CORS) degradeye düşüp tekrar dene.
    if (bytes == null && _hasPhoto) {
      setState(() => _photoBlocked = true);
      await Future.delayed(const Duration(milliseconds: 250));
      bytes = await _capture();
    }

    var sharedImage = false;
    if (bytes != null) {
      // Görseli METİNSİZ paylaş: görselle birlikte URL gidince Instagram bunu
      // "bağlantı paylaş → DM" olarak yorumluyor. Sadece görsel → Instagram
      // "Hikayene Ekle / Akış / DM" seçeneklerini sunar.
      sharedImage = await shareImageViaWebShareApi(
        bytes,
        filename: "babybites_${r.id}_${_format == ShareFormat.story ? 'story' : 'post'}.png",
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_format == ShareFormat.story
            ? "Hazır! Instagram'da \"Hikayene Ekle\"yi seç. 🎉"
            : "Hazır! Instagram'da \"Akış\"ı seç. 🎉"),
        duration: const Duration(seconds: 4),
      ));
    } else if (sharedLink) {
      // Görsel paylaşımı başarısız olup bağlantıya düştük. SEBEBİ GÖSTER:
      // sessizce düşmek, "Instagram'a gitmiyor" şikâyetinin teşhisini
      // imkânsız kılıyordu.
      Navigator.pop(context);
      final why = lastShareError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(why == null
            ? "Görsel paylaşılamadı; bağlantı menüsü açıldı."
            : "Görsel paylaşılamadı ($why). Bağlantı menüsü açıldı."),
        duration: const Duration(seconds: 6),
      ));
    } else {
      final why = lastShareError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(why == null
            ? "Paylaşım açılamadı. Bağlantı panoya kopyalandı."
            : "Paylaşım açılamadı ($why). Bağlantı panoya kopyalandı."),
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: recipeShareUrl(widget.recipe)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Bağlantı kopyalandı."),
      duration: Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ratio = _format == ShareFormat.story ? 16 / 9 : 1.0; // yükseklik/genişlik
    final maxH = media.size.height * 0.56;
    double w = media.size.width * 0.74;
    if (w * ratio > maxH) w = maxH / ratio;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _formatPicker(w),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _boundaryKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: w,
                  height: w * ratio,
                  child: _shareCard(widget.recipe),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: w,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _copyLink,
                icon: const Icon(Icons.link, size: 18, color: Colors.white),
                label: const Text("Bağlantıyı Kopyala",
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
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
                      child: const Text("Kapat",
                          style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontWeight: FontWeight.w600)),
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
                      label: Text(_format == ShareFormat.story ? "Hikayede Paylaş" : "Gönderi Olarak Paylaş",
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
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
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: w,
                child: const Text(
                  "Masaüstü tarayıcıda paylaşım menüsü açılmayabilir; bağlantı panoya kopyalanır.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white54, height: 1.35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hikaye / Gönderi seçimi.
  Widget _formatPicker(double w) => SizedBox(
        width: w,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              _formatTab("Hikaye", "9:16", ShareFormat.story),
              _formatTab("Gönderi", "1:1", ShareFormat.post),
            ],
          ),
        ),
      );

  Widget _formatTab(String label, String ratio, ShareFormat f) {
    final sel = _format == f;
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : () => setState(() => _format = f),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text("$label · $ratio",
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : _text)),
        ),
      ),
    );
  }

  Widget _shareCard(Recipe recipe) {
    final isStory = _format == ShareFormat.story;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Arka plan: tarif fotoğrafı (varsa), yoksa markalı degrade.
        if (_hasPhoto)
          photoOrFallback(recipe.imageUrl, fallback: _gradientBg(), fit: BoxFit.cover)
        else
          _gradientBg(),
        // Okunabilirlik için koyu degrade.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.38), Colors.transparent, Colors.black.withOpacity(0.80)],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
        ),
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
              const Text("BabyBites",
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
            ],
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: isStory ? 20 : 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
                child: Text("${recipe.startingMonth}+ ay • ${recipe.prepTime}",
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              Text(recipe.name,
                  maxLines: isStory ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isStory ? 26 : 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)])),
              if (recipe.author.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text("Hazırlayan: ${recipe.author}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
              ],
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text("Tarifin tamamı: babybites.com.tr",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 6)])),
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
