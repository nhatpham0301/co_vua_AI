import 'package:flutter/widgets.dart';

/// Max content width for phone-like layout on tablets/large screens.
const double kAdaptiveMaxWidth = 460.0;

/// Returns true when the screen is wider than phone-width
/// (i.e. iPad, tablet, large Android).
bool isTabletLayout(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// Constrains [child] to [maxWidth] and centers it horizontally.
/// The full-width background / Stack parents are NOT affected —
/// only wrap the *content column* inside the Stack.
class AdaptiveWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdaptiveWidth({
    super.key,
    required this.child,
    this.maxWidth = kAdaptiveMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
