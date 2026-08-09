import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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

  factory InstagramPost.fromMap(Map m) => InstagramPost(
        id: m['id']?.toString() ?? '',
        caption: m['caption']?.toString() ?? '',
        mediaUrl: m['mediaUrl']?.toString() ?? '',
        permalink: m['permalink']?.toString() ?? '',
        timestamp: m['timestamp']?.toString() ?? '',
      );

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

/// Instagram gönderilerini Cloud Function üzerinden çeker.
///
/// ⚠️ ERİŞİM JETONU İSTEMCİDE TUTULMAZ. İlk tasarımda jeton
/// `lib/config/instagram_config.dart` içindeydi; iki sızıntı yolu vardı:
///   1. Depo GitHub'da HERKESE AÇIK — jeton doğrudan yayınlanmış olurdu.
///   2. Açık olmasa bile sabit, uygulama paketine gömülür ve uygulamayı
///      indiren herkes ikili dosyadan çıkarabilir.
/// Jeton artık Firebase gizli anahtarı (INSTAGRAM_TOKEN) olarak yalnızca
/// fonksiyonun çalışma ortamında duruyor. Yönetici kontrolü de sunucuda
/// yapılıyor — istemcide gizlemek yeterli olmazdı, çağrı doğrudan da
/// yapılabilir.
class InstagramImport {
  InstagramImport._();
  static final InstagramImport instance = InstagramImport._();

  /// Son hatanın okunabilir açıklaması (panelde gösteriliyor).
  String? lastError;

  /// Hesabın son [limit] gönderisi. Hata olursa boş liste döner ve
  /// [lastError] dolar.
  Future<List<InstagramPost>> fetchRecent({int limit = 25}) async {
    lastError = null;
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('instagramMedia');
      final res = await fn.call<Map<String, dynamic>>({'limit': limit});
      final posts = res.data['posts'];
      if (posts is! List) return const [];
      return posts.whereType<Map>().map(InstagramPost.fromMap).toList();
    } on FirebaseFunctionsException catch (e) {
      // 'not-found' = instagramMedia fonksiyonu henüz yayınlanmadı.
      // Fonksiyon INSTAGRAM_TOKEN gizli anahtarına bağlı; anahtar
      // tanımlanmadan deploy edilemiyor, o yüzden özellik kurulana kadar
      // sunucuda hiç yok. Ham hata kodu yerine ne yapılacağını yazıyoruz.
      lastError = e.code == 'not-found'
          ? 'Instagram içe aktarma henüz kurulmadı.\n\n'
              'Gerekenler: Instagram hesabına bağlı bir Facebook sayfası, '
              'developers.facebook.com üzerinde bir uygulama ve uzun ömürlü '
              'erişim jetonu. Jeton sunucuda gizli anahtar olarak saklanır, '
              'uygulamaya girmez.'
          : (e.message ?? 'Instagram verisi alınamadı (${e.code}).');
      debugPrint('InstagramImport failed: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      lastError = 'Bağlantı kurulamadı: $e';
      debugPrint('InstagramImport failed: $e');
      return const [];
    }
  }
}
