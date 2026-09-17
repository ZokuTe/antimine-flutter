import 'package:flutter/material.dart';

import '../../../foundation/ui/spacing.dart';

/// A settings row with a title and one or two trailing actions.
///
/// Used for settings that are not simple switches, such as picking a background
/// image, where the row opens a picker or clears the current value.
class SettingsActionItem extends StatelessWidget {
  const SettingsActionItem({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.subtitle,
  });

  final String title;

  /// Label and callback for the main action (e.g. "Choose").
  final String primaryLabel;
  final VoidCallback onPressed;

  /// Optional secondary action (e.g. "Remove"). Hidden when null.
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  /// Shown under the title, e.g. the current selection.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryLabel = this.secondaryLabel;
    return ListTile(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Spacing.x8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.x16),
      dense: true,
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onPressed, child: Text(primaryLabel)),
          if (secondaryLabel != null && onSecondaryPressed != null)
            IconButton(
              onPressed: onSecondaryPressed,
              icon: const Icon(Icons.delete_outline),
              tooltip: secondaryLabel,
            ),
        ],
      ),
    );
  }
}
