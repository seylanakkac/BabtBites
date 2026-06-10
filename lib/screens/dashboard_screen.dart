import 'package:flutter/material.dart';

class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFFB38A); // Softer Apricot
    const textColor = Color(0xFF7A7A8A); // Softer dark grey

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "BabyBites",
          style: TextStyle(
            fontFamily: 'Inter',
            color: textColor,
            fontWeight: FontWeight.w500, // Softer weight
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_outlined,
                  size: 50,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Giriş Başarılı! 🎉",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w500, // Softer weight
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "BabyBites Anasayfası (Dashboard) yapım aşamasındadır. Şimdi açılış ve giriş ekranlarının tasarımını inceleyebilirsiniz.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate back to login
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Çıkış Yap"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
