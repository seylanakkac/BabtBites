// AdSense (web) — package:web + dart:js_interop.
//
// NEDEN dart:html DEĞİL: Dart 3.12'de `dart:js_util` KALDIRILDI ve `dart:html`
// kullanımdan kaldırıldı. Flutter 3.44'e yükseltirken bu dosya derlenmiyordu.
// package:web tipleri doğrudan JSObject tabanlı olduğu için interop
// çağrıları ek köprü gerektirmiyor.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

bool _scriptInjected = false;
final Set<String> _registered = {};

/// AdSense yükleyici script'ini bir kez ekler (client param'ıyla).
void _ensureScript(String client) {
  if (_scriptInjected || client.isEmpty) return;
  _scriptInjected = true;
  // index.html zaten yüklüyorsa tekrar ekleme (çift adsbygoogle.js hata verir).
  final existing = web.document.querySelectorAll('script[src*="adsbygoogle.js"]');
  if (existing.length > 0) return;
  final s = web.document.createElement('script') as web.HTMLScriptElement
    ..async = true
    ..src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$client'
    ..crossOrigin = 'anonymous';
  web.document.head?.append(s);
}

void _pushAd() {
  try {
    // window.adsbygoogle dizisi yoksa oluştur, sonra boş bir nesne push et —
    // AdSense'in beklediği tetikleme biçimi bu.
    if (!web.window.has('adsbygoogle')) {
      web.window.setProperty('adsbygoogle'.toJS, JSArray<JSAny>());
    }
    final arr = web.window.getProperty('adsbygoogle'.toJS) as JSObject?;
    arr?.callMethod('push'.toJS, JSObject());
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
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final ins = web.document.createElement('ins') as web.HTMLElement
        ..className = 'adsbygoogle';
      ins.style.display = 'block';
      ins.style.width = '${width}px';
      ins.style.height = '${height}px';
      ins.setAttribute('data-ad-client', client);
      ins.setAttribute('data-ad-slot', slot);

      final wrapper = web.document.createElement('div') as web.HTMLDivElement;
      wrapper.style.width = '${width}px';
      wrapper.style.height = '${height}px';
      wrapper.style.overflow = 'hidden';
      wrapper.append(ins);

      // Element DOM'a girdikten sonra reklamı tetikle.
      web.window.requestAnimationFrame(((JSNumber _) {
        _pushAd();
      }).toJS);
      return wrapper;
    });
  }
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}
