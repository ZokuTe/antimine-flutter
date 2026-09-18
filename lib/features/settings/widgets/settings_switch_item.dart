import 'package:flutter/material.dart';

import '../../../foundation/ui/spacing.dart';

/// A titled switch whose position is owned by the caller.
///
/// `SwitchListTile` is stateless by design and renders whatever value it is
/// given, so mirroring the value into local state only invited the copy to
/// drift from the bloc.
class SettingsSwitchItem extends StatelessWidget {
  const SettingsSwitchItem({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Spacing.x8)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.x16),
      dense: true,
      enableFeedback: false,
      value: value,
      onChanged: onChanged,
    );
  }
}
