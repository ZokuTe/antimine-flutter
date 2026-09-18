import 'package:flutter/material.dart';

import '../../../foundation/ui/spacing.dart';

class ControlDivider extends StatelessWidget {
  const ControlDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: Spacing.x2,
      thickness: Spacing.x2,
      indent: Spacing.x16,
      endIndent: Spacing.x16,
      color: colorScheme.onSurface.withAlpha(_controlDividerAlpha),
    );
  }

  static final _controlDividerAlpha = (255.0 * 0.25).toInt();
}
