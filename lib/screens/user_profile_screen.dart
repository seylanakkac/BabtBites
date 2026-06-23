import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/food_database.dart';
import '../data/recipe_social_store.dart';
import '../data/user_profile_store.dart';
import '../services/social_sync.dart';
import '../services/storage_service.dart';
import '../services/auth_gate.dart';
import '../widgets/expert_badge.dart';
import '../widgets/web_shell.dart';
import 'recipe_detail_screen.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F6);
const _danger = Color(0xFFFF4D6A);
const _star = Color(0xFFFFB300);

/// Public profile of a recipe author. Shows ONLY the @username, linked social
/// accounts and the recipes they authored — no real name, baby or contact info.
class UserProfileScreen extends StatefulWidget {
  final String author;
  const UserProfileScreen({super.key, required this.author});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the real public profile (social links) from Firestore.
    SocialSync.instance.loadProfileByUsername(widget.author).then((_) {
      if (mounted) setState(() {});
    });
  }

  static const Map<String, IconData> _icons = {
    "instagram": FontAwesomeIcons.instagram,
    "tiktok": FontAwesomeIcons.tiktok,
    "youtube": FontAwesomeIcons.youtube,
    "facebook": FontAwesomeIcons.facebookF,
    "x": FontAwesomeIcons.twitter,
    "whatsapp": FontAwesomeIcons.whatsapp,
  };
  static const Map<String, Color> _colors = {
    "instagram": Color(0xFFE1306C),
    "tiktok": Color(0xFF010101),
    "youtube": Color(0xFFFF0000),
    "facebook": Color(0xFF1877F2),
    "x": Color(0xFF1DA1F2),
    "whatsapp": Color(0xFF25D366),
  };

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return webPageShell(context, maxWidth: 880, child: _shelled(context));
  }

  Widget _followButton(String author) {
    final following = isFollowing(author);
    return SizedBox(
      width: 200,
      child: following
          ? OutlinedButton.icon(
              onPressed: () => _toggleFollow(author),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Takip ediliyor", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )
          : ElevatedButton.icon(
              onPressed: () => _toggleFollow(author),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text("Takip Et", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
    );
  }

  void _toggleFollow(String author) {
    if (requireLogin(context)) return;
    final u = author.trim().toLowerCase();
    setState(() {
      if (globalMyFollowing.contains(u)) {
        globalMyFollowing.remove(u);
      } else {
        globalMyFollowing.add(u);
      }
    });
    StorageService.instance.saveMyProfile();
    SocialSync.instance.setFollowing(globalMyFollowing.toList());
  }

  Widget _shelled(BuildContext context) {
    final author = widget.author;
    final profile = profileForAuthor(author);
    final recipes = recipesByAuthor(author);
    final socials = profile?.socials ?? const <String, String>{};
    final linked = kSocialPlatforms.where((p) => (socials[p] ?? "").trim().isNotEmpty).toList();
    final initial = author.isNotEmpty ? author[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _text), onPressed: () => Navigator.pop(context)),
        title: Text("@$author", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header: avatar + @username
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_primary, _danger]),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(initial, style: const TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 10),
                Text("@$author", style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
                if (expertTypeForAuthor(author) != null) ...[
                  const SizedBox(height: 6),
                  ExpertBadge(type: expertTypeForAuthor(author)!, fontSize: 12),
                ],
                const SizedBox(height: 4),
                Text("${recipes.length} tarif", style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: _light)),
                // Takip Et: kendi profilin hariç her yazarda görünür.
                // Misafir tıklarsa _toggleFollow login ekranını açar.
                if (author.trim().isNotEmpty && author.trim().toLowerCase() != myUsername().trim().toLowerCase()) ...[
                  const SizedBox(height: 12),
                  _followButton(author),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Social accounts
          if (linked.isNotEmpty) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: linked.map((p) {
                final color = _colors[p] ?? _primary;
                return GestureDetector(
                  onTap: () => _open(socialUrl(p, socials[p]!)),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.4))),
                    child: Icon(_icons[p] ?? Icons.link, size: 22, color: color),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
          ] else ...[
            const Center(child: Text("Bağlı sosyal hesap yok", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light))),
            const SizedBox(height: 22),
          ],

          // Recipes
          const Text("Tarifleri 🍳", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 10),
          if (recipes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6))),
              child: const Text("Henüz yayınlanmış tarif yok.", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
            )
          else
            ...recipes.map((r) => _recipeRow(context, r)),
        ],
      ),
    );
  }

  Widget _recipeRow(BuildContext context, Recipe recipe) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6))),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: _primary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Icon(Icons.restaurant_menu, color: _primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("${recipe.startingMonth}+ Ay • ${recipe.prepTime}", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 13, color: _star),
                      const SizedBox(width: 2),
                      Text(recipeRatingLabel(recipe.id), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: _text)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _light),
          ],
        ),
      ),
    );
  }
}
