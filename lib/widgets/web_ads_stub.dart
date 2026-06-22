import 'package:flutter/material.dart';

/// Web olmayan platformlarda AdSense yok → boş.
Widget adsenseAd({
  required String client,
  required String slot,
  required double width,
  required double height,
}) =>
    const SizedBox.shrink();
