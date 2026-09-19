import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../logic/live_issue.dart';
import 'live_event.dart';

/// 连接失败。
///
/// 只带原因（[LiveIssue]）和远端给的原始信息，**不带文案**——翻成哪种语言是
/// 界面层的事。
class BilibiliDanmakuException implements Exception {
  const BilibiliDanmakuException(this.issue, {this.detail});

  final LiveIssue issue;

  /// 远端给的原始信息，比如 HTTP 状态码或 B 站自己的 message。可能为空。
  final String? detail;

  @override
  String toString() =>
      detail == null
          ? 'BilibiliDanmakuException(${issue.name})'
          : 'BilibiliDanmakuException(${issue.name}: $detail)';
}

/// 直连 B 站直播弹幕，协议实现在进程内，不依赖外部程序。
///
/// 整个流程只有三步：
///
/// 1. `get_info` 把短号解析成真实房间号（主播填的可能是短号，而粉丝牌的
///    `medal_room_id` 是真实号，两边得对上）
/// 2. `getDanmuInfo` 拿 token 和弹幕服务器地址
/// 3. WebSocket 鉴权 + 心跳保活，然后收弹幕
///
/// 认证包显式请求 **protover 2（zlib）**：zlib 解压是 `dart:io` 自带的，
/// 而默认的 protover 3 是 brotli，Dart 没有内置实现，就得引第三方包。
///
/// `SESSDATA` 不必填：实测匿名连接照样能拿到 `medal_room_id`，粉丝牌判定不受
/// 影响。代价是没有它时 `uid` 会是 0、用户名会被打码，归因显示不好看。
///
/// 只依赖 `dart:*`，不碰 Flutter，所以可以脱离界面单独跑和测。
class BilibiliDanmakuClient {
  BilibiliDanmakuClient({HttpClient? httpClient, String? userAgent})
    : _httpClient = httpClient ?? HttpClient(),
      _userAgent = userAgent ?? _defaultUserAgent;

  final HttpClient _httpClient;
  final String _userAgent;

  /// WBI 密钥缓存。B 站会轮换，所以带时效。
  String? _cachedWbiKey;
  DateTime? _wbiKeyFetchedAt;

  /// 连上并持续产出事件。断开或出错时把异常抛给订阅方，由它决定重连。
  ///
  /// [roomId] 可以是短号。[sessdata] 可空，填了就带上。
  Stream<LiveEvent> connect({required int roomId, String? sessdata}) async* {
    final session = await _openSession(sessdata);
    try {
      final resolved = await _resolveRoom(session, roomId);
      final info = await _fetchDanmuInfo(session, resolved);

      final socket = await _openSocket(info.hosts);
      final heartbeat = Timer.periodic(
        _heartbeatInterval,
        (_) => socket.add(_encodePacket('[object Object]', _opHeartbeat)),
      );

      try {
        socket.add(
          _encodePacket(
            jsonEncode({
              'uid': 0,
              'roomid': resolved,
              'protover': _zlibProto,
              'platform': 'web',
              'type': 2,
              'key': info.token,
              'buvid': session.buvid ?? '',
            }),
            _opAuth,
          ),
        );

        yield LiveHello(protocol: _protocolVersion, roomId: resolved);

        await for (final frame in socket) {
          if (frame is! List<int>) {
            continue;
          }
          for (final packet in _decode(Uint8List.fromList(frame))) {
            final event = _toEvent(packet);
            if (event != null) {
              yield event;
            }
          }
        }
      } finally {
        heartbeat.cancel();
        await socket.close();
      }
    } finally {
      session.close();
    }
  }

  /// 打开一个带 UA 和 cookie 的会话。
  ///
  /// 顺手取一次 `buvid3`：B 站给匿名连接发的设备标识，会跟着认证包发过去。
  Future<_Session> _openSession(String? sessdata) async {
    final cookies = <String, String>{};
    String? buvid;

    try {
      final request = await _httpClient.getUrl(Uri.parse(_buvidUrl));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();
      await response.drain<void>();
      for (final cookie in response.cookies) {
        if (cookie.name == 'buvid3') {
          buvid = cookie.value;
        }
      }
    } on SocketException {
      // 拿不到 buvid 也能连，认证包里留空即可
    } on HttpException {
      // 同上
    }

    if (sessdata != null && sessdata.isNotEmpty) {
      cookies['SESSDATA'] = sessdata;
    }
    if (buvid != null && buvid.isNotEmpty) {
      cookies['buvid3'] = buvid;
    }

    return _Session(cookies: cookies, buvid: buvid);
  }

