import 'package:flutter/material.dart';

/// Small "Sponsorlu" label shown on admin-flagged sponsored recipes/articles.
/// Optional [label] appends the sponsor/brand name (e.g. "Sponsorlu · MarkaAdı").
class SponsoredBadge extends StatelessWidget {
  final String label;
  const SponsoredBadge({super.key, this.label = ""});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB7791F);
    final text = label.trim().isEmpty ? "Sponsorlu" : "Sponsorlu · ${label.trim()}";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amber.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_outlined, size: 12, color: amber),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: amber),
            ),
          ),
        ],
      ),
    );
  }
}
