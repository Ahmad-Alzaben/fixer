import 'package:fixer/features/messaging/domain/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone (default country 962, Jordan)', () {
    const cases = {
      '+962 79 123 4567': '962791234567',
      '00962791234567': '962791234567',
      '0791234567': '962791234567',
      '(079) 123-4567': '962791234567',
      '962791234567': '962791234567',
      '+1 (555) 123-4567': '15551234567',
      '791234567': '962791234567',
    };
    cases.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(normalizePhone(input), expected);
      });
    });

    test('uses another default country code when given', () {
      expect(
        normalizePhone('0501234567', defaultCountryCode: '966'),
        '966501234567',
      );
    });

    test('returns null when there are too few digits', () {
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('abc'), isNull);
      expect(normalizePhone('12'), isNull);
    });
  });
}
