import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Web olmayan platformlarda Web Share API yok → her zaman false.
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) async => false;
Future<bool> shareImageViaWebShareApi(Uint8List bytes, {String text = '', String filename = 'babybites.png'}) async => false;

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
