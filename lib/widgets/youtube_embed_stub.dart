import 'package:flutter/material.dart';

/// Web olmayan platformda iframe yok → boş.
Widget youtubeEmbed(String url, {bool vertical = false}) => const SizedBox.shrink();
