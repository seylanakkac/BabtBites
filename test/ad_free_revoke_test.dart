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
    expect(globalAdFreeUntil, isNull);
    expect(adFreeActive(), isFalse);
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
    expect(globalAdFreeUntil, isNull);
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
    expect(globalAdFreeUntil, isNull);
  });

  test('geri alma tekrar çalıştırılabilir (ikinci kez bir şey yapmaz)', () async {
    globalAdFreeUntil = DateTime.now().add(const Duration(days: 90)).toIso8601String();
    expect(await FoundingMember.revokeGiftedAdFree(), isTrue);
    expect(await FoundingMember.revokeGiftedAdFree(), isFalse);
  });
}
