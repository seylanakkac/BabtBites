// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registered = {};

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
