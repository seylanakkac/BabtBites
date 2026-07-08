import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

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
    return u.providerData.first.providerId; // 'password' | 'google.com'
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
}
