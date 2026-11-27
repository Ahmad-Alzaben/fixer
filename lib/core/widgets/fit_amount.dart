import 'package:flutter/widgets.dart';

/// An amount inside a [Row] that shrinks instead of overflowing when space
/// runs out (narrow phones, very large text, very large numbers).
///
/// Use it as a direct child of a Row/Flex: it is [Flexible] itself, so the
/// label beside it (usually `Expanded`) keeps its share of the width.
class FitAmount extends StatelessWidget {
  const FitAmount(this.text, {this.style, this.flex = 1, super.key});

  final String text;
  final TextStyle? style;
  final int flex;

  @override
  Widget build(BuildContext context) {
    // Tight fit: fills its share of the row so the amount sits flush right
    // (a loose fit would leave it floating mid-row).
    return Flexible(
      flex: flex,
      fit: FlexFit.tight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: Text(text, style: style, maxLines: 1),
      ),
    );
  }
}
