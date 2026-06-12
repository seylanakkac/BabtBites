import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Admin account unlocks the admin panel (no backend — fixed credentials).
    final isAdmin = _isLogin &&
        _emailController.text.trim().toLowerCase() == "admin@babybites.com" &&
        _passwordController.text == "admin1234";
    setAdminMode(isAdmin);
    StorageService.instance.saveIsAdmin(isAdmin);

    // On registration, persist the parent identity (name + relationship).
    if (!_isLogin) {
      StorageService.instance.saveParent(
        _parentNameController.text.trim(),
        _parentRelationship,
      );
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Navigate based on admin / Login / Register mode
        if (globalIsAdmin) {
          Navigator.of(context).pushReplacementNamed('/admin');
        } else if (_isLogin) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    });
  }

  void _socialLogin(String platform) {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Navigate based on admin / Login / Register mode
        if (globalIsAdmin) {
          Navigator.of(context).pushReplacementNamed('/admin');
        } else if (_isLogin) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    });
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

                  // Forgot Password (only shown on Login screen)
                  if (_isLogin)
                    Center(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi.")),
                            );
                          },
                          child: const Text(
                            "Şifremi Unuttum",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
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
    );
  }
}
