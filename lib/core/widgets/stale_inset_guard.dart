import 'package:flutter/widgets.dart';

/// Ignores keyboard space reported by the system while no text field has
/// focus.
///
/// Some Android devices (seen on Samsung) keep reporting the keyboard's
/// height after the user leaves and returns to the app, although the
/// keyboard is closed. Every screen then shrinks as if a keyboard covered
/// it. A keyboard can only be open for a focused text field, so without one
/// the reported space must be stale.
class StaleInsetGuard extends StatefulWidget {
  const StaleInsetGuard({required this.child, super.key});

  final Widget child;

  @override
  State<StaleInsetGuard> createState() => _StaleInsetGuardState();
}

class _StaleInsetGuardState extends State<StaleInsetGuard> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  static bool get _textFieldFocused {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.viewInsets.bottom == 0 || _textFieldFocused) return widget.child;
    return MediaQuery(
      data: media.copyWith(viewInsets: media.viewInsets.copyWith(bottom: 0)),
      child: widget.child,
    );
  }
}
