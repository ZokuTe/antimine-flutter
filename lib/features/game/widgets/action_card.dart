import 'package:flutter/material.dart';

import '../../../../foundation/ui/frosted_glass.dart';
import '../../../../foundation/ui/spacing.dart';
import 'action_list.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.isPortrait,
    required this.children,
  });

  final bool isPortrait;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final margin =
        isPortrait
            ? const EdgeInsets.only(bottom: Spacing.x8)
            : const EdgeInsets.only(right: Spacing.x8);
    return Container(
      padding: const EdgeInsets.all(Spacing.x4),
      // The card floats over the minefield. A backdrop filter cannot sample the
      // Flame canvas (own RepaintBoundary), so use a translucent frosted panel.
      child: Padding(
        padding: margin,
        child: FrostedSurface(
          borderRadius: BorderRadius.circular(Spacing.x12),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.x8),
            child: ActionList(isPortrait: isPortrait, children: children),
          ),
        ),
      ),
    );
  }
}
