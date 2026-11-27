// Deep links that open WhatsApp or the SMS app with a message prefilled.
// The user still taps Send in that app; nothing is sent automatically.
//
// Text is percent-encoded with `Uri.encodeComponent`, so spaces become
// `%20` (some SMS apps would show `+` literally).

/// [internationalDigits] like `962791234567` (see `normalizePhone`), or null
/// to let the user choose the chat in WhatsApp.
Uri whatsappUri(String? internationalDigits, String text) => Uri.parse(
  'https://wa.me/${internationalDigits ?? ''}'
  '?text=${Uri.encodeComponent(text)}',
);

/// [phone] as stored (e.g. `+962791234567`), or null to pick a recipient
/// in the SMS app.
Uri smsUri(String? phone, String text) =>
    Uri.parse('sms:${phone ?? ''}?body=${Uri.encodeComponent(text)}');
