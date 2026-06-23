import 'package:flutter/material.dart';
import 'youtube_embed_stub.dart' if (dart.library.html) 'youtube_embed_web.dart' as impl;

/// YouTube oynatıcı (web'de iframe). Geçersiz/boş linkte boş döner.
/// [vertical] true ise (veya link Shorts ise) 9:16 dikey gösterilir.
Widget youtubeEmbed(String url, {bool vertical = false}) =>
    impl.youtubeEmbed(url, vertical: vertical);
