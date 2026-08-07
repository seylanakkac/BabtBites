import '../data/extras_store.dart';
import 'storage_service.dart';

/// Reklamsız kullanım hakkının TAMAMEN kaldırılması.
///
/// Reklamsız dönem artık hiçbir kullanıcıda olmamalı: ne kurucu üye hediyesi
/// (o sistem tamamen kaldırıldı) ne de ödüllü reklamla kazanılan 1 günlük
/// pencere. Reklamlar uygulamanın tek gelir kaynağı ve sessizce gizlenmeleri
/// "reklamlar görünmüyor" şikâyetinin sebebiydi.
///
/// Bu temizlik AÇILIŞTA iki kez çalışır:
///   1. main.dart — yerel kayıt yüklendikten hemen sonra,
///   2. splash_screen.dart — CloudSync.pull()'DAN SONRA, çünkü pull bulutta
///      duran eski tarihi yerel kayda geri yazabiliyor.
///
/// Bir şey temizlendiyse true döner.
Future<bool> revokeAllAdFree() async {
  final raw = globalAdFreeUntil;
  if (raw == null || raw == kAdFreeRevokedMarker) return false;
  // Geçmiş tarih ("mezar taşı") yazılır, null DEĞİL — bkz. clearAdFreeUntil'in
  // açıklaması: null, prefs anahtarını silip bulut temizliğini engelliyordu.
  clearAdFreeUntil();
  await StorageService.instance.saveExtras();
  return true;
}
