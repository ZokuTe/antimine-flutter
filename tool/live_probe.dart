// 协议冒烟测试：直连一个 B 站直播间，把收到的东西打出来。
//
//   dart run tool/live_probe.dart <房间号> [秒数]
//
// 纯 Dart，不碰 Flutter，所以能脱离界面单独跑。改过
// `bilibili_danmaku_client.dart` 的协议逻辑之后先跑这个。
import 'dart:async';
import 'dart:io';

import 'package:antimine/features/live/data/bilibili_danmaku_client.dart';
import 'package:antimine/features/live/data/live_event.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/live_probe.dart <房间号> [秒数]');
    exit(64);
  }

  final roomId = int.parse(args.first);
  final seconds = args.length > 1 ? int.parse(args[1]) : 20;
  final sessdata = Platform.environment['BILI_SESSDATA'];

  stdout.writeln(
    '连房间 $roomId，抓 $seconds 秒'
    '${sessdata == null || sessdata.isEmpty ? '（匿名）' : '（带 SESSDATA）'}',
  );

  var danmaku = 0;
  var withMedal = 0;
  var heartbeats = 0;
  final samples = <String>[];

  final client = BilibiliDanmakuClient();
  final subscription = client
      .connect(roomId: roomId, sessdata: sessdata)
      .listen(
        (event) {
          switch (event) {
            case LiveHello():
              stdout.writeln('hello: 真实房间号 = ${event.roomId}');
            case LiveDanmaku():
              danmaku++;
              if (event.medalLevel > 0) {
                withMedal++;
              }
              if (samples.length < 8) {
                samples.add(
                  '  ${event.uname} | ${event.text} | '
                  '牌子 ${event.medalLevel} 级 / 房间 ${event.medalRoomId}',
                );
              }
            case LiveHeartbeat():
              heartbeats++;
          }
        },
        onError: (Object error) {
          stderr.writeln('错误: $error');
        },
        onDone: () {
          stdout.writeln('连接关闭');
        },
      );

  await Future<void>.delayed(Duration(seconds: seconds));
  await subscription.cancel();

  stdout
    ..writeln()
    ..writeln('弹幕 $danmaku 条，其中带牌子 $withMedal 条，心跳 $heartbeats 次')
    ..writeln('样例：');
  for (final line in samples) {
    stdout.writeln(line);
  }

  if (danmaku > 0 && withMedal > 0) {
    stdout.writeln('结果：协议可用，粉丝牌字段拿得到');
  } else if (danmaku > 0) {
    stdout.writeln('结果：协议可用，但这个房间这段时间没人带牌子');
  } else {
    stdout.writeln('结果：一条都没收到（房间没开播？或者协议挂了）');
  }

  exit(0);
}
