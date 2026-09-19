import 'dart:async';
import 'dart:math' as math;

import 'package:antimine/common/models/input/action.dart';
import 'package:antimine/features/live/bloc/live_bloc.dart';
import 'package:antimine/features/live/bloc/live_state.dart';
import 'package:antimine/features/live/data/bilibili_danmaku_client.dart';
import 'package:antimine/features/live/data/live_event.dart';
import 'package:antimine/features/live/logic/live_command.dart';
import 'package:antimine/features/live/logic/live_cursor.dart';
import 'package:antimine/features/live/logic/live_issue.dart';
import 'package:antimine/features/live/settings/live_settings_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mocks/test_settings_repository.dart';

/// 假的客户端，测试自己往里灌事件，不碰网络。
class _FakeClient implements BilibiliDanmakuClient {
  final List<StreamController<LiveEvent>> opened = [];

  /// 下一次 connect() 直接失败，用来测重连。
  bool failNext = false;

  StreamController<LiveEvent> get latest => opened.last;

  int get connectCount => opened.length;

  int? lastRoomId;
  String? lastSessdata;

  @override
  Stream<LiveEvent> connect({required int roomId, String? sessdata}) {
    lastRoomId = roomId;
    lastSessdata = sessdata;
    if (failNext) {
      return Stream.error(
        const BilibiliDanmakuException(LiveIssue.network, detail: 'test'),
      );
    }
    final controller = StreamController<LiveEvent>();
    opened.add(controller);
    return controller.stream;
  }
}

/// 测试用的房间号。造弹幕和发 hello 都用它，两边对得上才过得了粉丝牌门槛。
const testRoomId = 5440;

