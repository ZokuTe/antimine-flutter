import 'package:antimine/features/live/data/live_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LiveDanmaku danmaku({int medalLevel = 3, int medalRoomId = 5440}) {
    return LiveDanmaku(
      text: '开',
      uid: 1,
      uname: '某人',
      medalLevel: medalLevel,
      medalRoomId: medalRoomId,
    );
  }

  group('hasMedalOf', () {
    test('本房牌子才算', () {
      expect(danmaku().hasMedalOf(5440), isTrue);
    });

    test('别家牌子不算', () {
      // 30 级的别家牌子——只看 medalLevel > 0 就会误判
      expect(
        danmaku(medalLevel: 30, medalRoomId: 99999).hasMedalOf(5440),
        isFalse,
      );
    });

    test('没牌子不算', () {
      expect(danmaku(medalLevel: 0).hasMedalOf(5440), isFalse);
    });

    test('房间号未知时不算', () {
      // 宁可漏也不放错
      expect(danmaku().hasMedalOf(null), isFalse);
    });
  });
}
