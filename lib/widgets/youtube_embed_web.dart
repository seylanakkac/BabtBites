// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'youtube_util.dart';

final Set<String> _registered = {};

/// YouTube videosunu iframe ile gömer. Dikey (Shorts) için 9:16, aksi 16:9.
Widget youtubeEmbed(String url, {bool vertical = false}) {
  final id = youtubeId(url);
  if (id == null) return const SizedBox.shrink();
  final vert = vertical || isShorts(url);
  final viewId = 'yt_${id}_${vert ? 'v' : 'h'}';
  if (!_registered.contains(viewId)) {
    _registered.add(viewId);
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$id?rel=0&modestbranding=1&playsinline=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute('loading', 'lazy')
        ..setAttribute('allow', 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen');
      return iframe;
    });
  }
  return Center(
    child: ConstrainedBox(
      // Dikey videoyu çok büyütme; yatayı tam genişlik.
      constraints: BoxConstraints(maxWidth: vert ? 320 : 640),
      child: AspectRatio(
        aspectRatio: vert ? 9 / 16 : 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: HtmlElementView(viewType: viewId),
        ),
      ),
    ),
  );
}
