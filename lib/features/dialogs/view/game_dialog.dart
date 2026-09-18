import 'package:flutter/material.dart';

import '../../../common/utils/build_context_ext.dart';
import '../../../foundation/ui/frosted_glass.dart';
import '../../../foundation/ui/spacing.dart';

class GameDialog extends StatelessWidget {
  const GameDialog({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dialogTheme = DialogTheme.of(context);

    final size = MediaQuery.sizeOf(context);
    final side = size.shortestSide;
    final widthConstraint = context.isTablet ? 0.5 : 0.8;
    final double maxWidth = side * widthConstraint;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Floating above the game canvas. FrostedGlass clips the backdrop
        // filter to the dialog's bounds.
        child: FrostedGlass(
          borderRadius: BorderRadius.circular(Spacing.x16),
          child: Material(
            color: Colors.transparent,
            elevation: 0.0,
            shadowColor: dialogTheme.shadowColor,
            surfaceTintColor: dialogTheme.surfaceTintColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(Spacing.x16)),
            ),
            type: MaterialType.card,
            clipBehavior: Clip.none,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.x16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
