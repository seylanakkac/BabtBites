import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'story_share_sheet.dart';
import 'web_embed.dart';

/// Paylaşım düğmeleri.
///
/// ⚠️ NEDEN ARTIK AYRI FACEBOOK DÜĞMESİ YOK:
/// Instagram ve Facebook bir URL şemasıyla metin/bağlantı ALMIYOR. Eskiden bu
/// widget `instagram.com` ve `facebook.com/sharer/sharer.php` açıyordu;
/// kullanıcı uygulamaya düşüyor ama paylaşacak bir şey olmuyordu ("gidiyor,
/// eylem yok"). Yalnızca WhatsApp çalışıyordu, çünkü `wa.me` gerçekten `text`
/// parametresi kabul ediyor.
///
/// Çalışan iki yol var, ikisi de burada:
///   • GÖRSEL paylaşımı → işletim sisteminin paylaşım sayfası. Instagram
///     görseli kabul eder ("Hikayene Ekle / Akış"). [showStoryShare] içeriği
///     markalı bir karta dönüştürür.
///   • METİN + BAĞLANTI → yine sistem paylaşım sayfası; Facebook, Mesajlar,
///     Mail, X, "Bağlantıyı Kopyala" hepsi orada ve hepsi çalışır.
///
/// Düğmeler: Instagram (görsel kart) · WhatsApp (doğrudan) · Paylaş (sistem).
/// Her düğme gerçekten bir iş yapıyor.
class ShareButtons extends StatelessWidget {
  /// Paylaşılacak başlık/özet metni.
  final String text;

  /// Paylaşılacak bağlantı.
  final String url;

  /// Görsel kartta gösterilecek alt satır (isteğe bağlı).
  final String subtitle;

  /// Görsel kartın arka planı (isteğe bağlı fotoğraf).
  final String imageUrl;

  /// Fotoğraf yoksa kartta görünecek emoji.
  final String emoji;

  /// Verilirse Instagram düğmesi varsayılan kart yerine bunu çağırır
  /// (ör. tarifin kendi paylaşım kartı).
  final VoidCallback? onInstagram;

  final double size;

  const ShareButtons({
    super.key,
    required this.text,
    required this.url,
    this.subtitle = "",
    this.imageUrl = "",
    this.emoji = "🍼",
    this.onInstagram,
    this.size = 30,
  });

  Future<void> _whatsapp() async {
    // wa.me metin parametresini gerçekten destekliyor — doğrudan kişi seçimine
    // gider, sistem sayfasına uğramaya gerek yok.
    final uri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent('$text\n$url')}");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _system(BuildContext context) async {
    final ok = await shareViaWebShareApi(title: "BabyBites", text: text, url: url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Paylaşım menüsü açılamadı."),
      ));
    }
  }

  void _instagram(BuildContext context) {
    if (onInstagram != null) {
      onInstagram!();
      return;
    }
    showStoryShare(
      context,
      title: text,
      subtitle: subtitle,
      url: url,
      emoji: emoji,
      imageUrl: imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(FontAwesomeIcons.instagram, const Color(0xFFE1306C), () => _instagram(context), "Instagram'da paylaş (görsel kart)"),
        const SizedBox(width: 8),
        _btn(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), _whatsapp, "WhatsApp'ta paylaş"),
        const SizedBox(width: 8),
        // Facebook dahil diğer her yer buradan: sistem paylaşım sayfası.
        _btn(Icons.ios_share, const Color(0xFF5A5A6A), () => _system(context), "Diğer (Facebook, Mesajlar, Mail…)"),
      ],
    );
  }

  Widget _btn(IconData icon, Color color, VoidCallback onTap, String tooltip) => Tooltip(
        message: tooltip,
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
