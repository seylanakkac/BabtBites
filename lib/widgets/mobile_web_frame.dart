import 'package:flutter/material.dart';

/// Eskiden masaüstü web'de simüle bir telefon çerçevesi çiziyordu. Artık web
/// gerçek bir responsive web sitesi gibi göründüğü için çerçeve kaldırıldı;
/// bu sarmalayıcı geriye-uyumluluk için pass-through olarak korunuyor.
/// Responsive düzen artık her ekranın kendi içinde (ör. HomeScreen yan menüsü).
class MobileWebFrame extends StatelessWidget {
  final Widget child;
  const MobileWebFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
