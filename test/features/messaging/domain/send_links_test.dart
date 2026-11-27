import 'package:fixer/features/messaging/domain/send_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'Hi Omar, you owe 2.396 JOD.\n- Tea: 1.000 & more';

  group('whatsappUri', () {
    test('opens a chat with the number and the message prefilled', () {
      expect(
        whatsappUri('962791234567', text).toString(),
        'https://wa.me/962791234567?text=Hi%20Omar%2C%20you%20owe%202.396%20JOD.'
        '%0A-%20Tea%3A%201.000%20%26%20more',
      );
    });

    test('without a number lets the user pick the chat', () {
      expect(whatsappUri(null, 'Hi').toString(), 'https://wa.me/?text=Hi');
    });
  });

  group('smsUri', () {
    test('targets the number with an encoded body (spaces never become +)', () {
      expect(
        smsUri('+962791234567', 'a b+c').toString(),
        'sms:+962791234567?body=a%20b%2Bc',
      );
    });

    test('without a number opens the SMS app with just the body', () {
      expect(smsUri(null, 'Hi').toString(), 'sms:?body=Hi');
    });
  });
}
