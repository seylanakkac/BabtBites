import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/cloud_sync.dart';
import '../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _parentNameController = TextEditingController();

  // Parent's relationship to the baby (registration only).
  static const List<String> _relationshipOptions = ["Anne", "Baba", "Bakıcı", "Diğer"];
  String _parentRelationship = "Anne";

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _rememberMe = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    try {
      await _applyPersistence();
      bool isNewUser = false;
      if (_isLogin) {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: pass);
      } else {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);
        await cred.user?.updateDisplayName(_parentNameController.text.trim());
        StorageService.instance.saveParent(
          _parentNameController.text.trim(),
          _parentRelationship,
        );
        isNewUser = true;
      }
      _applyAdmin(email);
      // Bring this user's cloud data down (or seed it on first use).
      await CloudSync.instance.pull();
      if (!mounted) return;
      _routeAfterAuth(isNewUser);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authErrorTr(e.code));
    } catch (_) {
      if (mounted) _showError("Bir hata oluştu. Lütfen tekrar deneyin.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _socialLogin(String platform) async {
    if (platform == "Apple") {
      _showError("Apple ile giriş yakında (web yapılandırması gerekiyor).");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _applyPersistence();
      final cred =
          await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      final email = cred.user?.email ?? "";
      final isNew = cred.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        StorageService.instance
            .saveParent(cred.user?.displayName ?? "", "Anne");
      }
      _applyAdmin(email);
      await CloudSync.instance.pull();
      if (!mounted) return;
      _routeAfterAuth(isNew);
    } on FirebaseAuthException catch (e) {
      if (e.code == "popup-closed-by-user" ||
          e.code == "cancelled-popup-request") {
        // user dismissed the popup — no error toast.
      } else if (mounted) {
        _showError(_authErrorTr(e.code));
      }
    } catch (_) {
      if (mounted) _showError("Google ile giriş yapılamadı.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// "Beni hatırla": on web, LOCAL persistence keeps the session across browser
  /// restarts; SESSION clears it when the tab closes. No-op off web.
  Future<void> _applyPersistence() async {
    if (!kIsWeb) return;
    try {
      await FirebaseAuth.instance
          .setPersistence(_rememberMe ? Persistence.LOCAL : Persistence.SESSION);
    } catch (_) {}
  }

  void _applyAdmin(String email) {
    final isAdmin = isAdminEmail(email);
    setAdminMode(isAdmin);
    StorageService.instance.saveIsAdmin(isAdmin);
  }

  void _routeAfterAuth(bool isNewUser) {
    if (globalIsAdmin) {
      Navigator.of(context).pushReplacementNamed('/admin');
      return;
    }
    final babies = StorageService.instance.loadBabies();
    if (isNewUser || babies == null || babies.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError("Önce e-posta adresinizi girin.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authErrorTr(e.code));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFFF4D6A)),
    );
  }

  String _authErrorTr(String code) {
    switch (code) {
      case 'invalid-email':
        return "Geçersiz e-posta adresi.";
      case 'user-disabled':
        return "Bu hesap devre dışı bırakılmış.";
      case 'user-not-found':
        return "Bu e-posta ile kayıtlı hesap yok.";
      case 'wrong-password':
      case 'invalid-credential':
        return "E-posta veya şifre hatalı.";
      case 'email-already-in-use':
        return "Bu e-posta zaten kayıtlı. Giriş yapın.";
      case 'weak-password':
        return "Şifre çok zayıf (en az 6 karakter).";
      case 'operation-not-allowed':
        return "Bu giriş yöntemi etkin değil.";
      case 'too-many-requests':
        return "Çok fazla deneme. Lütfen sonra tekrar deneyin.";
      case 'network-request-failed':
        return "İnternet bağlantısı yok.";
      default:
        return "Giriş başarısız ($code).";
    }
  }

  Future<void> _openTermsUrl() async {
    final Uri url = Uri.parse('https://github.com/seylanakkac/BabtBites/blob/main/TERMS_OF_USE.md');
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bağlantı açılamadı.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bağlantı açılamadı.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _parentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF7A45); // Vibrant Apricot/Coral
    const textColor = Color(0xFF2D2D3A); // Darker charcoal for legibility
    const lightTextColor = Color(0xFF8E8E9F); // Lighter text color
    const inputBgColor = Color(0xFFF5F5F7); // Light grey input box color
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white, // Clean white page background
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Left-aligned like image
                children: [
                  if (!isKeyboardOpen) ...[
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.015),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Header Title
                  Text(
                    _isLogin ? "Hoş Geldin Canım Anne 👋" : "Hesap Oluşturun 👋",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Header Subtitle
                  Text(
                    _isLogin ? "Bebeğin için en iyisi burada" : "Bebeğiniz için en tatlı ek gıda günlüğü",
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: lightTextColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email Label
                  const Text(
                    "E-posta",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "ornek@email.com",
                      hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFB0B0C0),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.email_outlined, size: 18, color: lightTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    validator: (val) {
                      if (val == null || !val.contains('@')) {
                        return "Lütfen geçerli bir e-posta adresi girin.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Label
                  const Text(
                    "Şifre",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                    onFieldSubmitted: (_) {
                      if (_isLogin && !_isLoading) _submit();
                    },
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "........",
                      hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFB0B0C0),
                        fontSize: 14,
                        letterSpacing: 2.0,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, size: 18, color: lightTextColor),
                      suffixIcon: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: lightTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return "Şifre en az 6 karakter olmalıdır.";
                      }
                      return null;
                    },
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Şifreyi Tekrarla",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: "........",
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFB0B0C0),
                          fontSize: 14,
                          letterSpacing: 2.0,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: lightTextColor),
                        suffixIcon: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: lightTextColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: primaryColor, width: 1.5),
                        ),
                        filled: true,
                        fillColor: inputBgColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "Lütfen şifrenizi tekrar girin.";
                        }
                        if (val != _passwordController.text) {
                          return "Şifreler eşleşmiyor.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Parent name
                    const Text(
                      "Adınız",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _parentNameController,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: "Örn. Seylan",
                        hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0xFFB0B0C0), fontSize: 14),
                        prefixIcon: const Icon(Icons.person_outline, size: 18, color: lightTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
                        filled: true,
                        fillColor: inputBgColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      validator: (val) {
                        if (!_isLogin && (val == null || val.trim().isEmpty)) {
                          return "Lütfen adınızı girin.";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Parent relationship to baby
                    const Text(
                      "Bebeğin nesi oluyorsunuz?",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _relationshipOptions.map((role) {
                        final selected = _parentRelationship == role;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _parentRelationship = role),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? primaryColor.withOpacity(0.12) : inputBgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected ? primaryColor : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? primaryColor : lightTextColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Remember me + Forgot password (only on Login screen)
                  if (_isLogin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: primaryColor,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Beni hatırla",
                                  style: TextStyle(fontFamily: 'Inter', color: lightTextColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text(
                              "Şifremi Unuttum",
                              style: TextStyle(fontFamily: 'Inter', color: primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Terms and Conditions Checkbox (Only in Register mode)
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    FormField<bool>(
                      initialValue: _acceptTerms,
                      validator: (value) {
                        if (value == null || value == false) {
                          return "Kullanım koşullarını kabul etmelisiniz.";
                        }
                        return null;
                      },
                      builder: (state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Checkbox(
                                    value: state.value ?? false,
                                    activeColor: primaryColor,
                                    onChanged: (bool? newValue) {
                                      state.didChange(newValue);
                                      setState(() {
                                        _acceptTerms = newValue ?? false;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      text: '',
                                      children: [
                                        TextSpan(
                                          text: 'Kullanım Koşulları ve Gizlilik Politikası',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            color: primaryColor,
                                            decoration: TextDecoration.underline,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = _openTermsUrl,
                                        ),
                                        const TextSpan(
                                          text: '\'nı okudum ve kabul ediyorum.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: lightTextColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0, top: 4.0),
                                child: Text(
                                  state.errorText!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const SizedBox(height: 12),
                  ],
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25), // Pill-shaped
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF5A5A6A)),
                                ),
                              )
                            : Text(
                                _isLogin ? "Giriş Yap" : "Kayıt Ol",
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // "veya" Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFECEBE9), thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "veya",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: lightTextColor,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFECEBE9), thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Social Sign-In Row
                  Row(
                    children: [
                      // Google Button
                      Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _socialLogin("Google"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inputBgColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 16,
                                  width: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Google",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Apple Button
                      Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _socialLogin("Apple"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inputBgColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.apple,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Apple",
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Bottom Toggle Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Hesabın yok mu? " : "Zaten üye misiniz? ",
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: lightTextColor,
                          fontSize: 13,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _confirmPasswordController.clear();
                              _acceptTerms = false;
                            });
                          },
                          child: Text(
                            _isLogin ? "Kayıt Ol" : "Giriş Yap",
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
