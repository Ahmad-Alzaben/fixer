import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageTemplate.render', () {
    const values = {
      'name': 'Omar',
      'amount': '2.396 JOD',
      'billTotal': '5.670 JOD',
      'title': 'Shawarma night',
      'date': '27 Nov 2026',
      'items': '- 3.000',
    };

    test('replaces every known placeholder', () {
      const t = MessageTemplate(
        id: 't',
        name: 'Friends',
        body:
            'Hey {name}! {title} on {date}: you owe {amount} '
            '(bill {billTotal})\n{items}',
      );
      expect(
        t.render(values),
        'Hey Omar! Shawarma night on 27 Nov 2026: you owe 2.396 JOD '
        '(bill 5.670 JOD)\n- 3.000',
      );
    });

    test('leaves unknown placeholders untouched', () {
      const t = MessageTemplate(id: 't', name: 'x', body: '{name} {iban}');
      expect(t.render(values), 'Omar {iban}');
    });

    test('does not re-expand placeholders that appear inside values', () {
      const t = MessageTemplate(id: 't', name: 'x', body: '{title}');
      expect(t.render({'title': '{name}', 'name': 'Omar'}), '{name}');
    });

    test('text before and after the amount is kept verbatim', () {
      const t = MessageTemplate(
        id: 't',
        name: 'x',
        body: 'Please send {amount} via CliQ. Thanks!',
      );
      expect(t.render(values), 'Please send 2.396 JOD via CliQ. Thanks!');
    });
  });

  group('MessageTemplate.pickDefault', () {
    const a = MessageTemplate(id: 'a', name: 'A', body: '');
    const b = MessageTemplate(id: 'b', name: 'B', body: '', isDefault: true);

    test('returns the template marked default', () {
      expect(MessageTemplate.pickDefault([a, b]).id, 'b');
    });

    test('falls back to the first template when none is marked', () {
      expect(MessageTemplate.pickDefault([a]).id, 'a');
    });

    test('falls back to the built-in template when the list is empty', () {
      expect(MessageTemplate.pickDefault([]), MessageTemplate.builtIn);
      expect(MessageTemplate.builtIn.body, contains('{amount}'));
    });
  });
}
