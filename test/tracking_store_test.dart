import 'package:flutter_test/flutter_test.dart';

import 'package:babybites/data/tracking_store.dart';

void main() {
  setUp(() {
    globalDailyLogs.clear();
    globalBabyFoodStates.clear();
    globalBabyRecipeTastes.clear();
  });

  group('dailyLog liste kimliği', () {
    // Asıl hata: dailyLog() her çağrıldığında listeleri yeniden üretiyordu.
    // "Beslenme Ekle" penceresi açıkken araya bir yeniden çizim girince eldeki
    // liste öksüz kalıyor, Kaydet hiçbir yere yazmıyordu.
    test('art arda çağrılarda aynı liste nesnesi döner', () {
      final first = dailyLog('b1', '2026-08-05');
      final feeds1 = first['feeds'];
      final cis1 = first['cisList'];
      final kaka1 = first['kakaList'];

      final second = dailyLog('b1', '2026-08-05');

      expect(identical(second['feeds'], feeds1), isTrue);
      expect(identical(second['cisList'], cis1), isTrue);
      expect(identical(second['kakaList'], kaka1), isTrue);
    });

    test('elde tutulan listeye eklenen kayıt araya çağrı girse de görünür', () {
      final held = feedsFor('b1', '2026-08-05');
      dailyLog('b1', '2026-08-05'); // pencere açıkken gelen yeniden çizim
      held.add({'type': 'sagilmis', 'amount': '90', 'unit': 'ml'});

      expect(feedsFor('b1', '2026-08-05'), hasLength(1));
      expect(feedsFor('b1', '2026-08-05').first['amount'], '90');
    });

    test('diskten gelen List<dynamic> bir kez normalleştirilir', () {
      globalDailyLogs['b1'] = {
        '2026-08-05': <String, dynamic>{
          'feeds': <dynamic>[
            {'type': 'formul', 'amount': '120'},
          ],
        },
      };

      final normalised = dailyLog('b1', '2026-08-05')['feeds'];
      expect(normalised, isA<List<Map<String, dynamic>>>());
      // İkinci çağrı artık dokunmamalı.
      expect(identical(dailyLog('b1', '2026-08-05')['feeds'], normalised), isTrue);
    });

    test('eski int sayaçlı kayıtlar hâlâ listeye çevriliyor', () {
      globalDailyLogs['b1'] = {
        '2026-08-05': <String, dynamic>{'cis': 3, 'kaka': 2},
      };
      final log = dailyLog('b1', '2026-08-05');
      expect(log['cisList'], hasLength(3));
      expect(log['kakaList'], hasLength(2));
      expect((log['cisList'] as List).first['color'], 'orta');
    });
  });

  group('öğün tamamlama durumu', () {
    test('yaz / oku / temizle', () {
      expect(mealStatus('b1', '2026-08-05', 'Kahvaltı'), isNull);

      setMealStatus('b1', '2026-08-05', 'Kahvaltı', 'hepsi');
      expect(mealStatus('b1', '2026-08-05', 'Kahvaltı'), 'hepsi');
      expect(mealStatusLabel('hepsi'), 'Hepsini yedi');
      expect(mealStatusEmoji('hepsi'), '😋');

      // Aynı çipe yeniden dokunmak işareti kaldırır.
      setMealStatus('b1', '2026-08-05', 'Kahvaltı', null);
      expect(mealStatus('b1', '2026-08-05', 'Kahvaltı'), isNull);
    });

    test('öğünler ve günler birbirine karışmaz', () {
      setMealStatus('b1', '2026-08-05', 'Kahvaltı', 'hepsi');
      setMealStatus('b1', '2026-08-05', 'Öğle', 'yemedi');
      setMealStatus('b1', '2026-08-06', 'Kahvaltı', 'tadi');

      expect(mealStatus('b1', '2026-08-05', 'Kahvaltı'), 'hepsi');
      expect(mealStatus('b1', '2026-08-05', 'Öğle'), 'yemedi');
      expect(mealStatus('b1', '2026-08-06', 'Kahvaltı'), 'tadi');
      expect(mealStatus('b2', '2026-08-05', 'Kahvaltı'), isNull);
    });
  });

  group('öğün saati', () {
    test('yaz / oku / temizle', () {
      expect(mealTime('b1', '2026-08-05', 'Kahvaltı'), isNull);
      setMealTime('b1', '2026-08-05', 'Kahvaltı', '08:30');
      expect(mealTime('b1', '2026-08-05', 'Kahvaltı'), '08:30');
      setMealTime('b1', '2026-08-05', 'Kahvaltı', null);
      expect(mealTime('b1', '2026-08-05', 'Kahvaltı'), isNull);
    });

    test('durum ve saat birbirini ezmez', () {
      setMealStatus('b1', '2026-08-05', 'Öğle', 'biraz');
      setMealTime('b1', '2026-08-05', 'Öğle', '12:15');
      expect(mealStatus('b1', '2026-08-05', 'Öğle'), 'biraz');
      expect(mealTime('b1', '2026-08-05', 'Öğle'), '12:15');
    });
  });

  group('takviye / ilaç verilişleri', () {
    test('birden çok doz saatiyle kaydedilir', () {
      addDose('b1', '2026-08-05', 'med1', {'time': '08:00', 'remindAt': null, 'notifId': null});
      addDose('b1', '2026-08-05', 'med1', {'time': '14:00', 'remindAt': null, 'notifId': null});

      final doses = dosesFor('b1', '2026-08-05', 'med1');
      expect(doses, hasLength(2));
      expect(doses.map((d) => d['time']), ['08:00', '14:00']);
      expect(doseTakenToday('b1', '2026-08-05', 'med1'), isTrue);
    });

    test('doz listesi canlı — kimlik sabit kalır', () {
      final held = dosesFor('b1', '2026-08-05', 'med1');
      dailyLog('b1', '2026-08-05'); // araya giren yeniden çizim
      held.add({'time': '09:00'});
      expect(dosesFor('b1', '2026-08-05', 'med1'), hasLength(1));
    });

    test('silme bildirim kimliğini döner ve son dozda taken false olur', () {
      addDose('b1', '2026-08-05', 'med1', {'time': '08:00', 'notifId': 4242});
      expect(doseTakenToday('b1', '2026-08-05', 'med1'), isTrue);

      final notifId = removeDose('b1', '2026-08-05', 'med1', 0);
      expect(notifId, 4242);
      expect(dosesFor('b1', '2026-08-05', 'med1'), isEmpty);
      expect(doseTakenToday('b1', '2026-08-05', 'med1'), isFalse);
    });

    test('geçersiz indeks güvenle yok sayılır', () {
      expect(removeDose('b1', '2026-08-05', 'med1', 0), isNull);
      expect(removeDose('b1', '2026-08-05', 'med1', -1), isNull);
    });

    test('saatsiz eski kayıtlar (taken bayrağı) hâlâ verildi sayılır', () {
      globalDailyLogs['b1'] = {
        '2026-08-05': <String, dynamic>{
          'taken': {'med1': true},
        },
      };
      expect(dosesFor('b1', '2026-08-05', 'med1'), isEmpty);
      expect(doseTakenToday('b1', '2026-08-05', 'med1'), isTrue);
    });

    test('ilaçlar ve günler birbirine karışmaz', () {
      addDose('b1', '2026-08-05', 'med1', {'time': '08:00'});
      addDose('b1', '2026-08-06', 'med1', {'time': '09:00'});
      addDose('b1', '2026-08-05', 'med2', {'time': '10:00'});

      expect(dosesFor('b1', '2026-08-05', 'med1').single['time'], '08:00');
      expect(dosesFor('b1', '2026-08-06', 'med1').single['time'], '09:00');
      expect(dosesFor('b1', '2026-08-05', 'med2').single['time'], '10:00');
      expect(dosesFor('b2', '2026-08-05', 'med1'), isEmpty);
    });
  });

  group('veriliş zamanı göçü (labelToTime)', () {
    test('eski etiketler saate çevrilir', () {
      expect(labelToTime('Sabah'), '09:00');
      expect(labelToTime('Öğle'), '13:00');
      expect(labelToTime('Akşam'), '20:00');
      // Türkçe karakter kaybolmuş kayıtlar da tanınmalı.
      expect(labelToTime('ogle'), '13:00');
      expect(labelToTime('aksam'), '20:00');
    });

    test('zaten saat olanlar normalleştirilir', () {
      expect(labelToTime('09:00'), '09:00');
      expect(labelToTime('9:05'), '09:05');
      expect(labelToTime(' 21:30 '), '21:30');
    });

    test('geçersizler boş döner (atılır)', () {
      expect(labelToTime(''), '');
      expect(labelToTime('bilinmeyen'), '');
      expect(labelToTime('25:00'), '');
      expect(labelToTime('10:75'), '');
    });
  });

  group('plannedMedReminders', () {
    setUp(globalBabyMeds.clear);

    test('aktif + hatırlatmalı ilaçların her saati için kayıt üretir', () {
      globalBabyMeds['b1'] = [
        {
          'id': 'm1', 'name': 'Demir Damlası', 'dose': '1,5 ml',
          'active': true, 'reminder': true, 'times': ['09:00', '21:00'],
        },
      ];
      final planned = plannedMedReminders();
      expect(planned, hasLength(2));
      expect(planned.map((p) => p.time), containsAll(['09:00', '21:00']));
      expect(planned.first.title, contains('Demir Damlası'));
      expect(planned.first.body, contains('1,5 ml'));
    });

    test('eski etiketli saatler de plana girer', () {
      globalBabyMeds['b1'] = [
        {'id': 'm1', 'name': 'D Vitamini', 'active': true, 'reminder': true, 'times': ['Sabah']},
      ];
      expect(plannedMedReminders().single.time, '09:00');
    });

    test('pasif, hatırlatmasız ve saatsizler dışarıda kalır', () {
      globalBabyMeds['b1'] = [
        {'id': 'm1', 'name': 'A', 'active': false, 'reminder': true, 'times': ['09:00']},
        {'id': 'm2', 'name': 'B', 'active': true, 'reminder': false, 'times': ['09:00']},
        {'id': 'm3', 'name': 'C', 'active': true, 'reminder': true, 'times': []},
        {'id': 'm4', 'name': 'D', 'active': true, 'reminder': true, 'times': ['bilinmeyen']},
      ];
      expect(plannedMedReminders(), isEmpty);
    });

    test('birden çok bebeğin ilaçları birlikte döner', () {
      globalBabyMeds['b1'] = [
        {'id': 'm1', 'name': 'A', 'active': true, 'reminder': true, 'times': ['09:00']},
      ];
      globalBabyMeds['b2'] = [
        {'id': 'm2', 'name': 'B', 'active': true, 'reminder': true, 'times': ['10:00']},
      ];
      expect(plannedMedReminders(), hasLength(2));
    });
  });

  group('sevdi / sevmedi', () {
    test('gıda beğenisi bebek başına tutulur', () {
      setFoodTaste('b1', 'Elma', 'sevdi');
      setFoodTaste('b2', 'Elma', 'sevmedi');

      expect(foodTaste('b1', 'Elma'), 'sevdi');
      expect(foodTaste('b2', 'Elma'), 'sevmedi');
      expect(likedFoodNames('b1'), {'Elma'});
      expect(likedFoodNames('b2'), isEmpty);
    });

    test('gıda beğenisi kaldırılınca diğer alanlar korunur', () {
      final st = ensureFoodState('b1', 'Elma');
      st['tried'] = true;
      setFoodTaste('b1', 'Elma', 'sevdi');
      setFoodTaste('b1', 'Elma', null);

      expect(foodTaste('b1', 'Elma'), isNull);
      expect(isTried('b1', 'Elma'), isTrue); // "denendi" silinmemeli
    });

    test('tarif beğenisi bebek başına tutulur', () {
      setRecipeTaste('b1', 'r_1', 'sevdi');
      setRecipeTaste('b1', 'r_2', 'sevmedi');

      expect(likedRecipeIds('b1'), {'r_1'});
      expect(recipeTaste('b1', 'r_2'), 'sevmedi');
      expect(recipeTaste('b2', 'r_1'), isNull);

      setRecipeTaste('b1', 'r_1', null);
      expect(likedRecipeIds('b1'), isEmpty);
    });

    test('etiket ve emoji eşlemesi', () {
      expect(tasteLabel('sevdi'), 'Sevdi');
      expect(tasteEmoji('sevmedi'), '😖');
      expect(tasteLabel(null), '');
    });
  });
}
