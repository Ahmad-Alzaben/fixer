import 'package:flutter/painting.dart';

/// The selectable accent colors. Neon tones on a near-black base,
/// inspired by a cyberpunk HUD.
enum AppAccent {
  neonYellow('Neon Yellow', Color(0xFFFCEE0A)),
  electricCyan('Electric Cyan', Color(0xFF00F0FF)),
  hotRed('Hot Red', Color(0xFFFF003C)),
  netrunnerMagenta('Netrunner Magenta', Color(0xFFFF2BD6)),
  acidGreen('Acid Green', Color(0xFF39FF14));

  const AppAccent(this.label, this.color);

  final String label;
  final Color color;

  /// Text/icon color used on top of [color]. Near-black works on every
  /// preset (checked by tests to meet WCAG AA 4.5:1).
  Color get onColor => const Color(0xFF0A0A0F);

  static const fallback = neonYellow;

  static AppAccent fromName(String? name) => AppAccent.values.firstWhere(
    (a) => a.name == name,
    orElse: () => fallback,
  );
}

/// WCAG contrast ratio between two colors (1.0 to 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
