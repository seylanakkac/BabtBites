// YouTube link yardımcıları (saf Dart — UI yok).

/// URL'den 11 karakterlik YouTube video ID'sini çıkarır.
/// Destekler: watch?v=, youtu.be/, shorts/, embed/, live/ ve düz ID.
String? youtubeId(String url) {
  final u = url.trim();
  if (u.isEmpty) return null;
  final patterns = <RegExp>[
    RegExp(r'youtube\.com/watch\?[^\s]*v=([A-Za-z0-9_-]{11})'),
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/live/([A-Za-z0-9_-]{11})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(u);
    if (m != null) return m.group(1);
  }
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(u)) return u;
  return null;
}

/// Geçerli bir YouTube linki mi?
bool isYoutubeUrl(String url) => youtubeId(url) != null;

/// Dikey (Shorts) link mi?
bool isShorts(String url) => url.contains('/shorts/');
