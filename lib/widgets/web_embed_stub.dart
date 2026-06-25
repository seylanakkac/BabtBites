import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobil (Android/iOS): metin/link paylaşımı native paylaşım sayfasıyla.
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) async {
  try {
    final msg = [text, url].where((e) => e != null && e.isNotEmpty).join('\n');
    if (msg.isEmpty) return false;
    await Share.share(msg, subject: title);
    return true;
  } catch (_) {
    return false;
  }
}

/// Mobil (Android/iOS): görseli (PNG byte'ları) native paylaşım sayfası ile
/// paylaşır (Instagram, WhatsApp vb.). Geçici dosyaya yazıp paylaşır.
Future<bool> shareImageViaWebShareApi(Uint8List bytes,
    {String text = '', String filename = 'babybites.png'}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: text);
    return true;
  } catch (_) {
    return false;
  }
}

/// Web olmayan platformlar için yer-tutucu (mobil derlemede gerçek oynatıcı
/// ileride video_player/youtube_player ile eklenebilir).
Widget mediaEmbed({required bool youtube, required String url, double aspectRatio = 16 / 9}) {
  return AspectRatio(
    aspectRatio: aspectRatio,
    child: Container(
      decoration: BoxDecoration(color: const Color(0xFFEDEDF0), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(youtube ? Icons.smart_display_outlined : Icons.movie_outlined, size: 34, color: Colors.black.withOpacity(0.35)),
          const SizedBox(height: 6),
          const Text("Video", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF8E8E9F))),
        ],
      ),
    ),
  );
}
