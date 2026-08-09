// Web'e özgü paylaşım / indirme / gömme — package:web + dart:js_interop.
//
// NEDEN dart:html DEĞİL: Dart 3.12'de `dart:js_util` KALDIRILDI ve `dart:html`
// kullanımdan kaldırıldı. Flutter 3.44'e yükseltirken bu dosya derlenmiyordu.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = {};

/// Mobil sürümle aynı API yüzeyi (bkz. web_embed_stub.dart). Koşullu import'un
/// iki tarafı da aynı adları sunmak zorunda.
String? lastShareError;

/// Bayt dizisinden PNG Blob'u üretir.
web.Blob _pngBlob(Uint8List bytes) => web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );

/// Web Share API ile bir GÖRSEL paylaşır (mobil tarayıcı → Instagram hikaye vb.).
/// Tarayıcı dosya paylaşımını desteklemiyorsa / vazgeçilirse false döner.
Future<bool> shareImageViaWebShareApi(Uint8List bytes,
    {String text = '', String filename = 'babybites.png'}) async {
  try {
    final nav = web.window.navigator as JSObject;
    if (!nav.has('share')) return false;

    final file = web.File(
      <JSUint8Array>[bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: 'image/png'),
    );
    final data = JSObject();
    data.setProperty('files'.toJS, <web.File>[file].toJS);
    if (text.isNotEmpty) data.setProperty('text'.toJS, text.toJS);

    // canShare({files}) desteklenmiyorsa (çoğu masaüstü) hiç deneme.
    if (nav.has('canShare')) {
      final ok = nav.callMethod<JSBoolean>('canShare'.toJS, data);
      if (!ok.toDart) return false;
    }
    await nav.callMethod<JSPromise<JSAny?>>('share'.toJS, data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Web'de "galeriye kaydet" yok; indirme aynı işi görür.
Future<bool> saveImageToGallery(Uint8List bytes, {String filename = 'babybites.png'}) =>
    downloadImage(bytes, filename: filename);

/// Web'de bir PNG'yi dosya olarak indirir (masaüstü tarayıcılar paylaşımı
/// desteklemediğinde kullanıcı görseli indirip Instagram hikayesine yükleyebilir).
Future<bool> downloadImage(Uint8List bytes, {String filename = 'babybites.png'}) async {
  try {
    final url = web.URL.createObjectURL(_pngBlob(bytes));
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (_) {
    return false;
  }
}

/// Web'de native paylaşım sayfasını (Web Share API) açar. Tarayıcı desteklemiyorsa
/// ya da kullanıcı vazgeçerse false döner (çağıran tarafta yedek davranış için).
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) async {
  try {
    final nav = web.window.navigator as JSObject;
    // navigator.share yoksa (masaüstü tarayıcıların çoğu) doğrudan vazgeç.
    if (!nav.has('share')) return false;
    final data = JSObject();
    if (title != null && title.isNotEmpty) data.setProperty('title'.toJS, title.toJS);
    if (text != null && text.isNotEmpty) data.setProperty('text'.toJS, text.toJS);
    if (url != null && url.isNotEmpty) data.setProperty('url'.toJS, url.toJS);
    await nav.callMethod<JSPromise<JSAny?>>('share'.toJS, data).toDart;
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
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      if (youtube) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
          ..src = 'https://www.youtube.com/embed/${_ytId(url)}'
          ..allow = 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.borderRadius = '12px';
        return iframe;
      } else {
        final v = web.document.createElement('video') as web.HTMLVideoElement
          ..src = url
          ..controls = true;
        v.style.width = '100%';
        v.style.height = '100%';
        v.style.borderRadius = '12px';
        return v;
      }
    });
  }
  return AspectRatio(aspectRatio: aspectRatio, child: HtmlElementView(viewType: viewId));
}
