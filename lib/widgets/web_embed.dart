import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'web_embed_stub.dart' if (dart.library.html) 'web_embed_web.dart' as impl;

/// Yazı içine gömülü YouTube/video. Web'de gerçek iframe/video; diğer
/// platformlarda yer-tutucu. [youtube] true → YouTube, false → mp4 video URL'i.
Widget mediaEmbed({required bool youtube, required String url, double aspectRatio = 16 / 9}) =>
    impl.mediaEmbed(youtube: youtube, url: url, aspectRatio: aspectRatio);

/// Web'de native paylaşım sayfasını (Web Share API) açar. Başarılı olursa true,
/// desteklenmiyorsa / web değilse / kullanıcı vazgeçerse false döner.
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) =>
    impl.shareViaWebShareApi(title: title, text: text, url: url);

/// Web'de bir görseli (PNG byte'ları) native paylaşım sayfası ile paylaşır.
Future<bool> shareImageViaWebShareApi(Uint8List bytes, {String text = '', String filename = 'babybites.png'}) =>
    impl.shareImageViaWebShareApi(bytes, text: text, filename: filename);
