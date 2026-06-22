// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

bool _scriptInjected = false;
final Set<String> _registered = {};

/// AdSense yükleyici script'ini bir kez ekler (client param'ıyla).
void _ensureScript(String client) {
  if (_scriptInjected || client.isEmpty) return;
  _scriptInjected = true;
  // index.html zaten yüklüyorsa tekrar ekleme (çift adsbygoogle.js hata verir).
  final existing = html.document.querySelectorAll('script[src*="adsbygoogle.js"]');
  if (existing.isNotEmpty) return;
  final s = html.ScriptElement()
    ..async = true
    ..src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$client'
    ..crossOrigin = 'anonymous';
  html.document.head?.append(s);
}

void _pushAd() {
  try {
    var arr = js_util.getProperty(html.window, 'adsbygoogle');
    if (arr == null) {
      js_util.setProperty(html.window, 'adsbygoogle', js_util.jsify(<dynamic>[]));
      arr = js_util.getProperty(html.window, 'adsbygoogle');
    }
    js_util.callMethod(arr, 'push', <dynamic>[js_util.newObject()]);
  } catch (_) {}
}

Widget adsenseAd({
  required String client,
  required String slot,
  required double width,
  required double height,
}) {
  if (client.isEmpty || slot.isEmpty) return const SizedBox.shrink();
  _ensureScript(client);
  final viewId = 'adsense_${slot}_${width.toInt()}x${height.toInt()}';
  if (!_registered.contains(viewId)) {
    _registered.add(viewId);
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final ins = html.Element.tag('ins')
        ..className = 'adsbygoogle'
        ..style.display = 'block'
        ..style.width = '${width}px'
        ..style.height = '${height}px'
        ..setAttribute('data-ad-client', client)
        ..setAttribute('data-ad-slot', slot);
      final wrapper = html.DivElement()
        ..style.width = '${width}px'
        ..style.height = '${height}px'
        ..style.overflow = 'hidden'
        ..append(ins);
      // Element DOM'a girdikten sonra reklamı tetikle.
      html.window.requestAnimationFrame((_) => _pushAd());
      return wrapper;
    });
  }
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}
