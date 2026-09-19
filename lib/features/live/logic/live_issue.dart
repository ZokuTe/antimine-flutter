/// 连不上、或者断开的**原因**。
///
/// 文案刻意不在这里：协议层和 bloc 都不碰字符串，只产出这个枚举，由界面层翻成
/// 当前语言。
///
/// 前三个由 `LiveBloc` 判定，后五个由 `BilibiliDanmakuClient` 抛出。
enum LiveIssue {
  /// 平台不支持。直播联动只做 Windows / Linux。
  unsupportedPlatform,

  /// 开关开着，但没填房间号。
  missingRoomId,

  /// 连接断开，正在等重连。
  disconnected,

  /// 网络层：连不上、超时、DNS。
  network,

  /// B 站服务端不正常：非 200、返回体结构不对、缺关键字段。
  unavailable,

  /// B 站接口回了非 0 的 code。
  apiError,

  /// 房间号不存在，或者主播没开播。
  roomNotFound,

  /// 弹幕鉴权被拒，通常是 token 过期。
  authRejected,
}

/// 一个失败原因，外加远端给的原始信息。
///
/// 打成一个值而不是两个平行字段，是为了让「换原因」和「换附带信息」原子发生：
/// 拆成两个字段的话，从 `apiError(code=-352)` 变成 `missingRoomId` 时很容易
/// 把 `-352` 留在界面上。
class LiveIssueInfo {
  const LiveIssueInfo(this.issue, [this.detail]);

  final LiveIssue issue;

  /// 远端给的原始信息，比如 HTTP 状态码或 B 站自己的 message。
  ///
  /// 这是 B 站的话，**不翻译**——翻译了反而让排查变难。
  final String? detail;

  @override
  bool operator ==(Object other) {
    return other is LiveIssueInfo &&
        other.issue == issue &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(issue, detail);

  @override
  String toString() =>
      detail == null
          ? 'LiveIssueInfo(${issue.name})'
          : '${issue.name}: $detail';
}
