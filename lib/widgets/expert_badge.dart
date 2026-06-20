import 'package:flutter/material.dart';
import '../data/user_profile_store.dart';

/// Onaylı uzman rozeti (✓ Diyetisyen gibi). [type] boşsa hiçbir şey göstermez.
class ExpertBadge extends StatelessWidget {
  final String type;
  final double fontSize;
  const ExpertBadge({super.key, required this.type, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    if (type.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.25),
      decoration: BoxDecoration(color: const Color(0xFF2BB673).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: fontSize + 3, color: const Color(0xFF2BB673)),
          const SizedBox(width: 3),
          Text(type, style: TextStyle(fontFamily: 'Inter', fontSize: fontSize, fontWeight: FontWeight.bold, color: const Color(0xFF1E8C5A))),
        ],
      ),
    );
  }
}

/// Yazar uzmansa rozet, değilse boş. Kısayol.
Widget expertBadgeFor(String author, {double fontSize = 11}) {
  final t = expertTypeForAuthor(author);
  return t == null ? const SizedBox.shrink() : ExpertBadge(type: t, fontSize: fontSize);
}
