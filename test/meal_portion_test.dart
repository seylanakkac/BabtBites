import 'package:flutter_test/flutter_test.dart';

import 'package:babybites/data/tracking_store.dart';

/// Öğün planındaki miktar (porsiyon / gram) mantığı.
///
/// Bu sistemden ÖNCE besin hesabı miktarı hiç dikkate almıyordu:
/// plana eklenen her gıda 100 g, her tarif tam 1 porsiyon sayılıyordu.
/// Testler hem varsayılanları hem de miktarın kaydedilmesini kilitliyor.
void main() {
  setUp(globalMealPortions.clear);

  const day = '2026-08-07';
  const meal = 'Kahvaltı';

  group('varsayılanlar', () {
    test('kayıt yoksa gıda 100 g sayılır', () {
      // Eski planların besin değerleri geriye dönük değişmesin diye
      // varsayılan, porsiyon sisteminden önceki örtük davranışla aynı.
      expect(mealPortion(day, meal, 'Brokoli', isRecipe: false), kDefaultFoodGrams);
      expect(kDefaultFoodGrams, 100.0);
    });

    test('kayıt yoksa tarif 1 porsiyon sayılır', () {
      expect(mealPortion(day, meal, 'Omlet', isRecipe: true), kDefaultRecipePortions);
      expect(kDefaultRecipePortions, 1.0);
    });
  });

  group('kaydetme', () {
    test('gram kaydedilir ve okunur', () {
      setMealPortion(day, meal, 'Brokoli', 30);
      expect(mealPortion(day, meal, 'Brokoli', isRecipe: false), 30);
    });

    test('yarım porsiyon kaydedilir', () {
      setMealPortion(day, meal, 'Omlet', 0.5);
      expect(mealPortion(day, meal, 'Omlet', isRecipe: true), 0.5);
    });

    test('sıfır ve negatif değer yok sayılır', () {
      setMealPortion(day, meal, 'Brokoli', 0);
      setMealPortion(day, meal, 'Brokoli', -5);
      expect(mealPortion(day, meal, 'Brokoli', isRecipe: false), kDefaultFoodGrams);
    });

    test('miktar öğüne özel — aynı gıda başka öğünde etkilenmez', () {
      setMealPortion(day, 'Kahvaltı', 'Brokoli', 30);
      expect(mealPortion(day, 'Akşam Yemeği', 'Brokoli', isRecipe: false), kDefaultFoodGrams);
    });

    test('miktar güne özel — ertesi gün etkilenmez', () {
      setMealPortion(day, meal, 'Brokoli', 30);
      expect(mealPortion('2026-08-08', meal, 'Brokoli', isRecipe: false), kDefaultFoodGrams);
    });
  });

  group('silme', () {
    test('kalem silinince miktarı da silinir', () {
      setMealPortion(day, meal, 'Brokoli', 30);
      removeMealPortion(day, meal, 'Brokoli');
      expect(mealPortion(day, meal, 'Brokoli', isRecipe: false), kDefaultFoodGrams);
    });

    test('olmayan kalemi silmek hata vermez', () {
      removeMealPortion(day, meal, 'Yok');
      expect(globalMealPortions[day]?[meal]?['Yok'], isNull);
    });
  });

  group('besin ölçeklemesi', () {
    // Ekranda uygulanan çarpan: gıda için gram/100, tarif için porsiyon.
    test('30 g gıda, 100 g değerinin 0.30 katı', () {
      setMealPortion(day, meal, 'Brokoli', 30);
      final grams = mealPortion(day, meal, 'Brokoli', isRecipe: false);
      expect(grams / 100.0, closeTo(0.30, 0.0001));
    });

    test('2 porsiyon tarif, tek porsiyonun 2 katı', () {
      setMealPortion(day, meal, 'Omlet', 2);
      expect(mealPortion(day, meal, 'Omlet', isRecipe: true), 2.0);
    });
  });
}
