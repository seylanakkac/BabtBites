import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Hafif analitik sarmalayıcı. Firebase Analytics (GA4 mülkü G-TK00D3LFH1)
/// üzerine yazar; başarısız olursa sessizce yutar — uygulamayı asla bloklamaz.
/// init() yalnızca Firebase hazırsa main.dart'tan çağrılır.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  FirebaseAnalytics? _fa;

  /// Auto screen-view için MaterialApp.navigatorObservers'a eklenir (hazırsa).
  FirebaseAnalytics? get raw => _fa;

  void init() {
    try {
      _fa = FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('Analytics init failed: $e');
      _fa = null;
    }
  }

  void log(String name, [Map<String, Object>? params]) {
    final fa = _fa;
    if (fa == null) return;
    try {
      fa.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  void screen(String name) {
    final fa = _fa;
    if (fa == null) return;
    try {
      fa.logScreenView(screenName: name);
    } catch (_) {}
  }
}
