// Android launcher ikonu kaynak görselleri (logo taşmasını önlemek için dolgulu):
//  - assets/images/logo_adaptive.png : şeffaf 1024 zemin, logo ~%58 ortalı (adaptive foreground)
//  - assets/images/logo_launcher.png : turuncu (#FF7A45) zemin + logo ~%58 ortalı (legacy)
// Çalıştır: D:/flutter_sdk/flutter/bin/dart run tool/gen_launcher_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final logo = img.decodeImage(File('assets/images/logo.png').readAsBytesSync());
  if (logo == null) {
    stderr.writeln('logo.png decode edilemedi');
    exit(1);
  }
  const size = 1024;
  const box = 600; // adaptive güvenli alan içinde kalsın
  final scale = box / (logo.width > logo.height ? logo.width : logo.height);
  final lw = (logo.width * scale).round();
  final lh = (logo.height * scale).round();
  final resized = img.copyResize(logo, width: lw, height: lh, interpolation: img.Interpolation.cubic);
  final dx = ((size - lw) / 2).round();
  final dy = ((size - lh) / 2).round();

  // Şeffaf foreground
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(fg, resized, dstX: dx, dstY: dy);
  File('assets/images/logo_adaptive.png').writeAsBytesSync(img.encodePng(fg));

  // Turuncu legacy
  final bg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(bg, color: img.ColorRgb8(0xFF, 0x7A, 0x45));
  img.compositeImage(bg, resized, dstX: dx, dstY: dy);
  File('assets/images/logo_launcher.png').writeAsBytesSync(img.encodePng(bg));

  stdout.writeln('Üretildi: logo_adaptive.png + logo_launcher.png');
}
