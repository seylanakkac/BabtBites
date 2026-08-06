import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Son paylaşım denemesinin hatası (arayüzde gösterilebilsin diye).
///
/// Eskiden hatalar sessizce yutuluyordu: görsel paylaşımı başarısız olunca kod
/// sessizce bağlantı paylaşımına düşüyordu ve kullanıcı "Instagram'a gitmiyor"
/// diyordu — ama sebebi ne o görebiliyordu ne biz.
String? lastShareError;

/// Mobil (Android/iOS): metin/link paylaşımı native paylaşım sayfasıyla.
Future<bool> shareViaWebShareApi({String? title, String? text, String? url}) async {
  lastShareError = null;
  try {
    final msg = [text, url].where((e) => e != null && e.isNotEmpty).join('\n');
    if (msg.isEmpty) return false;
    // sharePositionOrigin iPad'de ZORUNLU (aşağıdaki nota bak).
    await Share.share(msg, subject: title, sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1));
    return true;
  } catch (e) {
    lastShareError = e.toString();
    debugPrint('shareViaWebShareApi failed: $e');
    return false;
  }
}

/// Mobil (Android/iOS): görseli (PNG byte'ları) native paylaşım sayfası ile
/// paylaşır (Instagram, WhatsApp vb.). Geçici dosyaya yazıp paylaşır.
Future<bool> shareImageViaWebShareApi(Uint8List bytes,
    {String text = '', String filename = 'babybites.png'}) async {
  lastShareError = null;
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    // Metin boşsa hiç gönderme (URL'li metin Instagram'ı DM/link moduna sokuyor;
    // sadece görsel paylaşınca "Hikayene Ekle" seçeneği çıkar).
    //
    // mimeType AÇIKÇA veriliyor: bazı iOS sürümlerinde uzantıdan tür
    // çıkarılamayınca Instagram paylaşım sayfasında hedef olarak görünmüyor.
    //
    // sharePositionOrigin iPad'de ZORUNLU: verilmezse UIActivityViewController
    // çıpa bulamayıp hata fırlatıyor ve paylaşım hiç açılmıyor. iPhone'da yok
    // sayılıyor, bu yüzden koşulsuz veriliyor.
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: text.isEmpty ? null : text,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
    return true;
  } catch (e) {
    lastShareError = e.toString();
    debugPrint('shareImageViaWebShareApi failed: $e');
    return false;
  }
}

/// Görseli DOĞRUDAN cihazın fotoğraf galerisine kaydeder.
///
/// Paylaşım sayfasına güvenmek yeterli değildi: Instagram bazı cihazlarda
/// hedef olarak hiç görünmüyor ve kullanıcının elinde hiçbir şey kalmıyordu.
/// Galeriye kaydedince kullanıcı Instagram'ı kendi açıp hikayeye ekleyebilir —
/// bu yol her zaman çalışır.
///
/// iOS'ta Info.plist'e NSPhotoLibraryAddUsageDescription gerekir; izin
/// verilmezse false döner (çağıran taraf paylaşıma düşer).
Future<bool> saveImageToGallery(Uint8List bytes, {String filename = 'babybites.png'}) async {
  lastShareError = null;
  try {
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) {
        lastShareError = 'Fotoğraflara erişim izni verilmedi';
        return false;
      }
    }
    await Gal.putImageBytes(bytes, album: 'BabyBites', name: filename.replaceAll('.png', ''));
    return true;
  } catch (e) {
    lastShareError = e.toString();
    debugPrint('saveImageToGallery failed: $e');
    return false;
  }
}

/// Mobilde "indir" = galeriye kaydet.
Future<bool> downloadImage(Uint8List bytes, {String filename = 'babybites.png'}) =>
    saveImageToGallery(bytes, filename: filename);

String _ytId(String url) {
  final m = RegExp(r'(?:youtu\.be/|v=|embed/|shorts/|live/)([A-Za-z0-9_-]{6,})').firstMatch(url.trim());
  return m != null ? m.group(1)! : '';
}

/// Mobil (Android/iOS): makale/tarif videosu. YouTube küçük resmi + oynat
/// düğmesi; dokununca videoyu YouTube uygulaması/tarayıcıda açar.
Widget mediaEmbed({required bool youtube, required String url, double aspectRatio = 16 / 9}) {
  final id = youtube ? _ytId(url) : '';
  Future<void> open() async {
    final u = Uri.tryParse(url.trim());
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  return AspectRatio(
    aspectRatio: aspectRatio,
    child: GestureDetector(
      onTap: open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (youtube && id.isNotEmpty)
              Image.network(
                'https://img.youtube.com/vi/$id/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1C1C28)),
              )
            else
              Container(color: const Color(0xFF1C1C28)),
            Container(color: Colors.black.withOpacity(0.28)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, size: 34, color: Color(0xFFFF7A45)),
                  ),
                  const SizedBox(height: 8),
                  const Text("Videoyu İzle", style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
