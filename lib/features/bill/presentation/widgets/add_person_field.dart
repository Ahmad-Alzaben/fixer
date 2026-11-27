import 'package:fixer/core/widgets/money_input.dart';
import 'package:fixer/features/bill/application/bill_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Type a name and press Enter; the field stays focused for the next one.
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
        prefixIcon: const Icon(Icons.person_add_alt),
        suffixIcon: IconButton(
          tooltip: 'Add person',
          icon: const Icon(Icons.add),
          onPressed: _submit,
        ),
      ),
    );
  }
}
