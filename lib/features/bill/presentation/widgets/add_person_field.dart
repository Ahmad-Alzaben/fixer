import 'package:fixer/core/widgets/money_input.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:fixer/features/contacts/contacts_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Type a name and press Enter (the field stays focused for the next one),
/// or pick someone from the phone's contacts.
class AddPersonField extends ConsumerStatefulWidget {
  const AddPersonField({super.key});

  @override
  ConsumerState<AddPersonField> createState() => _AddPersonFieldState();
}

class _AddPersonFieldState extends ConsumerState<AddPersonField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(billEditorProvider.notifier).addPerson(_controller.text);
    _controller.clear();
    refocus(_focus);
  }

  Future<void> _pickContact() async {
    final messenger = ScaffoldMessenger.of(context);
    final PickedContact? contact;
    try {
      contact = await ref.read(contactsGatewayProvider).pick();
    } on ContactsPermissionDenied {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Allow contacts access to pick people '
            '(Settings › Apps › Fixer › Permissions).',
          ),
        ),
      );
      return;
    }
    if (contact == null || !mounted) return;

    var phone = contact.phones.firstOrNull;
    if (contact.phones.length > 1) {
      phone = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Number for ${contact!.name}'),
          children: [
            for (final number in contact.phones)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, number),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(number),
                ),
              ),
          ],
        ),
      );
      if (phone == null) return; // dialog dismissed
    }
    ref
        .read(billEditorProvider.notifier)
        .addPerson(contact.name, phone: phone, contactId: contact.id);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onEditingComplete: keepFocus,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Add person',
        prefixIcon: IconButton(
          tooltip: 'Add from contacts',
          icon: const Icon(Icons.contacts_outlined),
          onPressed: _pickContact,
        ),
        suffixIcon: IconButton(
          tooltip: 'Add person',
          icon: const Icon(Icons.add),
          onPressed: _submit,
        ),
      ),
    );
  }
}
