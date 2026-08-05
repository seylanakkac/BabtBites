import 'package:flutter_test/flutter_test.dart';
import 'package:babybites/data/search_text.dart';

void main() {
  group('Turkce arama', () {
    test('I / i sorunu (bildirilen hata)', () {
      // Veritabaninda "Ispanak" kayitli.
      expect(searchMatches('Ispanak', 'ıspanak'), isTrue);
      expect(searchMatches('Ispanak', 'Ispanak'), isTrue);
      expect(searchMatches('Ispanak', 'ISPANAK'), isTrue);
      expect(searchMatches('Ispanak', 'ispanak'), isTrue);
      expect(searchMatches('Ispanak', 'span'), isTrue);
    });
    test('diger Turkce harfler', () {
      expect(searchMatches('Çilek', 'cilek'), isTrue);
      expect(searchMatches('Yoğurt', 'yogurt'), isTrue);
      expect(searchMatches('Şeftali', 'seftali'), isTrue);
      expect(searchMatches('Üzüm', 'uzum'), isTrue);
      expect(searchMatches('Böğürtlen', 'bogurtlen'), isTrue);
    });
    test('eslesmeyen', () {
      expect(searchMatches('Ispanak', 'elma'), isFalse);
      expect(searchMatches('Elma', 'armut'), isFalse);
    });
    test('bos arama her seyi getirir', () {
      expect(searchMatches('Ispanak', ''), isTrue);
    });
  });
}
