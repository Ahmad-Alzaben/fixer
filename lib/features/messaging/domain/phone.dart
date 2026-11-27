/// Converts a phone number as saved in contacts into international digits
/// (no `+`), as WhatsApp's `wa.me` links require.
///
/// - `+962 79...` / `00962 79...` -> `96279...`
/// - `079...` (local, trunk 0) -> default country code + `79...`
/// - already starting with the default country code -> kept
/// Returns null when fewer than 7 digits remain.
String? normalizePhone(String raw, {String defaultCountryCode = '962'}) {
  final trimmed = raw.trim();
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return null;

  if (trimmed.startsWith('+')) return digits;
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith(defaultCountryCode)) return digits;
  if (digits.startsWith('0')) digits = digits.substring(1);
  return '$defaultCountryCode$digits';
}
