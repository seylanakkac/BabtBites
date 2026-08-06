import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:babybites/data/extras_store.dart';
import 'package:babybites/services/founding_member.dart';
import 'package:babybites/services/storage_service.dart';

/// Kurucu üye hediyesiyle verilmiş reklamsız hakkın geri alınması.
///
/// Ayrım SÜREYE dayanıyor (hakkın kaynağı kaydedilmiyor): ödüllü reklam en
/// fazla 1 gün verebiliyor, dolayısıyla 2 günden uzak bir bitiş tarihi ancak
/// hediyeden gelmiş olabilir. Bu testler o sınırın iki yanını da kilitliyor.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
    globalAdFreeUntil = null;
  });

  test('90 günlük hediye geri alınır', () async {
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
    expect(adFreeActive(), isTrue);

    expect(await FoundingMember.revokeGiftedAdFree(), isTrue);
    expect(adFreeActive(), isFalse);
  });

  test('geri alınan hak null DEĞİL, geçmiş bir tarihle işaretlenir', () async {
    // null yapmak prefs anahtarını siliyor; exportUserData onu buluta hiç
    // göndermiyor ve merge'li push Firestore'daki eski tarihe dokunmuyor.
    // Sonuç: bir sonraki pull hakkı geri getiriyordu. Geçmiş tarih yazmak
    // alanın buluta gidip eski değeri EZMESİNİ sağlıyor.
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
    await FoundingMember.revokeGiftedAdFree();

    expect(globalAdFreeUntil, isNotNull, reason: 'buluta gidebilmesi için alan dolu kalmalı');
    final marker = DateTime.parse(globalAdFreeUntil!);
    expect(marker.isBefore(DateTime.now()), isTrue);
    expect(adFreeActive(), isFalse);
  });

  test('işaret prefs\'e yazılıyor (yani buluta da gidecek)', () async {
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
    await FoundingMember.revokeGiftedAdFree();

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('ad_free_until');
    expect(stored, isNotNull, reason: 'anahtar silinirse buluta gitmez');
    expect(stored, globalAdFreeUntil);
  });

  test('ödüllü reklamdan gelen 1 günlük hak KORUNUR', () async {
    final until = DateTime.now().add(const Duration(days: 1));
    globalAdFreeUntil = until.toIso8601String();

    expect(await FoundingMember.revokeGiftedAdFree(), isFalse);
    expect(globalAdFreeUntil, until.toIso8601String());
    expect(adFreeActive(), isTrue);
  });

  test('sınırın hemen ötesi (3 gün) geri alınır', () async {
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 3)).toIso8601String();
    expect(await FoundingMember.revokeGiftedAdFree(), isTrue);
    expect(adFreeActive(), isFalse);
  });

  test('hiç hak yoksa dokunmaz', () async {
    expect(await FoundingMember.revokeGiftedAdFree(), isFalse);
    expect(globalAdFreeUntil, isNull);
  });

  test('geçmişte kalmış hak (zaten etkisiz) korunur — kendiliğinden dolar', () async {
    final past = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
    globalAdFreeUntil = past;
    expect(adFreeActive(), isFalse);

    expect(await FoundingMember.revokeGiftedAdFree(), isFalse);
    expect(globalAdFreeUntil, past);
  });

  test('bozuk tarih temizlenir', () async {
    globalAdFreeUntil = "bozuk-tarih";
    expect(await FoundingMember.revokeGiftedAdFree(), isTrue);
    expect(adFreeActive(), isFalse);
  });

  test('geri alma tekrar çalıştırılabilir (ikinci kez bir şey yapmaz)', () async {
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
    expect(await FoundingMember.revokeGiftedAdFree(), isTrue);
    expect(await FoundingMember.revokeGiftedAdFree(), isFalse);
  });
}
