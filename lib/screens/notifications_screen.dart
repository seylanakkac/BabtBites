import 'package:flutter/material.dart';

import '../data/extras_store.dart';
import '../services/social_sync.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _green = Color(0xFF10B981);

/// In-app notifications (e.g. "your recipe was approved"). Loads the user's
/// notifications from Firestore and marks them read on open.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SocialSync.instance.loadNotifications();
    if (mounted) setState(() => _loading = false);
    // Mark read AFTER the list has rendered (so unread dots still show once).
    await SocialSync.instance.markAllNotificationsRead();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'recipe':
        return Icons.menu_book_rounded;
      case 'comment':
        return Icons.rate_review_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _fmtDate(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    const months = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    final m = int.tryParse(p[1]) ?? 1;
    return "${int.tryParse(p[2]) ?? ''} ${months[(m - 1).clamp(0, 11)]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: const Text("Bildirimler 🔔", style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : globalNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 56, color: _light.withOpacity(0.6)),
                      const SizedBox(height: 12),
                      const Text("Henüz bildirimin yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _light)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: globalNotifications.map((n) {
                    final unread = n["read"] != true;
                    final type = n["type"]?.toString() ?? "info";
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: unread ? _primary.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: unread ? _primary.withOpacity(0.3) : const Color(0xFFE2E2E6).withOpacity(0.6)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: (type == 'recipe' ? _green : _primary).withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(_iconFor(type), size: 20, color: type == 'recipe' ? _green : _primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(n["title"]?.toString() ?? "Bildirim", style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
                                    if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle)),
                                  ],
                                ),
                                if ((n["body"]?.toString() ?? "").isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(n["body"].toString(), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, height: 1.35)),
                                ],
                                const SizedBox(height: 6),
                                Text(_fmtDate(n["date"]?.toString() ?? ""), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
