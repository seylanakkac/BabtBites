import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'youtube_util.dart';

/// Native (iOS/Android) YouTube oynatıcı.
///
/// Web'de iframe kullanılıyor; native'de iframe yok. Bu dosya eskiden
/// `SizedBox.shrink()` döndürüyordu, yani TELEFONLARDA VİDEOLU TARİFLERDE
/// HİÇBİR ŞEY GÖRÜNMÜYORDU — "videolu tarif açılmıyor" şikâyetinin sebebi buydu.
///
/// Artık YouTube küçük resmi + oynat düğmesi gösterilir; dokununca video
/// YouTube uygulamasında (yoksa tarayıcıda) açılır. Makalelerde zaten
/// kullanılan ve çalışan yaklaşımın aynısı (bkz. web_embed_stub.mediaEmbed).
Widget youtubeEmbed(String url, {bool vertical = false}) {
  final id = youtubeId(url);
  if (id == null) return const SizedBox.shrink();
  final isVertical = vertical || isShorts(url);

  Future<void> open() async {
    // https adresi yeterli: hem iOS hem Android'de evrensel bağlantı (app
    // link) sayesinde YouTube uygulaması kuruluysa o açılır, değilse tarayıcı.
    // `youtube://` şemasını denemek iOS'ta Info.plist'e
    // LSApplicationQueriesSchemes eklemeyi gerektirir ve ek fayda sağlamaz.
    try {
      await launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=$id'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  return AspectRatio(
    aspectRatio: isVertical ? 9 / 16 : 16 / 9,
    child: GestureDetector(
      onTap: open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$id/hqdefault.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1C1C28)),
            ),
            Container(color: Colors.black.withOpacity(0.28)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 34, color: Color(0xFFFF7A45)),
                  ),
                  const SizedBox(height: 8),
                  const Text("Videoyu İzle",
                      style: TextStyle(
                          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
