import 'package:flutter/material.dart';

import '../data/community_store.dart';
import '../data/user_profile_store.dart';
import '../services/community_sync.dart';
import '../services/auth_gate.dart';
import '../services/file_storage.dart';
import '../widgets/expert_badge.dart';
import '../widgets/image_helpers.dart';
import 'community_post_screen.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F7);
const _green = Color(0xFF1E8C5A);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _category = "Tümü";
  String _query = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CommunitySync.instance.loadPosts();
    if (mounted) setState(() => _loading = false);
  }

  List<CommunityPost> get _filtered {
    return globalCommunityPosts.where((p) {
      if (_category != "Tümü" && p.category != _category) return false;
      if (_query.isNotEmpty && !("${p.title} ${p.body}".toLowerCase().contains(_query))) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filtered;
    final body = RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Diğer ebeveynlerle deneyim paylaş, soru sor, tavsiye al. 🤝", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _text),
                      decoration: const InputDecoration(
                        hintText: "Toplulukta ara...",
                        hintStyle: TextStyle(color: _light, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: _light),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ["Tümü", ...communityCategoryOptions].map((c) {
                        final sel = _category == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _category = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: sel ? _primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? Colors.transparent : const Color(0xFFE2E2E6).withOpacity(0.8))),
                              child: Center(child: Text(c, style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : _text))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _primary))))
          else if (posts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(32, 50, 32, 50),
                child: Column(children: [
                  Icon(Icons.forum_outlined, size: 48, color: _light),
                  SizedBox(height: 12),
                  Text("Henüz gönderi yok. İlk paylaşan sen ol! 💬", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _light)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _postCard(posts[i]),
                  childCount: posts.length,
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _text,
        title: const Text("Topluluk", style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.bold, color: _text)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: _newPost,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text("Yeni Gönderi", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: LayoutBuilder(
        builder: (ctx, c) => c.maxWidth >= 900
            ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body))
            : body,
      ),
    );
  }

  Widget _postCard(CommunityPost p) {
    final expert = p.anonymous ? null : expertTypeForAuthor(p.authorName);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E2E6).withOpacity(0.8))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityPostScreen(post: p)));
          if (mounted) _load(); // dönünce sayaçları tazele
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 16, backgroundColor: _primary.withOpacity(0.15), child: Text(p.anonymous ? "?" : (p.authorName.isNotEmpty ? p.authorName[0].toUpperCase() : "?"), style: const TextStyle(fontSize: 13, color: _primary, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: Text(p.anonymous ? "Anonim" : "@${p.authorName}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text))),
                        if (expert != null) ...[const SizedBox(width: 6), ExpertBadge(type: expert, fontSize: 10)],
                      ],
                    ),
                  ),
                  if (p.pinned) const Icon(Icons.push_pin, size: 15, color: _primary),
                  if (communityTimeAgo(p.createdMs).isNotEmpty) ...[const SizedBox(width: 6), Text(communityTimeAgo(p.createdMs), style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light))],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(p.category, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _primary))),
                  if (p.solved) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _green.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 11, color: _green), SizedBox(width: 3), Text("Çözüldü", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _green))]))],
                  if (p.hasPoll) ...[const SizedBox(width: 6), const Icon(Icons.poll_outlined, size: 14, color: _light)],
                ],
              ),
              const SizedBox(height: 8),
              Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text, height: 1.3)),
              if (p.body.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5A5A6A), height: 1.4)),
              ],
              if (isPhotoUrl(p.imageUrl)) ...[
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: double.infinity, height: 150, child: photoOrFallback(p.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover))),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 15, color: _light),
                  const SizedBox(width: 4),
                  Text("${p.likeCount}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, size: 15, color: _light),
                  const SizedBox(width: 4),
                  Text("${p.replyCount} yanıt", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Yeni gönderi ----
  void _newPost() {
    if (requireLogin(context)) return;
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    String category = communityCategoryOptions.first;
    String? photo;
    bool anonymous = false;
    bool poll = false;
    final pollCtrls = <TextEditingController>[TextEditingController(), TextEditingController()];
    bool busy = false;

    InputDecoration dec(String l) => InputDecoration(labelText: l, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 14, bottom: (MediaQuery.of(sheetCtx).viewInsets.bottom > 0 ? MediaQuery.of(sheetCtx).viewInsets.bottom : MediaQuery.of(sheetCtx).padding.bottom) + 16),
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E2E6), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 12),
                const Text("Yeni Gönderi 💬", style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
                const SizedBox(height: 2),
                const Text("Gönderin yönetici onayından sonra toplulukta yayınlanır.", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      TextField(controller: titleC, decoration: dec("Başlık")),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: dec("Kategori"),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: category,
                            isExpanded: true,
                            items: communityCategoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)))).toList(),
                            onChanged: (v) => setSheet(() => category = v ?? category),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: bodyC, maxLines: 5, decoration: dec("Yazını buraya yaz...")),
                      const SizedBox(height: 12),
                      PhotoPickerField(value: photo, label: "Fotoğraf (isteğe bağlı)", height: 130, onChanged: (v) => setSheet(() => photo = v)),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Anonim paylaş", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                        subtitle: const Text("Adın yerine 'Anonim' görünür.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                        value: anonymous,
                        activeColor: _primary,
                        onChanged: (v) => setSheet(() => anonymous = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Anket ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
                        subtitle: const Text("Oylama seçenekleri ekle.", style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
                        value: poll,
                        activeColor: _primary,
                        onChanged: (v) => setSheet(() => poll = v),
                      ),
                      if (poll) ...[
                        ...pollCtrls.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Expanded(child: TextField(controller: e.value, decoration: dec("Seçenek ${e.key + 1}"))),
                                if (pollCtrls.length > 2) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF4D6A), size: 20), onPressed: () => setSheet(() => pollCtrls.removeAt(e.key))),
                              ]),
                            )),
                        if (pollCtrls.length < 5)
                          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setSheet(() => pollCtrls.add(TextEditingController())), icon: const Icon(Icons.add, size: 16), label: const Text("Seçenek Ekle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)))),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final title = titleC.text.trim();
                            final bodyTxt = bodyC.text.trim();
                            final pollOpts = poll ? pollCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Başlık girin.")));
                              return;
                            }
                            if (bodyTxt.isEmpty && pollOpts.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bir metin yaz ya da anket ekle.")));
                              return;
                            }
                            if (poll && pollOpts.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anket için en az 2 seçenek girin.")));
                              return;
                            }
                            setSheet(() => busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(sheetCtx);
                            var imgUrl = photo ?? "";
                            if (isPhotoUrl(imgUrl) && imgUrl.startsWith('data:')) {
                              imgUrl = await FileStorage.instance.uploadDataUri("community/${DateTime.now().millisecondsSinceEpoch}.jpg", imgUrl);
                            }
                            await CommunitySync.instance.submitPost(
                              title: title,
                              body: bodyTxt,
                              category: category,
                              authorName: myUsername(fallbackName: ""),
                              imageUrl: imgUrl,
                              anonymous: anonymous,
                              pollOptions: pollOpts,
                            );
                            nav.pop();
                            messenger.showSnackBar(const SnackBar(content: Text("Gönderin alındı. Yönetici onayından sonra yayınlanacak. 👍")));
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Onaya Gönder", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
