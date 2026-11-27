import 'package:fixer/core/money/currency.dart';
import 'package:fixer/core/theme/app_accent.dart';
import 'package:fixer/core/theme/app_theme.dart';
import 'package:fixer/core/widgets/section_label.dart';
import 'package:fixer/features/bill/domain/bill.dart';
import 'package:fixer/features/bill/domain/tax.dart';
import 'package:fixer/features/settings/application/settings_providers.dart';
import 'package:fixer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          const SectionLabel('You'),
          const SizedBox(height: Gap.s),
          const _YourNameField(),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Bills'),
          const SizedBox(height: Gap.s),
          const _DefaultCurrencyField(),
          const SizedBox(height: Gap.m),
          const _CountryCodeField(),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Tax'),
          const SizedBox(height: Gap.s),
          const _TaxRateField(),
          const SizedBox(height: Gap.m),
          const _DefaultTaxModeField(),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Messages'),
          const SizedBox(height: Gap.s),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Message templates'),
              subtitle: const Text('Text sent with each person\'s share'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.templates),
            ),
          ),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Accent color'),
          const SizedBox(height: Gap.s),
          const _AccentPicker(),
        ],
      ),
    );
  }
}

class _YourNameField extends ConsumerStatefulWidget {
  const _YourNameField();

  @override
  ConsumerState<_YourNameField> createState() => _YourNameFieldState();
}

class _YourNameFieldState extends ConsumerState<_YourNameField> {
  late final _controller = TextEditingController(
    text: ref.read(preferencesProvider).yourName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onChanged: ref.read(preferencesProvider.notifier).setYourName,
      decoration: const InputDecoration(
        labelText: 'Your name',
        prefixIcon: Icon(Icons.person_outline),
        helperText:
            'Adding someone with this name marks them as Me, '
            'so Reports know your share.',
        helperMaxLines: 2,
      ),
    );
  }
}

class _DefaultCurrencyField extends ConsumerWidget {
  const _DefaultCurrencyField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      preferencesProvider.select((p) => p.defaultCurrency),
    );
    return DropdownButtonFormField<Currency>(
      key: const ValueKey('default-currency'),
      initialValue: current,
      decoration: const InputDecoration(
        labelText: 'Default currency for new bills',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      items: [
        for (final c in Currency.supported)
          DropdownMenuItem(value: c, child: Text(c.code)),
      ],
      onChanged: (c) {
        if (c != null) {
          ref.read(preferencesProvider.notifier).setDefaultCurrency(c);
        }
      },
    );
  }
}

class _CountryCodeField extends ConsumerStatefulWidget {
  const _CountryCodeField();

  @override
  ConsumerState<_CountryCodeField> createState() => _CountryCodeFieldState();
}

class _CountryCodeFieldState extends ConsumerState<_CountryCodeField> {
  late final _controller = TextEditingController(
    text: ref.read(preferencesProvider).countryCode,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changed(String value) async {
    try {
      await ref.read(preferencesProvider.notifier).setCountryCode(value);
      if (mounted && _error != null) setState(() => _error = null);
    } on ArgumentError {
      if (mounted) setState(() => _error = 'Digits only, e.g. 962');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      onChanged: _changed,
      decoration: InputDecoration(
        labelText: 'Country code',
        prefixText: '+',
        prefixIcon: const Icon(Icons.public),
        errorText: _error,
        helperText: 'Turns local numbers like 079… into +962 79… for WhatsApp.',
        helperMaxLines: 2,
      ),
    );
  }
}

class _TaxRateField extends ConsumerStatefulWidget {
  const _TaxRateField();

  @override
  ConsumerState<_TaxRateField> createState() => _TaxRateFieldState();
}

class _TaxRateFieldState extends ConsumerState<_TaxRateField> {
  late final _controller = TextEditingController(
    text: formatTaxPercent(ref.read(preferencesProvider).taxRate),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changed(String value) async {
    try {
      final rate = parseTaxPercent(value);
      await ref.read(preferencesProvider.notifier).setTaxRate(rate);
      if (mounted && _error != null) setState(() => _error = null);
    } on FormatException {
      if (mounted) setState(() => _error = 'A percentage from 0 to 100');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('tax-rate'),
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: _changed,
      decoration: InputDecoration(
        labelText: 'Tax rate',
        suffixText: '%',
        prefixIcon: const Icon(Icons.receipt_outlined),
        errorText: _error,
        helperText: 'Used by new bills. Bills you already made keep theirs.',
        helperMaxLines: 2,
      ),
    );
  }
}

class _DefaultTaxModeField extends ConsumerWidget {
  const _DefaultTaxModeField();

  static const _labels = {
    TaxMode.none: 'No tax',
    TaxMode.included: 'Included in prices',
    TaxMode.added: 'Added on top',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      preferencesProvider.select((p) => p.defaultTaxMode),
    );
    return DropdownButtonFormField<TaxMode>(
      key: const ValueKey('default-tax-mode'),
      initialValue: current,
      // Expanded so long labels shrink with ellipsis on narrow screens or
      // large text instead of overflowing.
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'New bills start with',
        prefixIcon: Icon(Icons.tune),
      ),
      items: [
        for (final mode in TaxMode.values)
          DropdownMenuItem(
            value: mode,
            child: Text(_labels[mode]!, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (mode) {
        if (mode != null) {
          ref.read(preferencesProvider.notifier).setDefaultTaxMode(mode);
        }
      },
    );
  }
}

class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentProvider);
    return Card(
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
