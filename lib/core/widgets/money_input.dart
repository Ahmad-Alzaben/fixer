import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/money/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard for amounts: digits and one decimal point.
const moneyKeyboard = TextInputType.numberWithOptions(decimal: true);

/// Only lets the user type a non-negative amount with at most the
/// currency's number of decimals (e.g. 3 for JOD).
List<TextInputFormatter> moneyInputFormatters(Currency currency) {
  const whole = '\\d{0,${Money.maxWholeDigits}}';
  final pattern = currency.minorDigits == 0
      ? RegExp('^$whole\$')
      : RegExp('^$whole(\\.\\d{0,${currency.minorDigits}})?\$');
  return [
    TextInputFormatter.withFunction(
      (oldValue, newValue) =>
          pattern.hasMatch(newValue.text) ? newValue : oldValue,
    ),
  ];
}

/// Hint like "0.000" for the currency's precision.
String moneyHint(Currency currency) =>
    currency.minorDigits == 0 ? '0' : '0.${'0' * currency.minorDigits}';

/// Keeps keyboard open after submit (default behaviour would unfocus).
void keepFocus() {}

/// Convenience to refocus a field after the frame (e.g. after a rebuild).
void refocus(FocusNode node) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
