import 'dart:async';

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../common/models/input/action.dart';
import '../data/bilibili_danmaku_client.dart';
import '../data/live_event.dart';
import '../live_support.dart';
import '../logic/live_command.dart';
import '../logic/live_cursor.dart';
import '../logic/live_issue.dart';
import '../settings/live_settings_manager.dart';
import 'live_state.dart';

/// 把一条指令送进游戏。游戏界面挂载时提供。
///
/// 直播这边只需要这一个出口，不需要 `GameBloc` 本体——真 `GameBloc` 有十几个
/// 依赖，为了测一条弹幕去拼一整套不值当，那样这层也就没法单测了。
typedef LiveActionSink = Future<void> Function(Action action, Vector2 position);

/// 直播联动的中枢：连 B 站弹幕、解析弹幕、驱动共享光标。
///
/// 协议实现就在进程内（[BilibiliDanmakuClient]），没有外部进程要管，
/// 所以设置里一个开关就能起停。
///
/// 连接**不随换局断开**——主播开新一局时弹幕流不该断——所以游戏界面是挂上来
/// 再摘下去的（[attach] / [detach]），而不是由它持有游戏。
class LiveBloc extends Cubit<LiveState> {
  LiveBloc({
    required this.client,
    required this.settingsManager,
    this.parser = const LiveCommandParser(),
    bool? supported,
    Duration retryDelay = const Duration(seconds: 5),
  }) : _supported = supported ?? isLiveSupported,
       _retryDelay = retryDelay,
       super(const LiveState());

  final BilibiliDanmakuClient client;
  final LiveSettingsManager settingsManager;
  final LiveCommandParser parser;
  final bool _supported;
  final Duration _retryDelay;

  LiveActionSink? _applyAction;
  StreamSubscription<LiveEvent>? _events;
  Timer? _retryTimer;

  bool _enabled = false;
  int? _roomId;
  String? _sessdata;

  /// 「房间号还不知道」只提醒一次，免得刷屏。
  bool _warnedNoRoomId = false;

  /// 指令应用的串行链。
  ///
  /// 这**不是限流**：一条弹幕都不会丢，只是排队一条一条应用。`_updateState`
  /// 内部有一次 `await`，同一帧到达的一批弹幕若并发进去，某些 emit 会带上
  /// 过期的 `areas`，盘面会短暂显示成旧状态。串起来就没有这个窗口。
  ///
  /// 代价是弹幕量超过游戏应用速度时队列会变长。这是不限流换来的，认了。
  Future<void> _chain = Future.value();

  /// 有游戏界面挂着吗。没挂着就不收指令——没有盘面，指令无处可落。
  bool get isAttached => _applyAction != null;

  @override
  Future<void> close() async {
    _enabled = false;
    _retryTimer?.cancel();
    await _events?.cancel();
    return super.close();
  }

  /// 读设置，决定要不要连。App 起来时调一次。
  Future<void> load() async {
    if (!_supported) {
      emit(
        state.copyWith(
          status: LiveConnectionStatus.off,
          enabled: false,
          issue: const LiveIssueInfo(LiveIssue.unsupportedPlatform),
        ),
      );
      return;
    }

    final settings = await settingsManager.load();
    _enabled = settings.enabled;
    _roomId = settings.roomId;
    _sessdata = settings.sessdata;

    emit(state.copyWith(requireMedal: settings.requireMedal));
    await _applyConnectionIntent();
  }

  /// 主播在设置里开关。
  Future<void> setEnabled(bool value) async {
    if (!_supported) {
      return;
    }
    await settingsManager.setEnabled(value);
    _enabled = value;
    await _applyConnectionIntent();
  }

  /// 换房间号并重连。传 `null` 或非正数表示清空。
  Future<void> setRoomId(int? value) async {
    await settingsManager.setRoomId(value);
    _roomId = (value == null || value <= 0) ? null : value;
    await _applyConnectionIntent();
  }

  /// 换 SESSDATA 并重连。空串表示清掉。
  Future<void> setSessdata(String? value) async {
    await settingsManager.setSessdata(value);
    _sessdata = (value == null || value.isEmpty) ? null : value;
    await _applyConnectionIntent();
  }

  /// 切「是不是必须戴本房粉丝牌」。访客能不能操作就看它。
  ///
  /// 不需要重连：判定在收到弹幕时现做。
  Future<void> setRequireMedal(bool value) async {
    await settingsManager.setRequireMedal(value);
    emit(state.copyWith(requireMedal: value));
  }

  /// 挂上一个游戏界面。同一时刻只会有一个。
  void attach({
    required LiveActionSink applyAction,
    required int width,
    required int height,
  }) {
    _applyAction = applyAction;
    updateBounds(width: width, height: height);
  }

  /// 摘掉游戏界面。连接留着。
  void detach() {
    _applyAction = null;
  }

  /// 盘面尺寸变了（新局、换自定义尺寸）时调。
  ///
  /// 换局必须夹一次：标准局和自定义局的盘面尺寸不同，光标会停在一个新盘面上
  /// 不存在的格子里，后面所有指令都落在盘外。
  void updateBounds({required int width, required int height}) {
    if (width <= 0 || height <= 0) {
      return;
    }

    final cursor = state.cursor;
    final next =
        cursor == null
            ? LiveCursor.center(width: width, height: height)
            : cursor.clampedTo(width: width, height: height);

    if (next != cursor || state.width != width || state.height != height) {
      emit(state.copyWith(width: width, height: height, cursor: next));
    }
  }

