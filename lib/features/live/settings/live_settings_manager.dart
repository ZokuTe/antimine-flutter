import 'package:antimine/common/settings/settings_repository.dart';

/// 直播联动的设置。
class LiveSettings {
  const LiveSettings({
    this.enabled = false,
    this.roomId,
    this.sessdata,
    this.requireMedal = true,
  });

  final bool enabled;

  /// 直播间号，短号也行。没填就没法连。
  final int? roomId;

  /// 可选。实测匿名连接照样能拿到完整用户名和粉丝牌，所以它现在只是换个身份用，
  /// 不填完全能跑。
  final String? sessdata;

  /// 只接受戴着**本直播间**粉丝牌的弹幕。默认开，关掉之后访客也能操作。
  final bool requireMedal;
}

/// 读写直播设置。
///
/// 单独一个 manager 而不是塞进 `GameSettings`：那是个到处在用的不可变大对象，
/// 为这几个字段去动它的 `copyWith`、序列化和所有构造点不划算。
class LiveSettingsManager {
  LiveSettingsManager({required this.repository});

  final SettingsRepository repository;

  Future<LiveSettings> load() async {
    final roomId = await repository.getInt(_roomIdKey, 0);
    final sessdata = await repository.optString(_sessdataKey);

    return LiveSettings(
      enabled: await repository.getBool(_enabledKey, false),
      roomId: roomId > 0 ? roomId : null,
      sessdata: sessdata == null || sessdata.isEmpty ? null : sessdata,
      requireMedal: await repository.getBool(_requireMedalKey, true),
    );
  }

  Future<void> setEnabled(bool value) {
    return repository.setBool(_enabledKey, value);
  }

  Future<void> setRequireMedal(bool value) {
    return repository.setBool(_requireMedalKey, value);
  }

  Future<void> setRoomId(int? value) {
    if (value == null || value <= 0) {
      return repository.remove(_roomIdKey);
    }
    return repository.setInt(_roomIdKey, value);
  }

  Future<void> setSessdata(String? value) {
    if (value == null || value.isEmpty) {
      return repository.remove(_sessdataKey);
    }
    return repository.setString(_sessdataKey, value);
  }

  static const _enabledKey = 'live_enabled';
  static const _requireMedalKey = 'live_require_medal';
  static const _roomIdKey = 'live_room_id';
  static const _sessdataKey = 'live_sessdata';
}
