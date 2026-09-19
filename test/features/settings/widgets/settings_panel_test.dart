import 'package:antimine/features/settings/models/settings_item.dart';
import 'package:antimine/features/settings/widgets/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// `GameContainer` 画了一层带背景色的 `DecoratedBox`，而 `ListTile` 会把水波纹和
  /// 背景画到**最近的 `Material`** 上。中间少了那层透明 `Material` 的话，debug 下
  /// 每一行开关都会抛一次「ListTile background color or ink splashes may be
  /// invisible」，几十条噪音能把真错误淹掉。
  testWidgets('开关行不报 ListTile 水波纹断言', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(
            title: 'Test',
            children: [
              SettingsItem(title: 'A switch', value: false, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );

    // 先确认这一行真的渲染出来了，否则断言可能只是因为什么都没画而通过
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
