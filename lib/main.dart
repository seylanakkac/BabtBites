import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/mobile_web_frame.dart';

void main() {
  runApp(const BabyBitesApp());
}

class BabyBitesApp extends StatelessWidget {
  const BabyBitesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF7A7A8A); // Lighter, softer dark grey

    return MaterialApp(
      title: 'BabyBites',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6), // Warm Cream
        fontFamily: 'Inter', // Local font family
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFFB38A), // Softer Apricot
          secondary: Color(0xFF42C18C), // Softer Mint Green
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Color(0xFF7A7A8A),
          error: Color(0xFFFF4D6A),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Inter',
              bodyColor: textColor,
              displayColor: textColor,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF9F6),
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500, // Softer weight
            color: textColor,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
      },
      builder: (context, child) {
        return MobileWebFrame(child: child!);
      },
    );
  }
}
