import 'package:flutter/material.dart';

/// A small, reusable medical disclaimer shown across health/nutrition areas.
/// Required for app-store compliance — this app is informational, not a
/// substitute for professional medical advice.
class MedicalDisclaimer extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final String text;
  const MedicalDisclaimer({
    super.key,
    this.margin = EdgeInsets.zero,
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
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF8A7A4A), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