  /// 按当前设置决定「应该连吗」。开关、房间号、凭据变化都走这里。
  ///
  /// 统一收口的好处是这几种变化共用同一条清理路径，不会出现「改了房间号但
  /// 旧连接还挂着」这种残留。
  Future<void> _applyConnectionIntent() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _events?.cancel();
    _events = null;

    if (!_enabled) {
      emit(
        state.copyWith(
          status: LiveConnectionStatus.off,
          enabled: false,
          clearIssue: true,
        ),
      );
      return;
    }

    final roomId = _roomId;
    if (roomId == null) {
      // 开着但没填房间号。这不是错误而是缺配置，说清楚就行。
      emit(
        state.copyWith(
          status: LiveConnectionStatus.off,
          enabled: true,
          issue: const LiveIssueInfo(LiveIssue.missingRoomId),
        ),
      );
      return;
    }

    _connect();
  }

  void _connect() {
    final roomId = _roomId;
    if (roomId == null) {
      return;
    }

    _retryTimer?.cancel();
    _events?.cancel();
    _warnedNoRoomId = false;

    emit(
      state.copyWith(
        status: LiveConnectionStatus.connecting,
        enabled: true,
        clearIssue: true,
      ),
    );

    _events = client
        .connect(roomId: roomId, sessdata: _sessdata)
        .listen(
          _onEvent,
          onError: _onError,
          onDone:
              () => _scheduleRetry(const LiveIssueInfo(LiveIssue.disconnected)),
          cancelOnError: true,
        );
  }

  void _onError(Object error, StackTrace stackTrace) {
    _scheduleRetry(switch (error) {
      BilibiliDanmakuException(:final issue, :final detail) => LiveIssueInfo(
        issue,
        detail,
      ),
      // 理论上到不了这里。真到了说明是没预料到的异常，把原文带上好排查。
      _ => LiveIssueInfo(LiveIssue.unavailable, '$error'),
    });
  }

  void _scheduleRetry(LiveIssueInfo issue) {
    // 开关关掉、或者房间号被清空之后不该继续重试。
    if (!_enabled || _roomId == null) {
      return;
    }
    _retryTimer?.cancel();
    emit(state.copyWith(status: LiveConnectionStatus.retrying, issue: issue));
    _retryTimer = Timer(_retryDelay, _connect);
  }

  void _onEvent(LiveEvent event) {
    switch (event) {
      case LiveHello():
        emit(
          state.copyWith(
            status: LiveConnectionStatus.connected,
            roomId: event.roomId,
            clearIssue: true,
          ),
        );
      case LiveDanmaku():
        _onDanmaku(event);
      case LiveHeartbeat():
        // B 站链路活着。目前只当存活信号，不改界面状态。
        break;
    }
  }

  void _onDanmaku(LiveDanmaku danmaku) {
    // 粉丝牌门槛。默认要；关掉之后访客（没戴牌子、或者戴的是别家牌子）
    // 也能操作共享光标。
    if (state.requireMedal) {
      final roomId = state.roomId;
      if (roomId == null) {
        // 还没收到 hello，没法判断牌子是不是本房的。按不放行处理，但得出声——
        // 否则表现就是「弹幕一条都不动」，很难查。
        if (!_warnedNoRoomId) {
          _warnedNoRoomId = true;
          debugPrint('> live: room id unknown, dropping danmaku for now');
        }
        return;
      }
      if (!danmaku.hasMedalOf(roomId)) {
        // 静默丢弃，**不 emit**：热闹的房间里没牌子的弹幕占绝大多数，
        // 每条都推一次 state 会把监听 LiveState 的界面刷爆。
        return;
      }
    }

    final steps = parser.parse(danmaku.text);
    if (steps == null) {
      emit(state.copyWith(ignored: state.ignored + 1));
      return;
    }

    // 没挂游戏界面，或者盘面尺寸还不知道——指令没地方落。
    if (!isAttached || !state.hasBoard) {
      emit(state.copyWith(ignored: state.ignored + 1));
      return;
    }

    // 先把整串走一遍，算出最终光标和每个动作的落点，最后一次性 emit。
    // 逐步 emit 也对，但中间态没人看，多推几次 state 只是白让界面重建。
    var cursor = state.cursor!;
    final pending = <(Action, LiveCursor)>[];

    for (final step in steps) {
      switch (step) {
        case MoveCursor():
          cursor = cursor.movedBy(
            step.direction,
            width: state.width,
            height: state.height,
          );

        case ActAtCursor():
          // 落点取的是它**前面那些移动之后**的光标，所以 `3下开` 的「开」
          // 落在地下三格那一格，不是原来的位置。
          pending.add((step.action, cursor));
      }
    }

    emit(
      state.copyWith(
        cursor: cursor,
        accepted: state.accepted + 1,
        lastCommand: LiveCommandRecord(
          uname: danmaku.uname,
          text: danmaku.text,
          steps: steps,
        ),
      ),
    );

    for (final (action, at) in pending) {
      _enqueue(action, at);
    }
  }

  void _enqueue(Action action, LiveCursor cursor) {
    _chain = _chain
        .then((_) {
          final applyAction = _applyAction;
          if (applyAction == null) {
            // 排队期间游戏界面被摘掉了（主播退出了对局），这条就别发了。
            return Future.value();
          }
          return applyAction(
            action,
            Vector2(cursor.x.toDouble(), cursor.y.toDouble()),
          );
        })
        .catchError((Object error) {
          // 一次失败不能把整条链打断，否则之后所有弹幕都会无声无息地不生效。
          debugPrint('> live action failed: $error');
        });
  }
}
