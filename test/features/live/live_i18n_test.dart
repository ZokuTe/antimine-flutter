import 'package:antimine/foundation/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// 守的是「直播这块的文案真的翻了」这件事。
///
/// 有两个很隐蔽的失败模式，下面都盯着：
///
/// 1. 新键只写进 template（`strings.i18n.json`）而没写进 base locale
///    （`strings_en.i18n.json`），slang 就不会**生成**这个 getter，你会拿到编译
///    错误。反过来，写进了 base 但忘了 zh-CN，编译没问题，界面却静默回落英文。
/// 2. slang 把每个语言编译成**延迟加载**的库，所以切语言必须 `await`。
///    `setLocaleSync` 会直接抛「Deferred library l_zh_CN was not loaded」，
///    而不 await 的 `setLocale` 会让断言和加载赛跑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 切到中文并等它的延迟库真的加载完。
  Future<void> useChinese() => LocaleSettings.setLocale(AppLocale.zhCn);

  tearDown(() => LocaleSettings.setLocale(AppLocale.en));

  test('zh-CN 的直播文案是翻过的，不是英文回落', () async {
    await useChinese();

    expect(t.live, '直播');
    expect(t.live_enable, 'B站弹幕控制');
    expect(t.live_require_medal, '需要粉丝牌');
    expect(t.live_room_id, '房间号');
    expect(t.live_sessdata, 'SESSDATA（可选）');
    expect(t.live_status, '状态');
  });

  test('状态文案也翻了', () async {
    await useChinese();

    expect(t.live_status_off, '未开启');
    expect(t.live_status_connecting, '连接中…');
    expect(t.live_status_retrying, '重连中…');
    expect(t.live_status_connected(RoomId: 5440), '已连接 · 房间 5440');
  });

  test('失败原因也翻了', () async {
    await useChinese();

    expect(t.live_issue_unsupported_platform, contains('Windows'));
    expect(t.live_issue_missing_room_id, '填个房间号才能连');
    expect(t.live_issue_room_not_found, '房间不存在，或者没在播');
    expect(t.live_issue_disconnected, '连接断开，正在重连…');
  });

  test('远端给的原始信息原样带出，不被翻译', () async {
    await useChinese();

    // `-352` 是 B 站自己的错误码，翻了就没法排查了
    expect(t.live_issue_api_error(Detail: 'code=-352'), contains('-352'));
    expect(t.live_issue_network(Detail: 'HTTP 503'), contains('HTTP 503'));
  });

  test('指令提示里的指令词不翻译', () async {
    await useChinese();

    // 先确认拿到的确实是中文那份——否则下面那些字面量在英文串里也有，
    // 回落到英文时这条会假通过。
    expect(t.live_commands, startsWith('指令：'));
    // 那些是观众要照打的字面量，任何语言下都不该被翻掉
    for (final token in ['上', '下', '左', '右', '开', '旗', '问']) {
      expect(t.live_commands, contains(token));
    }
  });

  test('英文是 base，也一样有', () async {
    await LocaleSettings.setLocale(AppLocale.en);

    expect(t.live_enable, 'Bilibili danmaku control');
    expect(t.live_room_id, 'Room ID');
    expect(t.live_issue_room_not_found, isNotEmpty);
  });
}
