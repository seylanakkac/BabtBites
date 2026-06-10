import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final List<Map<String, dynamic>>? initialBabies;

  const HomeScreen({
    super.key,
    this.initialBabies,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFFB38A); // Softer Apricot
    const secondaryColor = Color(0xFF42C18C); // Softer Mint Green
    const textColor = Color(0xFF7A7A8A); // Softer dark grey
    const lightTextColor = Color(0xFFA8A8B3);
    const cardBgColor = Colors.white;

    // Use default mock babies if none provided
    final babiesList = initialBabies ?? [
      {"name": "Zeynep", "gender": "Kız", "dob": "12.10.2025"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "BabyBites",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(
                Icons.logout_outlined,
                color: textColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Hoş Geldiniz 👋",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Bebeğinizin beslenme yolculuğunu bugün de takip edelim.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: lightTextColor,
                ),
              ),
              const SizedBox(height: 24),

              // Babies Card Section
              const Text(
                "Kayıtlı Bebekleriniz",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              
              ...babiesList.map((baby) {
                final isFemale = baby["gender"] == "Kız";
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isFemale 
                              ? Colors.pink.withOpacity(0.08)
                              : Colors.orange.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFemale ? Icons.girl_outlined : Icons.boy_outlined,
                          color: isFemale ? Colors.pink[300] : Colors.orange[400],
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              baby["name"] ?? "Bilinmeyen",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${baby["gender"]} • ${baby["dob"]}",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: lightTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: lightTextColor,
                      ),
                    ],
                  ),
                );
              }),

              // Add Baby Button Shortcut
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/onboarding');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Yeni Bebek Ekle"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Placeholder content blocks to make it look like a real app dashboard
              const Text(
                "Günlük Özet",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardMetric(
                      title: "Denenecekler",
                      value: "4 Gıda",
                      icon: Icons.restaurant_menu,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDashboardMetric(
                      title: "Alerjen Takibi",
                      value: "Sorunsuz",
                      icon: Icons.verified_user_outlined,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Tip of the day card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.1), Colors.orange.withOpacity(0.02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Günün Önerisi",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Bebeğiniz 6. ayını doldurduysa ek gıdaya öncelikle alerji riski düşük olan kabak veya havuç püresiyle başlamanız önerilir.",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFFA8A8B3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A7A8A),
            ),
          ),
        ],
      ),
    );
  }
}
