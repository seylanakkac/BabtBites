import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class MobileWebFrame extends StatelessWidget {
  final Widget child;
  const MobileWebFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // The admin panel is a full-width professional area — never phone-framed.
    // Listen reactively so logging in/out as admin flips the frame at runtime.
    return ValueListenableBuilder<bool>(
      valueListenable: adminModeNotifier,
      builder: (context, isAdmin, _) => isAdmin ? child : _framed(context),
    );
  }

  Widget _framed(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Show simulated phone frame on desktop screen sizes
        final isWebOrDesktop = kIsWeb ||
            Theme.of(context).platform == TargetPlatform.windows || 
            Theme.of(context).platform == TargetPlatform.macOS || 
            Theme.of(context).platform == TargetPlatform.linux;
            
        final showFrame = isWebOrDesktop && constraints.maxWidth > 500;

        if (!showFrame) {
          return child;
        }

        const deviceWidth = 375.0;
        const deviceHeight = 812.0;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF9F6), // Warm cream desktop background
          body: Center(
            child: Container(
              width: deviceWidth,
              height: deviceHeight,
              margin: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(44),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF2E2E3A), // Sleek mobile phone bezel
                  width: 10,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
