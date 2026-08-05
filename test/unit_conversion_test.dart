import 'package:flutter_test/flutter_test.dart';
import 'package:babybites/data/unit_conversion.dart';

void main() {
  group('parseQuantity', () {
    test('duz sayilar', () {
      expect(parseQuantity('100'), 100);
      expect(parseQuantity('0.5'), 0.5);
      expect(parseQuantity('1,5'), 1.5);
    });
    test('kesirler', () {
      expect(parseQuantity('1/2'), 0.5);
      expect(parseQuantity('3/4'), 0.75);
      expect(parseQuantity('1 1/2'), 1.5);
    });
    test('sozel olculer', () {
      expect(parseQuantity('yarım'), 0.5);
      expect(parseQuantity('yarim'), 0.5);
      expect(parseQuantity('Yarım su bardağı'), 0.5);
      expect(parseQuantity('çeyrek'), 0.25);
      expect(parseQuantity('ceyrek elma'), 0.25);
      expect(parseQuantity('1 buçuk'), 1.5);
      expect(parseQuantity('2 bucuk'), 2.5);
      expect(parseQuantity('bir buçuk'), 1.5);
    });
    test('aralik', () {
      expect(parseQuantity('2-3'), 2.5);
    });
    test('bos / cozulemeyen', () {
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('biraz'), isNull);
    });
  });
}
