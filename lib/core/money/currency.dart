/// An ISO 4217 currency and its minor-unit precision.
class Currency {
  const Currency._(this.code, this.minorDigits);

  final String code;

  /// Number of decimal digits in the minor unit (JOD = 3 fils digits).
  final int minorDigits;

  static const jod = Currency._('JOD', 3);
  static const usd = Currency._('USD', 2);
  static const eur = Currency._('EUR', 2);
  static const sar = Currency._('SAR', 2);
  static const aed = Currency._('AED', 2);
  static const kwd = Currency._('KWD', 3);
  static const jpy = Currency._('JPY', 0);

  static const defaultCurrency = jod;

  static const supported = [jod, usd, eur, sar, aed, kwd, jpy];

  static Currency? byCode(String code) {
    final upper = code.toUpperCase();
    for (final c in supported) {
      if (c.code == upper) return c;
    }
    return null;
  }

  /// 10^minorDigits: how many minor units make one major unit.
  int get minorPerMajor {
    var result = 1;
    for (var i = 0; i < minorDigits; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  String toString() => code;
}
