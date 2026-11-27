import 'package:fixer/core/ids.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/messaging/application/template_repository.dart';
import 'package:fixer/features/messaging/domain/message_template.dart';
import 'package:fixer/features/messaging/presentation/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create or edit a template, with placeholder chips and a live preview.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({this.template, super.key});

  /// Null to create a new template.
  final MessageTemplate? template;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final _name = TextEditingController(text: widget.template?.name);
  late final _body = TextEditingController(text: widget.template?.body);
  String? _nameError;
  String? _bodyError;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Inserts [token] at the cursor (or at the end if the field was never
  /// focused).
  void _insert(String token) {
    final text = _body.text;
    final sel = _body.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final body = _body.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name' : null;
      _bodyError = body.isEmpty ? 'Enter a message' : null;
    });
    if (name.isEmpty || body.isEmpty) return;
    await ref
        .read(templateRepositoryProvider)
        .save(
          MessageTemplate(
            id: widget.template?.id ?? ref.read(idGeneratorProvider)(),
            name: name,
            body: body,
            isDefault: widget.template?.isDefault ?? false,
          ),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = MessageTemplate(
      id: 'preview',
      name: '',
      body: _body.text,
    ).render(templatePreviewValues);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'NEW TEMPLATE' : 'EDIT TEMPLATE'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: Gap.m),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Message',
              errorText: _bodyError,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Gap.s),
          Text(
            'Tap to insert at the cursor:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.xs,
            children: [
              for (final e in templatePlaceholders.entries)
                Tooltip(
                  message: e.value,
                  child: ActionChip(
                    label: Text(e.key),
                    onPressed: () => _insert(e.key),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Preview'),
          const SizedBox(height: Gap.s),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.l),
              child: Text(
                preview.isEmpty ? '…' : preview,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