void main() {
  late _FakeClient fake;
  late TestSettingsRepository repository;
  late LiveSettingsManager settings;

  setUp(() {
    fake = _FakeClient();
    repository = TestSettingsRepository();
    settings = LiveSettingsManager(repository: repository);
  });

  LiveBloc buildBloc({
    bool supported = true,
    Duration retryDelay = const Duration(milliseconds: 5),
  }) {
    return LiveBloc(
      client: fake,
      settingsManager: settings,
      supported: supported,
      retryDelay: retryDelay,
    );
  }

  /// 灌一条事件并等它被处理完。
  Future<void> feed(LiveEvent event) async {
    fake.latest.add(event);
    await pumpEventQueue();
  }

  /// 等到 [predicate] 成立，最多等 [timeout]。
  ///
  /// 别用固定的 `Future.delayed` 等异步结果：全量跑测试时多个文件并行，机器一忙
  /// 固定延时就不够，会出现「单独跑通过、全量跑失败」。这里踩过这个坑。
  Future<void> waitFor(
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('等待条件成立超时');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// 只连上，不等握手。用来测连接状态本身。
  Future<void> connectRaw(LiveBloc bloc) async {
    await repository.setBool('live_enabled', true);
    await repository.setInt('live_room_id', testRoomId);
    await bloc.load();
    await pumpEventQueue();
  }

  /// 连上并走完握手。
  ///
  /// 真实流程里 `hello` 是连上就发的第一条，而房间号要等它到了才知道——
  /// 粉丝牌门槛靠房间号判断牌子是不是**本房**的，所以默认把握手做掉。
  Future<void> connect(LiveBloc bloc, {int roomId = testRoomId}) async {
    await connectRaw(bloc);
    fake.latest.add(LiveHello(protocol: 1, roomId: roomId));
    await pumpEventQueue();
  }

  /// 默认造「本房 3 级粉丝牌」的弹幕，能过门槛。
  LiveDanmaku says(
    String text, {
    String uname = '某人',
    int uid = 1,
    int medalLevel = 3,
    int medalRoomId = testRoomId,
  }) {
    return LiveDanmaku(
      text: text,
      uid: uid,
      uname: uname,
      medalLevel: medalLevel,
      medalRoomId: medalRoomId,
    );
  }

  final danmaku = says('开');

  group('平台与开关', () {
    test('不支持的平台不连，状态是 off', () async {
      final bloc = buildBloc(supported: false);
      await connectRaw(bloc);

      expect(bloc.state.status, LiveConnectionStatus.off);
      expect(fake.connectCount, 0);
      await bloc.close();
    });

    test('开关关着不连', () async {
      final bloc = buildBloc();
      await bloc.load(); // 默认 enabled=false
      await pumpEventQueue();

      expect(bloc.state.status, LiveConnectionStatus.off);
      expect(fake.connectCount, 0);
      await bloc.close();
    });

    test('开关开着就连', () async {
      final bloc = buildBloc();
      await connectRaw(bloc);

      expect(fake.connectCount, 1);
      expect(bloc.state.status, LiveConnectionStatus.connecting);
      await bloc.close();
    });
  });

  group('连接', () {
    test('hello 之后变成 connected 并记下房间号', () async {
      final bloc = buildBloc();
      await connectRaw(bloc);
      await feed(const LiveHello(protocol: 1, roomId: 5440));

      expect(bloc.state.status, LiveConnectionStatus.connected);
      expect(bloc.state.roomId, 5440);
      expect(bloc.state.isConnected, isTrue);
      await bloc.close();
    });

    test('连不上时进入重试，并保留原因', () async {
      fake.failNext = true;
      final bloc = buildBloc();
      await connectRaw(bloc);

      expect(bloc.state.status, LiveConnectionStatus.retrying);
      expect(bloc.state.issue?.issue, LiveIssue.network);
      await bloc.close();
    });

    test('重试之后会再连一次', () async {
      fake.failNext = true;
      final bloc = buildBloc(retryDelay: const Duration(milliseconds: 5));
      await connectRaw(bloc);

      fake.failNext = false;
      await waitFor(() => fake.connectCount > 0);

      expect(fake.connectCount, greaterThan(0));
      await bloc.close();
    });

    test('关掉开关之后不再重试', () async {
      fake.failNext = true;
      final bloc = buildBloc(retryDelay: const Duration(milliseconds: 5));
      await connectRaw(bloc);
      await bloc.setEnabled(false);

      // 这里是在证明「不会发生」，只能等一段时间看它没发生；等够几个重试
      // 周期就行，所以是固定延时而非 waitFor。
      final countAfterDisable = fake.connectCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fake.connectCount, countAfterDisable);
      expect(bloc.state.status, LiveConnectionStatus.off);
      await bloc.close();
    });
  });

  group('共享光标', () {
    test('挂上盘面后光标落在中央', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      expect(bloc.state.cursor, const LiveCursor(5, 5));
      await bloc.close();
    });

    test('方向弹幕移动光标', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右'));
      expect(bloc.state.cursor, const LiveCursor(6, 5));

      await feed(says('上'));
      expect(bloc.state.cursor, const LiveCursor(6, 4));

      await feed(says('w')); // 也认 WASD
      expect(bloc.state.cursor, const LiveCursor(6, 3));

      await bloc.close();
    });

    test('撞到边界就停住，不环绕', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 3, height: 3);

      await feed(says('右'));
      await feed(says('右'));
      await feed(says('右'));
      expect(bloc.state.cursor, const LiveCursor(2, 1));

      await bloc.close();
    });

    test('换局到更小的盘面时光标被夹回来', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 20, height: 20);
      expect(bloc.state.cursor, const LiveCursor(10, 10));

      // 换到 5x5 的自定义局
      bloc.updateBounds(width: 5, height: 5);

      expect(bloc.state.cursor, const LiveCursor(4, 4));
      expect(bloc.state.width, 5);
      await bloc.close();
    });

    test('退化的尺寸不会把光标弄坏', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      bloc.updateBounds(width: 0, height: 0);
      // 尺寸非法时直接忽略，保持原样
      expect(bloc.state.cursor, const LiveCursor(5, 5));
      expect(bloc.state.width, 10);
      await bloc.close();
    });

    test('闲聊计入 ignored，不计入 accepted', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('主播加油'));
      await feed(says('哈哈哈'));
      await feed(says('右'));

      expect(bloc.state.ignored, 2);
      expect(bloc.state.accepted, 1);
      await bloc.close();
    });

    test('没挂盘面时指令进 ignored', () async {
      final bloc = buildBloc();
      await connect(bloc);
      await feed(says('右'));

      expect(bloc.state.accepted, 0);
      expect(bloc.state.ignored, 1);
      await bloc.close();
    });
  });

  group('指令应用', () {
    test('动作落在光标所在格子', () async {
      final applied = <String>[];
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          applied.add(
            '${action.name}@${position.x.toInt()},${position.y.toInt()}',
          );
        },
        width: 10,
        height: 10,
      );

      await feed(says('右')); // 光标到 (6,5)
      await feed(danmaku); // 开
      await pumpEventQueue();

      expect(applied, ['open@6,5']);
      await bloc.close();
    });

    test('一批指令串行应用，不并发', () async {
      var active = 0;
      var maxActive = 0;
      final order = <String>[];

      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          active++;
          maxActive = math.max(maxActive, active);
          order.add(position.x.toString());
          await Future<void>.delayed(const Duration(milliseconds: 2));
          active--;
        },
        width: 10,
        height: 10,
      );

      // 同一批到达：三条「开」，中间夹一次移动
      fake.latest.add(says('开', uname: 'a'));
      fake.latest.add(says('右', uname: 'b'));
      fake.latest.add(says('开', uname: 'c'));
      await waitFor(() => order.length == 2);

      // 关键：任何时刻只有一个动作在跑。并发进去的话 _updateState 的 await
      // 窗口会让某些 emit 带上过期的 areas。
      expect(maxActive, 1, reason: '指令不能并发应用');
      expect(order.length, 2);
      await bloc.close();
    });

    test('位置在到达那一刻就定下来', () async {
      final positions = <String>[];
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          positions.add('${position.x.toInt()},${position.y.toInt()}');
        },
        width: 10,
        height: 10,
      );

      // 中央是 (5,5)：先「开」再「右」再「开」
      await feed(says('开'));
      await feed(says('右'));
      await feed(says('开'));
      await pumpEventQueue();

      // 第二条「开」落在移动之后的 (6,5)，而且不会因为排队而漂到别处
      expect(positions, ['5,5', '6,5']);
      await bloc.close();
    });

    test('一条弹幕里先移动后动作，落点在移动之后', () async {
      final positions = <String>[];
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          positions.add('${position.x.toInt()},${position.y.toInt()}');
        },
        width: 10,
        height: 10,
      );

      // 从中央 (5,5) 往下三格再挖开 -> 应该落在 (5,8)，不是 (5,5)
      await feed(says('3下开'));
      await pumpEventQueue();

      expect(positions, ['5,8']);
      expect(bloc.state.cursor, const LiveCursor(5, 8));
      await bloc.close();
    });

    test('一条弹幕里多个动作各落在它前面的移动之后', () async {
      final positions = <String>[];
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          positions.add('${position.x.toInt()},${position.y.toInt()}');
        },
        width: 10,
        height: 10,
      );

      // 原地开 -> 右三格再开
      await feed(says('开3右开'));
      await pumpEventQueue();

      expect(positions, ['5,5', '8,5']);
      expect(bloc.state.cursor, const LiveCursor(8, 5));
      await bloc.close();
    });

    test('带次数的一串操作一次 emit 完', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('3下2右'));

      // 一条弹幕只算一条 accepted，光标一次到位
      expect(bloc.state.accepted, 1);
      expect(bloc.state.cursor, const LiveCursor(7, 8));
      await bloc.close();
    });

    test('一串移动撞到边界只夹一次', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 5, height: 5);

      // (2,2) 往右下各 9 格 -> 夹到 (4,4)
      await feed(says('9右9下'));

      expect(bloc.state.cursor, const LiveCursor(4, 4));
      await bloc.close();
    });

    test('一条失败不影响后面的', () async {
      final positions = <String>[];
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          positions.add(position.x.toString());
          if (positions.length == 1) {
            throw StateError('第一条就炸');
          }
        },
        width: 10,
        height: 10,
      );

      await feed(says('开'));
      await feed(says('右'));
      await feed(says('开'));
      await waitFor(() => positions.length == 2);

      expect(positions.length, 2, reason: '一次失败不能把整条链打断');
      await bloc.close();
    });

    test('排队期间摘掉盘面就不发了', () async {
      // 用 Completer 把第一条卡住，人工造出「队列里还排着东西」的窗口，
      // 这样不依赖任何时序。
      final gate = Completer<void>();
      final invoked = <String>[];

      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(
        applyAction: (action, position) async {
          invoked.add(position.x.toString());
          await gate.future;
        },
        width: 10,
        height: 10,
      );

      await feed(says('开')); // 第一条开始执行，卡在 gate 上
      await feed(says('开')); // 第二条排在它后面
      bloc.detach(); // 主播退出对局

      gate.complete();
      await pumpEventQueue();

      // 第二条执行时读到 _applyAction 已经是 null，于是不发
      expect(invoked.length, 1);
      await bloc.close();
    });
  });

  group('归因', () {
    test('记下最近一条生效的指令是谁发的', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右', uname: '甲'));

      expect(bloc.state.lastCommand?.uname, '甲');
      expect(bloc.state.lastCommand?.text, '右');
      expect(bloc.state.lastCommand?.steps, const [
        MoveCursor(CursorDirection.right),
      ]);
      await bloc.close();
    });

    test('闲聊不覆盖归因', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右', uname: '甲'));
      await feed(says('哈哈哈', uname: '乙'));

      expect(bloc.state.lastCommand?.uname, '甲');
      await bloc.close();
    });

    test('动作指令也记归因', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('开', uname: '乙'));

      expect(bloc.state.lastCommand?.uname, '乙');
      // 归因存的是原文，不是展开后的操作
      expect(bloc.state.lastCommand?.text, '开');
      expect(bloc.state.lastCommand?.steps, const [ActAtCursor(Action.open)]);
      await bloc.close();
    });
  });

  group('粉丝牌门槛', () {
    test('默认要粉丝牌，没牌子的弹幕被丢掉', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右', medalLevel: 0, medalRoomId: 0));

      expect(bloc.state.requireMedal, isTrue);
      expect(bloc.state.accepted, 0);
      expect(bloc.state.cursor, const LiveCursor(5, 5));
      // 门槛挡下的弹幕不进 ignored：没牌子的弹幕占绝大多数，每条都 emit 一次
      // 会把监听 LiveState 的界面刷爆。
      expect(bloc.state.ignored, 0);
      await bloc.close();
    });

    test('戴别家的牌子也过不了', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      // 30 级的别家牌子——只看 medalLevel > 0 就会误放
      await feed(says('右', medalLevel: 30, medalRoomId: 99999));

      expect(bloc.state.accepted, 0);
      expect(bloc.state.cursor, const LiveCursor(5, 5));
      await bloc.close();
    });

    test('戴本房牌子能过', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右', medalLevel: 1, medalRoomId: testRoomId));

      expect(bloc.state.accepted, 1);
      expect(bloc.state.cursor, const LiveCursor(6, 5));
      await bloc.close();
    });

    test('关掉之后访客也能操作', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);
      await bloc.setRequireMedal(false);

      // 没牌子的
      await feed(says('右', medalLevel: 0, medalRoomId: 0));
      expect(bloc.state.cursor, const LiveCursor(6, 5));

      // 戴别家牌子的也放行
      await feed(says('下', medalLevel: 30, medalRoomId: 99999));
      expect(bloc.state.cursor, const LiveCursor(6, 6));

      await bloc.close();
    });

    test('开关会持久化', () async {
      final bloc = buildBloc();
      await connect(bloc);
      await bloc.setRequireMedal(false);

      final fresh = buildBloc();
      await fresh.load();
      await pumpEventQueue();

      expect(fresh.state.requireMedal, isFalse);
      await bloc.close();
      await fresh.close();
    });

    test('房间号还不知道时不放行，但不会崩', () async {
      final bloc = buildBloc();
      await connectRaw(bloc); // 不发 hello，roomId 还是 null
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);

      await feed(says('右'));

      expect(bloc.state.roomId, isNull);
      expect(bloc.state.accepted, 0);
      await bloc.close();
    });

    test('门槛关掉后，房间号未知也照样放行', () async {
      // 门槛关掉就不靠房间号判断了
      final bloc = buildBloc();
      await connectRaw(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);
      await bloc.setRequireMedal(false);

      await feed(says('右', medalLevel: 0, medalRoomId: 0));

      expect(bloc.state.cursor, const LiveCursor(6, 5));
      await bloc.close();
    });
  });

  group('房间号与凭据', () {
    test('开了但没填房间号就不连，并说明原因', () async {
      final bloc = buildBloc();
      await repository.setBool('live_enabled', true);
      await bloc.load();
      await pumpEventQueue();

      expect(fake.connectCount, 0);
      expect(bloc.state.status, LiveConnectionStatus.off);
      expect(bloc.state.enabled, isTrue);
      expect(bloc.state.issue?.issue, LiveIssue.missingRoomId);
      await bloc.close();
    });

    test('填了房间号就连，并把房间号传给客户端', () async {
      final bloc = buildBloc();
      await repository.setBool('live_enabled', true);
      await bloc.load();
      await pumpEventQueue();
      expect(fake.connectCount, 0);

      await bloc.setRoomId(12345);
      await pumpEventQueue();

      expect(fake.connectCount, 1);
      expect(fake.lastRoomId, 12345);
      await bloc.close();
    });

    test('改房间号会重连', () async {
      final bloc = buildBloc();
      await connectRaw(bloc);
      expect(fake.connectCount, 1);

      await bloc.setRoomId(999);
      await pumpEventQueue();

      expect(fake.connectCount, 2);
      expect(fake.lastRoomId, 999);
      await bloc.close();
    });

    test('清空房间号会断开并停止重试', () async {
      final bloc = buildBloc();
      await connectRaw(bloc);
      expect(fake.connectCount, 1);

      await bloc.setRoomId(null);
      await pumpEventQueue();

      // 同上：证明「不再重试」只能等一段时间观察。
      final count = fake.connectCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fake.connectCount, count, reason: '清空之后不该继续重试');
      expect(bloc.state.status, LiveConnectionStatus.off);
      expect(bloc.state.issue?.issue, LiveIssue.missingRoomId);
      await bloc.close();
    });

    test('SESSDATA 会传给客户端', () async {
      final bloc = buildBloc();
      await connectRaw(bloc);

      await bloc.setSessdata('abc123');
      await pumpEventQueue();

      expect(fake.lastSessdata, 'abc123');
      await bloc.close();
    });

    test('房间号存得住，重开还记得', () async {
      final bloc = buildBloc();
      await bloc.setRoomId(4242);

      final fresh = buildBloc();
      await repository.setBool('live_enabled', true);
      await fresh.load();
      await pumpEventQueue();

      expect(fake.lastRoomId, 4242);
      await bloc.close();
      await fresh.close();
    });
  });

  group('断开', () {
    test('关掉开关后光标留着，重新打开接着用', () async {
      final bloc = buildBloc();
      await connect(bloc);
      bloc.attach(applyAction: (_, _) async {}, width: 10, height: 10);
      await feed(says('右'));

      await bloc.setEnabled(false);
      expect(bloc.state.cursor, const LiveCursor(6, 5));

      await bloc.setEnabled(true);
      expect(bloc.state.cursor, const LiveCursor(6, 5));
      await bloc.close();
    });
  });
}
