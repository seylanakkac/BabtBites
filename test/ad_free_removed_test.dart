import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:babybites/data/extras_store.dart';
import 'package:babybites/services/ad_free.dart';
import 'package:babybites/services/storage_service.dart';

/// Reklamsız dönemin TAMAMEN kaldırıldığını kilitler.
///
/// Reklamsız hak veren iki sistem de silindi (kurucu üye hediyesi ve ödüllü
/// reklamın 1 günlük penceresi). Geriye iki güvence kaldı:
///   • adFreeActive() her koşulda false — eski/bulut kayıtları reklamları
///     gizleyemez,
///   • revokeAllAdFree() kalmış değeri geçmiş tarihle ezip buluta yazar.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    globalAdFreeUntil = null;
  });

  group('adFreeActive her zaman false', () {
    test('90 günlük hediye duruyor olsa bile', () {
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
      expect(adFreeActive(), isFalse);
    });

    test('ödüllü reklamdan gelen 1 günlük pencerede bile', () {
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      expect(adFreeActive(), isFalse);
    });

    test('hiç değer yokken', () {
      expect(adFreeActive(), isFalse);
    });
  });

  group('revokeAllAdFree', () {
    test('uzun hediyeyi temizler', () async {
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
      expect(await revokeAllAdFree(), isTrue);
      expect(adFreeActive(), isFalse);
    });

    test('ödüllü reklamdan geleni de temizler (artık korunmuyor)', () async {
      // Eski davranış 1 günlük hakkı KORUYORDU; kullanıcı "reklamsız özelliği
      // hiçbir kullanıcıda olmasın" dediği için o ayrım kaldırıldı.
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      expect(await revokeAllAdFree(), isTrue);
      expect(globalAdFreeUntil, kAdFreeRevokedMarker);
    });

    test('temizlenen değer null DEĞİL, geçmiş tarihle işaretlenir', () async {
      // null yapmak prefs anahtarını siliyor; exportUserData onu buluta hiç
      // göndermiyor ve merge'li push Firestore'daki eski tarihe dokunmuyor.
      // Sonuç: bir sonraki pull hakkı geri getiriyordu.
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
      await revokeAllAdFree();

      expect(globalAdFreeUntil, isNotNull, reason: 'buluta gidebilmesi için alan dolu kalmalı');
      expect(DateTime.parse(globalAdFreeUntil!).isBefore(DateTime.now()), isTrue);
    });

    test('işaret prefs\'e yazılıyor (yani buluta da gidecek)', () async {
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
      await revokeAllAdFree();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ad_free_until'), globalAdFreeUntil,
          reason: 'anahtar silinirse buluta gitmez');
    });

    test('hiç hak yoksa dokunmaz', () async {
      expect(await revokeAllAdFree(), isFalse);
      expect(globalAdFreeUntil, isNull);
    });

    test('ikinci çalıştırmada bir şey yapmaz (idempotent)', () async {
      globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
      expect(await revokeAllAdFree(), isTrue);
      expect(await revokeAllAdFree(), isFalse);
    });

    test('bozuk tarih de temizlenir', () async {
      globalAdFreeUntil = "bozuk-tarih";
      expect(await revokeAllAdFree(), isTrue);
      expect(globalAdFreeUntil, kAdFreeRevokedMarker);
    });
  });
}
