import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Instagram / Facebook / WhatsApp paylaşım düğmeleri.
///
/// Her platformun kabul ettiği yol farklı:
///   • WhatsApp  → wa.me metin + link (uygulama/web açılır)
///   • Facebook  → sharer.php YALNIZCA url alır (quote artık yok sayılıyor)
///   • Instagram → link paylaşımını desteklemiyor; bağlantı panoya kopyalanır
///                 ve Instagram açılır. Görsel paylaşımı isteniyorsa çağıran
///                 taraf [onInstagram] verip kendi paylaşım kartını açar.
class ShareButtons extends StatelessWidget {
  /// Paylaşılacak metin (başlık/özet). Link ayrı gönderilir.
  final String text;

  /// Paylaşılacak bağlantı.
  final String url;

  /// Verilirse Instagram düğmesi bunu çağırır (ör. görsel paylaşım kartı).
  final VoidCallback? onInstagram;

  final double size;

  const ShareButtons({
    super.key,
    required this.text,
    required this.url,
    this.onInstagram,
    this.size = 30,
  });

  static Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _whatsapp() =>
      _open(Uri.parse("https://wa.me/?text=${Uri.encodeComponent('$text\n$url')}"));

  Future<void> _facebook() =>
      _open(Uri.parse("https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}"));

  Future<void> _instagram(BuildContext context) async {
    if (onInstagram != null) {
      onInstagram!();
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Bağlantı kopyalandı. Instagram'da profiline veya hikayene ekleyebilirsin."),
        duration: Duration(seconds: 3),
      ));
    }
    await _open(Uri.parse("https://www.instagram.com"));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(FontAwesomeIcons.instagram, const Color(0xFFE1306C), () => _instagram(context), "Instagram"),
        const SizedBox(width: 8),
        _btn(FontAwesomeIcons.facebookF, const Color(0xFF1877F2), _facebook, "Facebook"),
        const SizedBox(width: 8),
        _btn(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), _whatsapp, "WhatsApp"),
      ],
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap, String tooltip) => Tooltip(
        message: "$tooltip'ta paylaş",
        child: GestureDetector(
          // Kart tıklamasının altındaki "aç" hareketini tetiklememesi için
          // opaque: dokunma burada tüketilir.
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: size * 0.52, color: color),
          ),
        ),
      );
}
