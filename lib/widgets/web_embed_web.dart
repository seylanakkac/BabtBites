// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registered = {};

/// Web Share API ile bir GÖRSEL paylaşır (mobil tarayıcı → Instagram hikaye vb.).
/// Tarayıcı dosya paylaşımını desteklemiyorsa / vazgeçilirse false döner.
Future<bool> shareImageViaWebShareApi(Uint8List bytes, {String text = '', String filename = 'babybites.png'}) async {
  try {
    final nav = html.window.navigator;
    if (!js_util.hasProperty(nav, 'share')) return false;
    final blob = html.Blob(<Object>[bytes], 'image/png');
    final file = html.File(<Object>[blob], filename, {'type': 'image/png'});
    final data = js_util.newObject();
    js_util.setProperty(data, 'files', js_util.jsify(<dynamic>[file]));
    if (text.isNotEmpty) js_util.setProperty(data, 'text', text);
    // canShare({files}) desteklenmiyorsa (çoğu masaüstü) hiç deneme.
    if (js_util.hasProperty(nav, 'canShare')) {
      final ok = js_util.callMethod(nav, 'canShare', <dynamic>[data]);
      if (ok != true) return false;
    }
    await js_util.promiseToFuture(js_util.callMethod(nav, 'share', <dynamic>[data]));
    return true;
  } catch (_) {
    return false;
  }
}

/// Web'de bir PNG'yi dosya olarak indirir (masaüstü tarayıcılar paylaşımı
/// desteklemediğinde kullanıcı görseli indirip Instagram hikayesine yükleyebilir).
Future<bool> downloadImage(Uint8List bytes, {String filename = 'babybites.png'}) async {
  try {
    final blob = html.Blob(<Object>[bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (_) {
    return false;
  }
}

/// Web'de native paylaşım sayfasını (Web Share API) açar. Tarayıcı desteklemiyorsa
/// ya da kullanıcı vazgeçerse false döner (çağıran tarafta yedek davranış için).
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) async {
  try {
    final dynamic nav = html.window.navigator;
    // navigator.share yoksa (masaüstü tarayıcıların çoğu) doğrudan vazgeç.
    if (nav.share == null) return false;
    final data = <String, dynamic>{};
    if (title != null && title.isNotEmpty) data['title'] = title;
    if (text != null && text.isNotEmpty) data['text'] = text;
    if (url != null && url.isNotEmpty) data['url'] = url;
    await nav.share(data);
    return true;
  } catch (_) {
    return false;
  }
}

/// YouTube ID'sini çeşitli URL biçimlerinden çıkarır (zaten ID ise olduğu gibi).
String _ytId(String url) {
  final u = url.trim();
  final m = RegExp(r'(?:youtu\.be/|v=|embed/|shorts/)([A-Za-z0-9_-]{6,})').firstMatch(u);
  if (m != null) return m.group(1)!;
  return u;
}

/// Web'de YouTube iframe / HTML5 video gömer (HtmlElementView ile).
Widget mediaEmbed({required bool youtube, required String url, double aspectRatio = 16 / 9}) {
  final viewId = 'embed_${youtube ? 'yt' : 'v'}_${url.hashCode}';
  if (!_registered.contains(viewId)) {
    _registered.add(viewId);
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      if (youtube) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.youtube.com/embed/${_ytId(url)}'
          ..allow = 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '12px';
        return iframe;
      } else {
        final v = html.VideoElement()
          ..src = url
          ..controls = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '12px';
        return v;
      }
    });
  }
  return AspectRatio(aspectRatio: aspectRatio, child: HtmlElementView(viewType: viewId));
}
