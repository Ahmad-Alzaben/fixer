import 'package:fixer/core/clock.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/bill_calculation.dart';
import 'package:fixer/features/messaging/application/message_launcher.dart';
import 'package:fixer/features/messaging/application/message_values.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:fixer/features/messaging/domain/phone.dart';
import 'package:fixer/features/messaging/domain/send_links.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
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
  final _message = TextEditingController();
  List<MessageTemplate> _templates = const [MessageTemplate.builtIn];
  String? _templateId;

  /// True once the user picked a template or typed in the message; from then
  /// on their choice wins over the saved default.
  bool _userChose = false;

  @override
  void initState() {
    super.initState();
    _apply(MessageTemplate.builtIn);
    // Show the SAVED default as soon as templates load (usually at once).
    // Always use the stored template, never the built-in constant: the user
    // may have edited the default without changing its id.
    ref.listenManual(templatesProvider, (_, next) {
      final list = next.value;
      if (list == null || list.isEmpty) return;
      setState(() => _templates = list);
      final chosenStillExists = list.any((t) => t.id == _templateId);
      if (!_userChose || !chosenStillExists) {
        _apply(MessageTemplate.pickDefault(list));
      }
    }, fireImmediately: true);
  }

  /// Replaces the message with [template] filled in for this person.
  void _apply(MessageTemplate template) {
    _templateId = template.id;
    _message.text = template.render(
      messageValues(
        bill: widget.bill,
        calculation: widget.calculation,
        person: widget.person,
        date: widget.bill.createdAt ?? ref.read(clockProvider)(),
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
    final countryCode = ref.watch(preferencesProvider).countryCode;
    final digits = phone == null
        ? null
        : normalizePhone(phone, defaultCountryCode: countryCode);
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
          if (_templates.length > 1) ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('template-picker'),
              initialValue: _templateId,
              decoration: const InputDecoration(labelText: 'Template'),
              items: [
                for (final t in _templates)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (id) => setState(() {
                _userChose = true;
                _apply(_templates.firstWhere((t) => t.id == id));
              }),
            ),
            const SizedBox(height: Gap.m),
          ],
          TextField(
            controller: _message,
            onChanged: (_) => _userChose = true,
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
