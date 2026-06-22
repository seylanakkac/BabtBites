import 'package:flutter/material.dart';
import 'web_ads_stub.dart' if (dart.library.html) 'web_ads_web.dart' as impl;

/// Web'de AdSense görüntülü reklam render eder. Web olmayan platformda boş döner.
Widget adsenseAd({
  required String client,
  required String slot,
  required double width,
  required double height,
}) =>
    impl.adsenseAd(client: client, slot: slot, width: width, height: height);