  /// 短号 → 真实房间号。
  Future<int> _resolveRoom(_Session session, int roomId) async {
    final data = await _getJson(
      session,
      Uri.parse('$_roomInfoUrl?room_id=$roomId'),
    );
    final resolved = data['room_id'];
    if (resolved is! int || resolved <= 0) {
      throw BilibiliDanmakuException(
        LiveIssue.roomNotFound,
        detail: 'room_id=$roomId',
      );
    }
    return resolved;
  }

  Future<_DanmuInfo> _fetchDanmuInfo(_Session session, int roomId) async {
    // **必须带 WBI 签名**：不带就返回 -352（B 站的风控拒绝），实测如此。
    final signed = _sign({
      'id': roomId.toString(),
      'type': '0',
    }, await _wbiKey(session));
    final query = signed.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');

    final data = await _getJson(session, Uri.parse('$_danmuInfoUrl?$query'));

    final token = data['token'];
    final hostList = data['host_list'];
    if (token is! String || token.isEmpty) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'getDanmuInfo: no token',
      );
    }
    if (hostList is! List || hostList.isEmpty) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'getDanmuInfo: no host_list',
      );
    }

    final hosts = <_DanmuHost>[];
    for (final item in hostList) {
      if (item is! Map) {
        continue;
      }
      final host = item['host'];
      final port = item['wss_port'];
      if (host is String && port is int && host.isNotEmpty) {
        hosts.add(_DanmuHost(host, port));
      }
    }
    if (hosts.isEmpty) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'getDanmuInfo: no usable host',
      );
    }

    return _DanmuInfo(token: token, hosts: hosts);
  }

  /// 拿 WBI 签名密钥。
  ///
  /// `getDanmuInfo` 不带签名会被风控拒（-352），这是实测踩到的坑。
  ///
  /// 密钥形状：`nav` 接口给两个 URL，各取文件名（去扩展名）拼成 64 字符，
  /// 再按固定索引表抽出 32 个字符。B 站会轮换这两个 key，所以缓存 12 小时。
  Future<String> _wbiKey(_Session session) async {
    final cached = _cachedWbiKey;
    final fetchedAt = _wbiKeyFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _wbiKeyTtl) {
      return cached;
    }

    // 未登录时 nav 会回 code -101，但 data.wbi_img 照样有，所以这里**不能**
    // 走 _getJson 那个「code 必须为 0」的检查。
    // 注意：_getJson 返回的已经是响应里的 `data` 了，不要再解一层。
    final navData = await _getJson(
      session,
      Uri.parse(_navUrl),
      requireOk: false,
    );
    final wbiImg = navData['wbi_img'];
    final imgUrl = wbiImg is Map ? wbiImg['img_url'] : null;
    final subUrl = wbiImg is Map ? wbiImg['sub_url'] : null;
    if (imgUrl is! String || subUrl is! String) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'nav: no wbi_img',
      );
    }

    final shuffled = '${_fileStem(imgUrl)}${_fileStem(subUrl)}';
    final buffer = StringBuffer();
    for (final index in _wbiKeyIndexTable) {
      if (index < shuffled.length) {
        buffer.write(shuffled[index]);
      }
    }

    final key = buffer.toString();
    if (key.isEmpty) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'wbi key empty',
      );
    }

    _cachedWbiKey = key;
    _wbiKeyFetchedAt = DateTime.now();
    return key;
  }

  /// `https://i0.hdslb.com/bfs/wbi/abc123.png` -> `abc123`
  static String _fileStem(String url) {
    final slash = url.lastIndexOf('/');
    var name = slash == -1 ? url : url.substring(slash + 1);
    final dot = name.indexOf('.');
    if (dot != -1) {
      name = name.substring(0, dot);
    }
    return name;
  }

  /// 加签名：补 `wts`、按键字典序排序、去掉 `!'()*`、urlencode 后拼密钥取 md5。
  Map<String, String> _sign(Map<String, String> params, String wbiKey) {
    final wts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final toSign = <String, String>{...params, 'wts': wts};
    final sortedKeys = toSign.keys.toList()..sort();

    final query = sortedKeys
        .map(
          (key) =>
              '$key=${Uri.encodeQueryComponent(_stripUnsafe(toSign[key]!))}',
        )
        .join('&');

    return {
      ...params,
      'wts': wts,
      'w_rid': md5.convert(utf8.encode('$query$wbiKey')).toString(),
    };
  }

  static String _stripUnsafe(String value) =>
      value.replaceAll(RegExp(r"[!'()*]"), '');

  Future<Map<String, dynamic>> _getJson(
    _Session session,
    Uri uri, {
    bool requireOk = true,
  }) async {
    final HttpClientResponse response;
    try {
      final request = await _httpClient.getUrl(uri);
      request.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.refererHeader, _referer);
      if (session.cookies.isNotEmpty) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          session.cookies.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('; '),
        );
      }
      response = await request.close();
    } on SocketException catch (error) {
      throw BilibiliDanmakuException(
        LiveIssue.network,
        detail: error.osError?.message ?? error.message,
      );
    } on HttpException catch (error) {
      throw BilibiliDanmakuException(LiveIssue.network, detail: error.message);
    }

    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'HTTP ${response.statusCode}',
      );
    }

    final body = await response.transform(utf8.decoder).join();
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'not json',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'unexpected shape',
      );
    }
    if (requireOk && decoded['code'] != 0) {
      throw BilibiliDanmakuException(
        LiveIssue.apiError,
        detail: 'code=${decoded['code']} ${decoded['message'] ?? ''}'.trim(),
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const BilibiliDanmakuException(
        LiveIssue.unavailable,
        detail: 'no data',
      );
    }
    return data;
  }

  /// 依次试各个弹幕服务器，第一个握手成功的就用它。
  Future<WebSocket> _openSocket(List<_DanmuHost> hosts) async {
    Object? lastError;
    for (final host in hosts) {
      try {
        return await WebSocket.connect(
          'wss://${host.host}:${host.port}/sub',
          compression: CompressionOptions.compressionOff,
        );
      } on SocketException catch (error) {
        lastError = error;
      } on WebSocketException catch (error) {
        lastError = error;
      }
    }
    throw BilibiliDanmakuException(LiveIssue.network, detail: '$lastError');
  }

  /// 把收到的原始包翻成事件。
  ///
  /// `protover 2` 的包体是 zlib 压缩的**一批包**，所以要递归解进去；
  /// 解压出来可能还是 `protover 2`，也可能变回明文。
  Iterable<_RawPacket> _decode(Uint8List data) sync* {
    var offset = 0;

    while (offset + _headerLength <= data.length) {
      final view = ByteData.view(data.buffer, data.offsetInBytes + offset);
      final total = view.getUint32(0, Endian.big);
      final headerLength = view.getUint16(4, Endian.big);
      final protover = view.getUint16(6, Endian.big);
      final operation = view.getUint32(8, Endian.big);

      // 包头长度固定 16，但读进来的值不能全信：对不上就直接放弃剩下的数据，
      // 免得把越界读成别的东西。
      if (total < _headerLength ||
          offset + total > data.length ||
          headerLength < _headerLength) {
        return;
      }

      final body = Uint8List.sublistView(
        data,
        offset + headerLength,
        offset + total,
      );

      if (protover == _zlibProto) {
        // 服务端还是发了 zlib：解完接着当包解
        final List<int> inflated;
        try {
          inflated = zlib.decode(body);
        } on FormatException {
          // 数据坏了，这一包跳过
          offset += total;
          continue;
        }
        yield* _decode(Uint8List.fromList(inflated));
      } else if (protover == _plainProto || protover == 1) {
        yield _RawPacket(operation: operation, body: body);
      }
      // protover 3（brotli）不该出现——我们只要了 2。

      offset += total;
    }
  }

  /// 只挑弹幕。其它 cmd 一律忽略。
  LiveEvent? _toEvent(_RawPacket packet) {
    switch (packet.operation) {
      case _opHeartbeatReply:
        // 心跳回执，只当「B 站链路还活着」的信号
        return const LiveHeartbeat();
      case _opAuthReply:
        final code = _authCode(packet.body);
        if (code != null && code != 0) {
          throw BilibiliDanmakuException(
            LiveIssue.authRejected,
            detail: 'code=$code',
          );
        }
        return null;
    }

    // 只处理弹幕消息；别的操作码的体不是 JSON，直接跳过
    if (packet.operation != _opNotify) {
      return null;
    }

    final command = _decodeCommand(packet.body);
    if (command == null) {
      return null;
    }

    // B 站会在 cmd 后面接参数，比如 `DANMU_MSG:4:0:2:2:2:0`
    var name = command['cmd'];
    if (name is! String) {
      return null;
    }
    final colon = name.indexOf(':');
    if (colon != -1) {
      name = name.substring(0, colon);
    }
    if (name != 'DANMU_MSG') {
      return null;
    }

    final info = command['info'];
    if (info is! List || info.length < 3) {
      return null;
    }

    final text = info[1];
    final user = info[2];
    if (text is! String || user is! List || user.isEmpty) {
      return null;
    }

    // info[3] 是勋章信息，没戴牌子时是空列表
    var medalLevel = 0;
    var medalRoomId = 0;
    final medal = info[3];
    if (medal is List && medal.length >= 4) {
      medalLevel = medal[0] is int ? medal[0] as int : 0;
      medalRoomId = medal[3] is int ? medal[3] as int : 0;
    }

    return LiveDanmaku(
      text: text,
      uid: user[0] is int ? user[0] as int : 0,
      uname: user[1] is String ? user[1] as String : '',
      medalLevel: medalLevel,
      medalRoomId: medalRoomId,
    );
  }

  int? _authCode(Uint8List body) {
    final command = _decodeCommand(body);
    final code = command?['code'];
    return code is int ? code : null;
  }

  Map<String, dynamic>? _decodeCommand(Uint8List body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(utf8.decode(body, allowMalformed: true));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// 组一个包：16 字节头 + 体，全大端序。发出去的一律是明文 JSON。
  Uint8List _encodePacket(String body, int operation) {
    final payload = utf8.encode(body);
    final buffer = Uint8List(_headerLength + payload.length);
    final view = ByteData.view(buffer.buffer);
    view.setUint32(0, buffer.length, Endian.big);
    view.setUint16(4, _headerLength, Endian.big);
    view.setUint16(6, _plainProto, Endian.big);
    view.setUint32(8, operation, Endian.big);
    view.setUint32(12, 1, Endian.big);
    buffer.setRange(_headerLength, buffer.length, payload);
    return buffer;
  }

  static const _headerLength = 16;

  /// 明文 JSON
  static const _plainProto = 0;

  /// zlib 压缩
  static const _zlibProto = 2;

  static const _opHeartbeat = 2;
  static const _opHeartbeatReply = 3;
  static const _opNotify = 5;
  static const _opAuth = 7;
  static const _opAuthReply = 8;

  static const _protocolVersion = 1;

  static const _heartbeatInterval = Duration(seconds: 30);

  static const _wbiKeyTtl = Duration(hours: 12);

  /// WBI 密钥的抽取顺序，照抄 B 站前端。
  static const _wbiKeyIndexTable = [
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
  ];

  static const _buvidUrl = 'https://www.bilibili.com/';
  static const _navUrl = 'https://api.bilibili.com/x/web-interface/nav';
  static const _roomInfoUrl =
      'https://api.live.bilibili.com/room/v1/Room/get_info';
  static const _danmuInfoUrl =
      'https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo';
  static const _referer = 'https://live.bilibili.com/';

  static const _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

/// 一个已建立的 HTTP 会话：cookie 加设备标识。
class _Session {
  const _Session({required this.cookies, this.buvid});

  final Map<String, String> cookies;
  final String? buvid;

  void close() {}
}

class _DanmuHost {
  const _DanmuHost(this.host, this.port);

  final String host;
  final int port;
}

class _DanmuInfo {
  const _DanmuInfo({required this.token, required this.hosts});

  final String token;
  final List<_DanmuHost> hosts;
}

/// 解出来的一层包：操作码 + 原始体。
class _RawPacket {
  const _RawPacket({required this.operation, required this.body});

  final int operation;
  final Uint8List body;
}
