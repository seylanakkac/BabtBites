import 'package:flutter/material.dart';
import '../screens/sources_screen.dart';

/// A small, reusable medical disclaimer shown across health/nutrition areas.
/// Required for app-store compliance — this app is informational, not a
/// substitute for professional medical advice.
///
/// Ayrıca bilgilerin dayandığı kurumlara (WHO, T.C. Sağlık Bakanlığı, AAP,
/// USDA) götüren bir "Kaynaklar" bağlantısı gösterir. App Store Guideline
/// 1.4.1 tıbbi bilgi için kaynak atfını zorunlu tutar ve bu atıf kullanıcının
/// kolayca bulabileceği yerde olmalıdır; bu bileşen tıbbi bilgi gösterilen tüm
/// ekranlarda kullanıldığı için atıf her yerde erişilebilir olur.
class MedicalDisclaimer extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final String text;

  /// Kaynaklar bağlantısını gizlemek için false yapılabilir (ör. kaynak
  /// ekranının kendi içinde tekrar göstermemek için).
  final bool showSources;

  const MedicalDisclaimer({
    super.key,
    this.margin = EdgeInsets.zero,
    this.showSources = true,
    this.text =
        "Bu bilgiler yalnızca genel bilgilendirme amaçlıdır; tıbbi tavsiye yerine geçmez. Bebeğinizin beslenmesi ve sağlığıyla ilgili kararlar için mutlaka çocuk doktorunuza danışın.",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C879).withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 13, color: Color(0xFFB8860B)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF8A7A4A), height: 1.3),
                ),
                if (showSources) ...[
                  const SizedBox(height: 2),
                  // Guideline 1.4.1: atıf "kullanıcının kolayca bulabileceği"
                  // yerde olmalı. Bu yüzden bağlantı bilinçli olarak uyarı
                  // metninden DAHA belirgin: daha büyük punto, daha koyu renk
                  // ve en az 44pt dokunma alanı (Apple HIG minimumu).
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SourcesScreen()),
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 15, color: Color(0xFF7A5C00)),
                          SizedBox(width: 5),
                          Text(
                            "Bilgi kaynaklarımız",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7A5C00),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF7A5C00),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right,
                              size: 15, color: Color(0xFF7A5C00)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
