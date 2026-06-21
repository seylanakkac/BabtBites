// Logodan web favicon + PWA ikonlarini uretir.
// Calistir: D:/flutter_sdk/flutter/bin/dart run tool/gen_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeImage(File('assets/images/logo.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('logo.png decode edilemedi');
    exit(1);
  }
  img.Image fit(int size) {
    // Logoyu kareye sigdir (oranini koru, seffaf arka plan).
    final resized = img.copyResize(
      src,
      width: src.width >= src.height ? size : null,
      height: src.height > src.width ? size : null,
      interpolation: img.Interpolation.cubic,
    );
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    // Seffaf doldur.
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
    final dx = ((size - resized.width) / 2).round();
    final dy = ((size - resized.height) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
    return canvas;
  }

  void write(String path, int size) {
    File(path).writeAsBytesSync(img.encodePng(fit(size)));
    stdout.writeln('yazildi: $path (${size}x$size)');
  }

  write('web/favicon.png', 64);
  write('web/icons/Icon-192.png', 192);
  write('web/icons/Icon-512.png', 512);
  write('web/icons/Icon-maskable-192.png', 192);
  write('web/icons/Icon-maskable-512.png', 512);
}
