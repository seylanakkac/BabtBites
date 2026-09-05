import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Video linkinin platformunu URL'den tanır: 'instagram' | 'tiktok' | 'other'.
String videoPlatform(String url) {
  final u = url.toLowerCase();
  if (u.contains('instagram.com') || u.contains('instagr.am')) return 'instagram';
  if (u.contains('tiktok.com') || u.contains('vt.tiktok') || u.contains('vm.tiktok')) {
    return 'tiktok';
  }
  return 'other';
}

/// YouTube DIŞI video linkleri (Instagram, TikTok, diğer) için dokunulabilir
/// kart. Dokununca video ilgili uygulamada (kurulu değilse tarayıcıda) açılır.
///
/// NEDEN GÖMME DEĞİL: Instagram ve TikTok, YouTube gibi serbest iframe gömme
/// sunmuyor (oEmbed/JS SDK kısıtlı, çoğu zaman engelli). Bu yüzden en sağlam
/// yöntem linki harici açmak — YouTube küçük-resim yaklaşımının kardeşi.
Widget videoLinkCard(String url) {
  final v = url.trim();
  if (v.isEmpty) return const SizedBox.shrink();
  final platform = videoPlatform(v);

  final Widget iconWidget;
  final String label;
  final List<Color> grad;
  switch (platform) {
    case 'instagram':
      iconWidget = const FaIcon(FontAwesomeIcons.instagram, size: 26, color: Color(0xFFDD2A7B));
      label = "Instagram'da izle";
      grad = const [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)];
      break;
    case 'tiktok':
      iconWidget = const FaIcon(FontAwesomeIcons.tiktok, size: 26, color: Color(0xFF010101));
      label = "TikTok'ta izle";
      grad = const [Color(0xFF010101), Color(0xFF69C9D0), Color(0xFFEE1D52)];
      break;
    default:
      iconWidget = const Icon(Icons.play_arrow_rounded, size: 32, color: Color(0xFFFF7A45));
      label = "Videoyu izle";
      grad = const [Color(0xFF2D2D3A), Color(0xFF4A4A5A)];
  }

  Future<void> open() async {
    try {
      final uri = Uri.parse(v.contains('://') ? v : 'https://$v');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  return GestureDetector(
    onTap: open,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(child: iconWidget),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Video tarif", style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.open_in_new, color: Colors.white, size: 20),
        ],
      ),
    ),
  );
}
