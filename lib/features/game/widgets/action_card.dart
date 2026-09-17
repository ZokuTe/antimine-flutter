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
      // Floats over the minefield, so the frosted backdrop keeps it readable
      // while still showing the board behind it.
      child: Padding(
        padding: margin,
        child: FrostedGlass(
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
