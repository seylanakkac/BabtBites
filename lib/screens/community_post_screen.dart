import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/community_store.dart';
import '../data/user_profile_store.dart';
import '../services/community_sync.dart';
import '../services/auth_gate.dart';
import '../services/storage_service.dart';
import '../widgets/expert_badge.dart';
import '../widgets/image_helpers.dart';

const _primary = Color(0xFFFF7A45);
const _text = Color(0xFF2D2D3A);
const _light = Color(0xFFA8A8B3);
const _bg = Color(0xFFFAF9F7);
const _green = Color(0xFF1E8C5A);
const _danger = Color(0xFFFF4D6A);

class CommunityPostScreen extends StatefulWidget {
  final CommunityPost post;
  const CommunityPostScreen({super.key, required this.post});

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  late int _likeCount;
  late bool _liked;
  late List<int> _pollVotes;
  late bool _iVoted;
  late bool _solved;
  late String _acceptedReplyId;
  List<CommunityReply> _replies = [];
  bool _loadingReplies = true;
  bool _sending = false;
  final _replyCtrl = TextEditingController();
  bool _replyAnon = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _canModerate => _uid == widget.post.authorUid || globalIsAdmin;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _likeCount = p.likeCount;
    _liked = globalMyCommunityLikes.contains(p.id);
    _pollVotes = List<int>.from(p.pollVotes);
    _iVoted = _uid != null && p.pollVotedBy.containsKey(_uid);
    _solved = p.solved;
    _acceptedReplyId = p.acceptedReplyId;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    setState(() => _loadingReplies = true);
    final list = await CommunitySync.instance.loadReplies(widget.post.id);
    if (!mounted) return;
    setState(() {
      _replies = list;
      _loadingReplies = false;
    });
  }

  Future<void> _toggleLike() async {
    if (requireLogin(context)) return;
    final next = !_liked;
    setState(() {
      _liked = next;
      _likeCount += next ? 1 : -1;
      if (next) {
        globalMyCommunityLikes.add(widget.post.id);
      } else {
        globalMyCommunityLikes.remove(widget.post.id);
      }
    });
    final count = await CommunitySync.instance.toggleLike(widget.post.id, next);
    if (count != null && mounted) setState(() => _likeCount = count);
  }

  Future<void> _vote(int i) async {
    if (requireLogin(context)) return;
    final res = await CommunitySync.instance.votePoll(widget.post.id, i);
    if (!mounted) return;
    setState(() {
      if (res != null) _pollVotes = res;
      _iVoted = true;
    });
  }

  Future<void> _sendReply() async {
    if (requireLogin(context)) return;
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    await CommunitySync.instance.addReply(widget.post.id, body: body, authorName: myUsername(fallbackName: ""), anonymous: _replyAnon);
    _replyCtrl.clear();
    await _loadReplies();
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _accept(CommunityReply r) async {
    await CommunitySync.instance.acceptReply(widget.post.id, r.id);
    if (!mounted) return;
    setState(() {
      _solved = true;
      _acceptedReplyId = r.id;
    });
    _loadReplies();
  }

  Future<void> _report() async {
    if (requireLogin(context)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Şikayet Et", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Bu gönderiyi uygunsuz içerik olarak yöneticiye bildirmek istiyor musun?", style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Vazgeç")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text("Şikayet Et")),
        ],
      ),
    );
    if (ok == true) {
      await CommunitySync.instance.reportPost(widget.post.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayetin alındı. Teşekkürler.")));
    }
  }

  Future<void> _blockAuthor(String name) async {
    if (name.trim().isEmpty) return;
    globalBlockedUsers.add(name.trim().toLowerCase());
    await StorageService.instance.saveMyProfile();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("@$name engellendi. İçerikleri gizlendi.")));
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Gönderiyi Sil", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Bu gönderi kalıcı olarak silinsin mi?", style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Vazgeç")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: const Text("Sil")),
        ],
      ),
    );
    if (ok == true) {
      await CommunitySync.instance.deletePost(widget.post.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final expert = p.anonymous ? null : expertTypeForAuthor(p.authorName);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // yazar satırı
        Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: _primary.withOpacity(0.15), child: Text(p.anonymous ? "?" : (p.authorName.isNotEmpty ? p.authorName[0].toUpperCase() : "?"), style: const TextStyle(fontSize: 15, color: _primary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(p.anonymous ? "Anonim" : "@${p.authorName}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: _text))),
                    if (expert != null) ...[const SizedBox(width: 6), ExpertBadge(type: expert, fontSize: 10)],
                  ]),
                  Text("${p.category} · ${communityTimeAgo(p.createdMs)}", style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: _light)),
                ],
              ),
            ),
            if (_solved) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 12, color: _green), SizedBox(width: 3), Text("Çözüldü", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _green))])),
          ],
        ),
        const SizedBox(height: 14),
        Text(p.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w800, color: _text, height: 1.25)),
        if (p.body.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(p.body, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF3D3D4A), height: 1.55)),
        ],
        if (isPhotoUrl(p.imageUrl)) ...[
          const SizedBox(height: 14),
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: double.infinity, child: photoOrFallback(p.imageUrl, fallback: const SizedBox(), fit: BoxFit.cover))),
        ],
        if (p.hasPoll) ...[const SizedBox(height: 16), _pollWidget(p)],
        const SizedBox(height: 16),
        // aksiyon çubuğu
        Row(
          children: [
            _actionBtn(_liked ? Icons.favorite : Icons.favorite_border, "$_likeCount", _liked ? _danger : _light, _toggleLike),
            const SizedBox(width: 18),
            _actionBtn(Icons.chat_bubble_outline, "${_replies.length}", _light, null),
            const Spacer(),
            if (!p.anonymous && _uid != p.authorUid)
              IconButton(tooltip: "Kullanıcıyı engelle", icon: const Icon(Icons.person_off_outlined, size: 20, color: _light), onPressed: () => _blockAuthor(p.authorName)),
            IconButton(tooltip: "Şikayet et", icon: const Icon(Icons.flag_outlined, size: 20, color: _light), onPressed: _report),
            if (globalIsAdmin) IconButton(tooltip: "Sil", icon: const Icon(Icons.delete_outline, size: 20, color: _danger), onPressed: _deletePost),
          ],
        ),
        const Divider(height: 28),
        Text("Yanıtlar (${_replies.length})", style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 10),
        if (_loadingReplies)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _primary)))
        else if (_replies.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Henüz yanıt yok. İlk yanıtı sen yaz!", style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _light)))
        else
          ..._replies.where((r) => r.anonymous || !isBlockedUser(r.authorName)).map(_replyTile),
      ],
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _text,
        title: const Text("Gönderi", style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) => c.maxWidth >= 900
                  ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body))
                  : body,
            ),
          ),
          _replyComposer(),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: color))]),
        ),
      );

  Widget _pollWidget(CommunityPost p) {
    final total = _pollVotes.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E2E6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.poll_outlined, size: 16, color: _primary), SizedBox(width: 6), Text("Anket", style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: _text))]),
          const SizedBox(height: 10),
          ...p.pollOptions.asMap().entries.map((e) {
            final i = e.key;
            final votes = i < _pollVotes.length ? _pollVotes[i] : 0;
            final pct = total == 0 ? 0.0 : votes / total;
            if (_iVoted) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _text, fontWeight: FontWeight.w600))),
                      Text("%${(pct * 100).round()}", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: const Color(0xFFEDEDED), valueColor: const AlwaysStoppedAnimation(_primary))),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _vote(i),
                  style: OutlinedButton.styleFrom(foregroundColor: _primary, side: BorderSide(color: _primary.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), alignment: Alignment.centerLeft),
                  child: Text(e.value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
          if (_iVoted) Text("$total oy", style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _light)),
        ],
      ),
    );
  }

  Widget _replyTile(CommunityReply r) {
    final expert = r.anonymous ? null : expertTypeForAuthor(r.authorName);
    final accepted = r.id == _acceptedReplyId || r.accepted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accepted ? _green.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accepted ? _green.withOpacity(0.4) : const Color(0xFFE2E2E6).withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 13, backgroundColor: _primary.withOpacity(0.15), child: Text(r.anonymous ? "?" : (r.authorName.isNotEmpty ? r.authorName[0].toUpperCase() : "?"), style: const TextStyle(fontSize: 11, color: _primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Flexible(child: Text(r.anonymous ? "Anonim" : "@${r.authorName}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.bold, color: _text))),
              if (expert != null) ...[const SizedBox(width: 6), ExpertBadge(type: expert, fontSize: 9)],
              const Spacer(),
              if (accepted) const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 14, color: _green), SizedBox(width: 3), Text("En iyi yanıt", style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: _green))]),
              if (globalIsAdmin)
                InkWell(onTap: () async { await CommunitySync.instance.deleteReply(widget.post.id, r.id); _loadReplies(); }, child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.delete_outline, size: 16, color: _danger))),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.body, style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF3D3D4A), height: 1.45)),
          if (_canModerate && !accepted) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _accept(r),
                icon: const Icon(Icons.check_circle_outline, size: 15, color: _green),
                label: const Text("En iyi yanıt seç", style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0), minimumSize: const Size(0, 28)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _replyComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEDEDED)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Yanıt yaz...",
                    hintStyle: const TextStyle(color: _light, fontSize: 14),
                    filled: true,
                    fillColor: _bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _sending
                  ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _primary)))
                  : IconButton(onPressed: _sendReply, icon: const Icon(Icons.send_rounded, color: _primary)),
            ],
          ),
          Row(
            children: [
              Checkbox(value: _replyAnon, activeColor: _primary, visualDensity: VisualDensity.compact, onChanged: (v) => setState(() => _replyAnon = v ?? false)),
              const Text("Anonim yanıtla", style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _light)),
            ],
          ),
        ],
      ),
    );
  }
}
