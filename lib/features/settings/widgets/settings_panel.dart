import 'package:flutter/material.dart';

import '../../../foundation/ui/game_container.dart';
import '../../../foundation/ui/spacing.dart';
import '../models/settings_item.dart';
import 'settings_switch_item.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.title,
    required this.children,
    this.extra,
  });

  final String title;
  final List<SettingsItem> children;

  /// Rows that are not simple switches, appended after [children].
  final List<Widget>? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.x32),
      child: SizedBox(
        width: double.infinity,
        child: GameContainer(
          // GameContainer 画了一层带背景色的 DecoratedBox，而 ListTile 会把水波纹
          // 和背景画到**最近的 Material** 上。不隔一层的话它们会被那层背景盖掉，
          // debug 下每一行都会报一次「ListTile ... may be invisible」。
          // 透明 Material 给它们一个正确的落点，又不挡住 GameContainer 的底色。
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: Spacing.x16,
                    left: Spacing.x8,
                    bottom: Spacing.x8,
                  ),
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...children.map(
                  (e) => SettingsSwitchItem(
                    title: e.title,
                    value: e.value,
                    onChanged: e.onChanged,
                  ),
                ),
                ...?extra,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
