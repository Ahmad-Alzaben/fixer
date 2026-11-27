import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          const SectionLabel('Accent color'),
          const SizedBox(height: Gap.s),
          Card(
            child: RadioGroup<AppAccent>(
              groupValue: selected,
              onChanged: (a) {
                if (a != null) ref.read(accentProvider.notifier).choose(a);
              },
              child: Column(
                children: [
                  for (final accent in AppAccent.values)
                    RadioListTile<AppAccent>(
                      value: accent,
                      title: Text(accent.label),
                      secondary: _Swatch(color: accent.color),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: ShapeDecoration(
          color: color,
          shape: const BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}
