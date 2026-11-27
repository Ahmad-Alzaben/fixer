import 'package:fixer/core/clock.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/messaging/application/message_launcher.dart';
import 'package:fixer/features/messaging/application/message_values.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:fixer/features/messaging/domain/phone.dart';
import 'package:fixer/features/messaging/domain/send_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the message for [person], editable, with WhatsApp and SMS buttons.
Future<void> showSendSheet(
  BuildContext context, {
  required Bill bill,
  required BillCalculation calculation,
  required Person person,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _SendSheet(bill: bill, calculation: calculation, person: person),
  );
}

class _SendSheet extends ConsumerStatefulWidget {
  const _SendSheet({
    required this.bill,
    required this.calculation,
    required this.person,
  });

  final Bill bill;
  final BillCalculation calculation;
  final Person person;

  @override
  ConsumerState<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<_SendSheet> {
  late final TextEditingController _message;

  @override
  void initState() {
    super.initState();
    // Saved templates arrive in the next phase; until then the built-in
    // default is used and the text can be edited freely here.
    final template = MessageTemplate.pickDefault(const []);
    _message = TextEditingController(
      text: template.render(
        messageValues(
          bill: widget.bill,
          calculation: widget.calculation,
          person: widget.person,
          date: widget.bill.createdAt ?? ref.read(clockProvider)(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send(Uri uri, String appName) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final opened = await ref.read(messageLauncherProvider).open(uri);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $appName')),
      );
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = widget.person.phone;
    final digits = phone == null ? null : normalizePhone(phone);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.l,
        0,
        Gap.l,
        Gap.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Send to ${widget.person.name}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            phone ?? 'No number saved: you will pick the chat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.m),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                  onPressed: () =>
                      _send(whatsappUri(digits, _message.text), 'WhatsApp'),
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('SMS'),
                  onPressed: () =>
                      _send(smsUri(phone, _message.text), 'SMS app'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
