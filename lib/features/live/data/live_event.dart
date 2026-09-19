/// 弹幕客户端产出的一条事件。
sealed class LiveEvent {
  const LiveEvent();
}

/// 握手。连上就发一条，带解析出来的**真实**房间号。
///
/// 设置里填的可能是短号（实测 `1` 会解析成 `5440`），而粉丝牌的
/// `medal_room_id` 用的是真实号，所以两边要对上得靠这条事件。
class LiveHello extends LiveEvent {
  const LiveHello({required this.protocol, this.roomId});

  final int protocol;
  final int? roomId;
}

/// 一条弹幕。
class LiveDanmaku extends LiveEvent {
  const LiveDanmaku({
    required this.text,
    required this.uid,
    required this.uname,
    required this.medalLevel,
    required this.medalRoomId,
  });

  final String text;
  final int uid;
  final String uname;

  /// 勋章等级。0 表示没戴牌子。
  final int medalLevel;

  /// 勋章所属房间号。要拿它和 [LiveHello.roomId] 比才能确定是不是**本房**的牌子。
  ///
  /// 只看 [medalLevel] > 0 是不够的——别家直播间的牌子也成立。
  final int medalRoomId;

  /// 是不是戴着 [roomId] 这个房间的牌子。
  bool hasMedalOf(int? roomId) {
    return medalLevel > 0 && roomId != null && medalRoomId == roomId;
  }
}

/// B 站链路还活着。
///
/// 心跳回执每 30 秒来一次，所以它也是「整条解码链路还通着」的凭据。
class LiveHeartbeat extends LiveEvent {
  const LiveHeartbeat();
}
