/// Tax rates are whole basis points: 1600 = 16%, 750 = 7.5%. No doubles.
const maxTaxRate = 10000;

final _percentPattern = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$');

/// Parses a percentage such as `"16"` or `"7.5"` into basis points.
///
/// Throws [FormatException] for blank, negative, more than 2 decimals, or
/// more than 100%.
int parseTaxPercent(String input) {
  final match = _percentPattern.firstMatch(input.trim());
  if (match == null) throw FormatException('Not a valid percentage', input);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final rate = int.parse(match.group(1)!) * 100 + int.parse(fraction);
  if (rate > maxTaxRate) throw FormatException('More than 100%', input);
  return rate;
}

/// `1600` → `"16"`, `750` → `"7.5"`, `5` → `"0.05"`.
String formatTaxPercent(int rate) {
  final whole = rate ~/ 100;
  final fraction = (rate % 100).toString().padLeft(2, '0');
  if (fraction == '00') return '$whole';
  return '$whole.${fraction.replaceFirst(RegExp(r'0$'), '')}';
}
