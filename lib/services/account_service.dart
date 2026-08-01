import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/auth_config.dart';
import 'storage_service.dart';

enum AccountDeleteResult { success, reauthRequired, noUser, error }

/// Hesap silme (Google Play zorunluluğu). Firebase kullanıcısını + bulut
/// profilini siler, yerel veriyi temizler. Firebase son-oturum ister
/// (requires-recent-login) → yeniden kimlik doğrulama akışı sağlanır.
class AccountService {
  AccountService._();

  static String? get providerId {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.providerData.isEmpty) return null;
    return u.providerData.first.providerId; // 'password' | 'google.com' | 'apple.com'
  }

  static Future<AccountDeleteResult> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return AccountDeleteResult.noUser;
    final uid = user.uid;
    try {
      // Bulut public profilini sil (diğer koleksiyonlardaki içerik admin
      // moderasyonuyla yönetilir; kullanıcı hesabı silinince erişilemez).
      try {
        await FirebaseFirestore.instance.collection('profiles').doc(uid).delete();
      } catch (_) {}
      await user.delete();
      await StorageService.instance.clearUserData();
      return AccountDeleteResult.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return AccountDeleteResult.reauthRequired;
      debugPrint('AccountService.deleteAccount failed: ${e.code}');
      return AccountDeleteResult.error;
    } catch (e) {
      debugPrint('AccountService.deleteAccount failed: $e');
      return AccountDeleteResult.error;
    }
  }

  /// E-posta/şifre kullanıcısı için yeniden kimlik doğrulama.
  static Future<bool> reauthWithPassword(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return true;
    } catch (e) {
      debugPrint('reauthWithPassword failed: $e');
      return false;
    }
  }

  /// Google kullanıcısı için yeniden kimlik doğrulama.
  static Future<bool> reauthWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return true;
      }
      final g = await GoogleSignIn(
        serverClientId: kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
      ).signIn();
      if (g == null) return false;
      final ga = await g.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(accessToken: ga.accessToken, idToken: ga.idToken),
      );
      return true;
    } catch (e) {
      debugPrint('reauthWithGoogle failed: $e');
      return false;
    }
  }

  /// Apple kullanıcısı için yeniden kimlik doğrulama.
  ///
  /// ZORUNLU: Apple ile giren kullanıcının ŞİFRESİ YOKTUR. Bu yol olmadan
  /// Firebase 'requires-recent-login' döndürdüğünde kullanıcıya şifre soruluyor,
  /// giremiyor ve hesabını SİLEMİYOR. App Store Guideline 5.1.1(v) hesap
  /// oluşturan uygulamalarda uygulama içi hesap silmeyi zorunlu tutar; bu
  /// eksiklik doğrudan ret sebebidir.
  static Future<bool> reauthWithApple() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(
          OAuthProvider("apple.com")
            ..addScope('email')
            ..addScope('name'),
        );
        return true;
      }
      // Girişteki ile aynı desen: hash'lenmiş nonce Apple'a, ham nonce Firebase'e.
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      await user.reauthenticateWithCredential(
        OAuthProvider("apple.com").credential(
          idToken: appleCred.identityToken,
          rawNonce: rawNonce,
        ),
      );
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Kullanıcı iptal ettiyse hata değil.
      if (e.code != AuthorizationErrorCode.canceled) {
        debugPrint('reauthWithApple failed: ${e.code.name}');
      }
      return false;
    } catch (e) {
      debugPrint('reauthWithApple failed: $e');
      return false;
    }
  }

  static String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
