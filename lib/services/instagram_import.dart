import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/instagram_config.dart';

/// Instagram gönderisi (içe aktarma listesinde gösterilen sade hâli).
class InstagramPost {
  final String id;
  final String caption;
  final String mediaUrl;
  final String permalink;
  final String timestamp;

  const InstagramPost({
    required this.id,
    required this.caption,
    required this.mediaUrl,
    required this.permalink,
    required this.timestamp,
  });

  /// Açıklamanın ilk satırı — taslak tarife ad olarak önerilir.
  ///
  /// Instagram başlıkları genelde "Havuçlu Mücver 🥕\n\nMalzemeler:..."
  /// biçiminde; ilk satır neredeyse her zaman yemeğin adı oluyor.
  /// Hashtag'ler ve emojiler ayıklanıyor.
  String get suggestedTitle {
    final first = caption.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final noTags = first.replaceAll(RegExp(r'#\S+'), '');
    final cleaned = noTags.replaceAll(RegExp(r'[^\p{L}\p{N}\s.,()-]', unicode: true), '').trim();
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }
}

/// Instagram Graph API'den kendi gönderilerini çeker.
///
/// Yalnızca OKUMA yapar. Gönderiyi tarife çevirme işi admin panelinde,
/// insan eliyle yapılıyor (bkz. instagram_config.dart'taki gerekçe).
class InstagramImport {
  InstagramImport._();
  static final InstagramImport instance = InstagramImport._();

  /// Son hatanın okunabilir açıklaması (panelde gösteriliyor).
  String? lastError;

  /// Hesabın son [limit] gönderisi. Hata olursa boş liste döner ve
  /// [lastError] dolar.
  ///
  /// Jeton 60 günde bir yenilenmeli; süresi dolduğunda Graph API 190 kodlu
  /// hata veriyor ve bunu kullanıcıya açıkça yazıyoruz — aksi hâlde
  /// "liste boş geldi" gibi görünüp saatlerce yanlış yerde aranıyor.
  Future<List<InstagramPost>> fetchRecent({int limit = 25}) async {
    lastError = null;
    if (!instagramConfigured) {
      lastError = "Instagram bağlantısı yapılandırılmamış "
          "(lib/config/instagram_config.dart).";
      return const [];
    }
    final uri = Uri.https('graph.facebook.com', '/v21.0/$kInstagramUserId/media', {
      'fields': 'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp',
      'limit': '$limit',
      'access_token': kInstagramAccessToken,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) {
        final err = (body is Map ? body['error'] : null) as Map?;
        final code = err?['code'];
        lastError = code == 190
            ? "Erişim jetonunun süresi dolmuş. Yeni bir uzun ömürlü jeton alıp "
                "instagram_config.dart içine yazın."
            : "Instagram hatası: ${err?['message'] ?? res.statusCode}";
        return const [];
      }
      final data = (body as Map)['data'];
      if (data is! List) return const [];
      final out = <InstagramPost>[];
      for (final e in data) {
        if (e is! Map) continue;
        // VIDEO gönderilerinde media_url oynatma bağlantısı; kapak için
        // thumbnail_url kullanılıyor.
        final type = e['media_type']?.toString() ?? '';
        final url = (type == 'VIDEO' ? e['thumbnail_url'] : e['media_url'])?.toString() ?? '';
        if (url.isEmpty) continue;
        out.add(InstagramPost(
          id: e['id']?.toString() ?? '',
          caption: e['caption']?.toString() ?? '',
          mediaUrl: url,
          permalink: e['permalink']?.toString() ?? '',
          timestamp: e['timestamp']?.toString() ?? '',
        ));
      }
      return out;
    } catch (e) {
      debugPrint('InstagramImport.fetchRecent failed: $e');
      lastError = "Bağlantı kurulamadı: $e";
      return const [];
    }
  }
}
