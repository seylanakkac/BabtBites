import 'package:flutter/material.dart';
import 'web_embed_stub.dart' if (dart.library.html) 'web_embed_web.dart' as impl;

/// Yazı içine gömülü YouTube/video. Web'de gerçek iframe/video; diğer
/// platformlarda yer-tutucu. [youtube] true → YouTube, false → mp4 video URL'i.
Widget mediaEmbed({required bool youtube, required String url, double aspectRatio = 16 / 9}) =>
    impl.mediaEmbed(youtube: youtube, url: url, aspectRatio: aspectRatio);
