import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';

/// Misafir (üyeliksiz gezen) kullanıcı mı?
bool isGuest() => FirebaseAuth.instance.currentUser == null;

/// Hesap gerektiren bir işlemde çağrılır. Misafirse login ekranını açar ve
/// `true` döner (işlem engellendi). Girişliyse `false` döner (devam edilebilir).
bool requireLogin(BuildContext context) {
  if (!isGuest()) return false;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  return true;
}
