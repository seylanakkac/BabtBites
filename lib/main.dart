import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/cloud_sync.dart';
import 'services/catalog_sync.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/admin_screen.dart';
import 'widgets/mobile_web_frame.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to Firebase (account + cloud sync backend). Wrapped so a transient
  // init failure never blocks app startup — local storage still works offline.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase initialized: ${Firebase.app().options.projectId}');
    // Offline cache so the app works without a connection and syncs on reconnect.
    try {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
    } catch (_) {}
    // Mirror user-data saves and admin catalog edits to the cloud.
    StorageService.cloudPush = CloudSync.instance.push;
    StorageService.catalogPush = CatalogSync.instance.push;
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase init failed (app continues in local mode): $e');
  }
  // Restore persisted user data (cart, weekly plan, food flags) before the
  // first frame so screens render with the user's saved state.
  await StorageService.instance.init();
  // Pull the shared catalog (admin content) into prefs BEFORE loadInto so it
  // merges in a single clean pass and every user sees the admin's edits.
  if (firebaseReady) {
    await CatalogSync.instance.pull();
  }
  StorageService.instance.loadInto();
  runApp(const BabyBitesApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class BabyBitesApp extends StatelessWidget {
  const BabyBitesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D2D3A); // Darker, higher contrast dark grey

    // Emoji color fallback. On web (CanvasKit) the global 'Inter' family makes
    // emoji glyphs render as monochrome outlines; listing color-emoji families
    // as a fallback lets the engine pick up its bundled Noto Color Emoji.
    const List<String> emojiFallback = [
      'Noto Color Emoji',
      'Apple Color Emoji',
      'Segoe UI Emoji',
    ];

    return MaterialApp(
      title: 'BabyBites',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6), // Warm Cream
        fontFamily: 'Inter', // Local font family
        // Render emojis in full color (see emojiFallback above).
        fontFamilyFallback: emojiFallback,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF7A45), // Vibrant Coral Orange
          secondary: Color(0xFF10B981), // Vibrant Emerald Green
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: textColor,
          error: Color(0xFFFF4D6A),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Inter',
              fontFamilyFallback: emojiFallback,
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
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/articles': (context) => const ArticlesScreen(),
        '/admin': (context) => const AdminScreen(),
      },
      builder: (context, child) {
        // Slightly compact the whole app (text ~10% smaller) so dense screens
        // breathe and dialogs fit the phone frame.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(0.9)),
          child: MobileWebFrame(child: child!),
        );
      },
    );
  }
}
