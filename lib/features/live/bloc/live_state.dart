import 'package:equatable/equatable.dart';

import '../logic/live_command.dart';
import '../logic/live_cursor.dart';
import '../logic/live_issue.dart';

/// 和 B 站弹幕服务器之间的连接状态。
enum LiveConnectionStatus {
  /// 开关关着，没在连。
  off,

  /// 正在连。
  connecting,

  /// 连上了，弹幕在流。
  connected,

  /// 断开或连不上，等下次重试。
  retrying,
}

/// 「这条指令是谁发的」，用来做失败归因。
///
/// 弹幕害死主播时界面必须能显示出来：不显示的话观众不知道发生了什么，
/// 主播也会以为是自己的操作。
class LiveCommandRecord {
  const LiveCommandRecord({
    required this.uname,
    required this.text,
    required this.steps,
  });

  final String uname;

  /// 原始弹幕。归因显示用——观众看到的是自己打的那句话，不是展开后的操作。
  final String text;

  /// 展开后的操作序列，按顺序。
  final List<LiveCommand> steps;

  /// 只比人和原文：`steps` 是从 `text` 推出来的，比原文就够了。
  @override
  bool operator ==(Object other) {
    return other is LiveCommandRecord &&
        other.uname == uname &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(uname, text);

  @override
  String toString() => 'LiveCommandRecord($uname, $text)';
}

class LiveState extends Equatable {
  const LiveState({
    this.status = LiveConnectionStatus.off,
    this.enabled = false,
    this.requireMedal = true,
    this.cursor,
    this.roomId,
    this.width = 0,
    this.height = 0,
    this.accepted = 0,
    this.ignored = 0,
    this.lastCommand,
    this.issue,
  });

  final LiveConnectionStatus status;

  /// 主播有没有打开这个功能。
  ///
  /// 单独存一份而不是从 [status] 推：`off` 既可能是「开关关着」，也可能是
  /// 「刚启动还没读设置」，界面上的开关得知道到底是哪种。
  final bool enabled;

  /// 只接受本直播间粉丝牌的弹幕。默认开。
  ///
  /// 镜像自设置，放在 state 里是为了让设置界面和过滤逻辑读同一个源。
  final bool requireMedal;

  /// 所有人共享的光标。盘面还没出来时为 `null`。
  final LiveCursor? cursor;

  /// `hello` 报过来的**真实**房间号，用来确认连对了房间。
  ///
  /// 它和设置里填的短号不一定相同。
  final int? roomId;

  /// 当前盘面的格子数。
  ///
  /// 存下来是为了让移动光标不用回头去问 `GameBloc`——那一问会让这层依赖上
  /// 整个游戏 bloc，也就没法单独测了。
  final int width;
  final int height;

  /// 生效的弹幕**条数**（不是操作个数：一条 `3下开` 算一条）。
  final int accepted;

  /// 收到但不是指令的弹幕条数（观众闲聊）。用来判断指令表是不是写错了。
  final int ignored;

  /// 最近一条生效的指令。
  final LiveCommandRecord? lastCommand;

  /// 没连上／断开的原因。连上之后清空。文案由界面层翻译。
  final LiveIssueInfo? issue;

  bool get isConnected => status == LiveConnectionStatus.connected;

  /// 盘面尺寸知道了吗。不知道就没法把光标放到合法格子上。
  bool get hasBoard => width > 0 && height > 0;

  LiveState copyWith({
    LiveConnectionStatus? status,
    bool? enabled,
    bool? requireMedal,
    LiveCursor? cursor,
    int? roomId,
    int? width,
    int? height,
    int? accepted,
    int? ignored,
    LiveCommandRecord? lastCommand,
    LiveIssueInfo? issue,
    bool clearIssue = false,
  }) {
    return LiveState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      requireMedal: requireMedal ?? this.requireMedal,
      cursor: cursor ?? this.cursor,
      roomId: roomId ?? this.roomId,
      width: width ?? this.width,
      height: height ?? this.height,
      accepted: accepted ?? this.accepted,
      ignored: ignored ?? this.ignored,
      lastCommand: lastCommand ?? this.lastCommand,
      issue: clearIssue ? null : (issue ?? this.issue),
    );
  }

  @override
  List<Object?> get props => [
    status,
    enabled,
    requireMedal,
    cursor,
    roomId,
    width,
    height,
    accepted,
    ignored,
    lastCommand,
    issue,
  ];
}
