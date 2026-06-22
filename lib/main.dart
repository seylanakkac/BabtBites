import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'services/cloud_sync.dart';
import 'services/catalog_sync.dart';
import 'services/social_sync.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/articles_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'data/food_database.dart';
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
    // Don't let a failing upload retry for the default 2 minutes (UI would hang).
    try {
      FirebaseStorage.instance.setMaxOperationRetryTime(const Duration(seconds: 20));
      FirebaseStorage.instance.setMaxUploadRetryTime(const Duration(seconds: 25));
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
    // Time-box startup network reads so a slow/offline connection can never
    // block the first frame.
    await CatalogSync.instance.pull().timeout(const Duration(seconds: 10), onTimeout: () {});
    // Real cross-user recipe stats (ratings/likes/views) — public read.
    await SocialSync.instance.loadStats().timeout(const Duration(seconds: 10), onTimeout: () {});
    // Onaylı uzmanlar (rozetler + uzman içerik filtresi için) — public read.
    await SocialSync.instance.loadExperts().timeout(const Duration(seconds: 8), onTimeout: () {});
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
      // Tarif derin linki: babybites.com.tr/#/r/<id> → tarif detayını açar
      // (paylaşılan hikaye linkinden gelenler doğrudan tarifi görür).
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/r/')) {
          final id = name.substring(3);
          final idx = globalRecipesDatabase.indexWhere((r) => r.id == id);
          if (idx >= 0) {
            return MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: globalRecipesDatabase[idx]),
              settings: settings,
            );
          }
        }
        return null;
      },
      // Bilinmeyen/eksik route (ör. derin linkin ara segmenti) → splash'e düş.
      onUnknownRoute: (settings) => MaterialPageRoute(builder: (_) => const SplashScreen()),
      builder: (context, child) {
        // Dar (mobil) ekranda metni biraz sıkıştır; geniş (web/masaüstü) ekranda
        // ise büyüt — masaüstünde "mobil uygulama" gibi küçük görünmesin.
        final mq = MediaQuery.of(context);
        final scale = mq.size.width >= 900 ? 1.08 : 0.92;
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: MobileWebFrame(child: child!),
        );
      },
    );
  }
}
