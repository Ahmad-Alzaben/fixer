import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:fixer/core/widgets/money_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies the money input formatters as if the user typed [typed]
/// into a field that contained [before].
String typeInto(String before, String typed, Currency currency) {
  var value = TextEditingValue(text: before);
  final next = TextEditingValue(text: typed);
  for (final f in moneyInputFormatters(currency)) {
    value = f.formatEditUpdate(value, next);
  }
  return value.text;
}

void main() {
  group('Money.parse upper limit', () {
    test('accepts up to 999,999,999 in the major unit', () {
      expect(
        Money.parse('999999999.999', Currency.jod).minorUnits,
        999999999999,
      );
    });

    test('rejects amounts over the limit instead of overflowing', () {
      expect(
        () => Money.parse('1000000000', Currency.jod),
        throwsFormatException,
      );
      expect(
        () => Money.parse('99999999999999999999999', Currency.jod),
        throwsFormatException,
      );
    });
  });

  group('money input field', () {
    test('accepts digits with up to the currency\'s decimals', () {
      expect(typeInto('', '12.345', Currency.jod), '12.345');
      expect(typeInto('12.34', '12.345', Currency.usd), '12.34');
      expect(typeInto('12', '12.5', Currency.jpy), '12');
    });

    test('stops at 9 digits before the decimal point', () {
      expect(typeInto('123456789', '1234567890', Currency.jod), '123456789');
      expect(typeInto('', '123456789.5', Currency.jod), '123456789.5');
    });

    test('ignores minus signs, letters and a second decimal point', () {
      expect(typeInto('', '-1', Currency.jod), '');
      expect(typeInto('1', '1a', Currency.jod), '1');
      expect(typeInto('1.2', '1.2.', Currency.jod), '1.2');
    });
  });
}
