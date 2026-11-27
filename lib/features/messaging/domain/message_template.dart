/// A saved message the user sends to each person with their share.
///
/// Supported placeholders: `{name}`, `{amount}`, `{items}`, `{billTotal}`,
/// `{title}`, `{date}`. Unknown placeholders are left as typed.
class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String body;

  /// Exactly one saved template should be the default; it is preselected
  /// whenever a message is sent.
  final bool isDefault;

  static const builtIn = MessageTemplate(
    id: 'builtin',
    name: 'Default',
    body: 'Hi {name}, your share of {title} is {amount}.\n{items}',
    isDefault: true,
  );

  static final _placeholder = RegExp(r'\{(\w+)\}');

  /// Fills placeholders in a single pass, so text inside values is never
  /// expanded again.
  String render(Map<String, String> values) => body.replaceAllMapped(
    _placeholder,
    (m) => values[m.group(1)!] ?? m.group(0)!,
  );

  /// The template marked default, else the first one, else [builtIn].
  static MessageTemplate pickDefault(List<MessageTemplate> templates) {
    for (final t in templates) {
      if (t.isDefault) return t;
    }
    return templates.isEmpty ? builtIn : templates.first;
  }
}
