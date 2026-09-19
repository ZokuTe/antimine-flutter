import 'package:antimine/features/live/logic/live_command.dart';
import 'package:antimine/features/live/logic/live_cursor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 一个 5x5 的小盘面，边界好算
  const w = 5;
  const h = 5;

  group('movedBy 移动一格', () {
    test('四个方向各挪一格', () {
      const start = LiveCursor(2, 2);
      expect(
        start.movedBy(CursorDirection.up, width: w, height: h),
        const LiveCursor(2, 1),
      );
      expect(
        start.movedBy(CursorDirection.down, width: w, height: h),
        const LiveCursor(2, 3),
      );
      expect(
        start.movedBy(CursorDirection.left, width: w, height: h),
        const LiveCursor(1, 2),
      );
      expect(
        start.movedBy(CursorDirection.right, width: w, height: h),
        const LiveCursor(3, 2),
      );
    });

    test('一次只挪一格', () {
      const start = LiveCursor(2, 2);
      var cursor = start;
      for (var i = 0; i < 3; i++) {
        cursor = cursor.movedBy(CursorDirection.right, width: w, height: h);
      }
      expect(cursor, const LiveCursor(5 - 1, 2));
    });
  });

  group('撞边停在原地，绝不环绕', () {
    test('上边界', () {
      expect(
        const LiveCursor(2, 0).movedBy(CursorDirection.up, width: w, height: h),
        const LiveCursor(2, 0),
      );
    });

    test('下边界', () {
      expect(
        const LiveCursor(
          2,
          h - 1,
        ).movedBy(CursorDirection.down, width: w, height: h),
        const LiveCursor(2, h - 1),
      );
    });

    test('左边界', () {
      expect(
        const LiveCursor(
          0,
          2,
        ).movedBy(CursorDirection.left, width: w, height: h),
        const LiveCursor(0, 2),
      );
    });

    test('右边界不绕回最左边', () {
      // 这是环绕实现会出错的地方：应该停在 x=4，不是跳到 x=0
      expect(
        const LiveCursor(
          w - 1,
          3,
        ).movedBy(CursorDirection.right, width: w, height: h),
        const LiveCursor(w - 1, 3),
      );
    });

    test('撞边时另一个轴不受影响', () {
      // y 撞上边界，x 应该保持不动
      expect(
        const LiveCursor(3, 0).movedBy(CursorDirection.up, width: w, height: h),
        const LiveCursor(3, 0),
      );
    });
  });

  group('clampedTo 换局后收进新盘面', () {
    test('盘面变小', () {
      // 标准局 20x20 里的光标，换到 5x5 的自定义局
      expect(
        const LiveCursor(15, 15).clampedTo(width: 5, height: 5),
        const LiveCursor(4, 4),
      );
    });

    test('盘面变大时不动', () {
      expect(
        const LiveCursor(2, 3).clampedTo(width: 20, height: 20),
        const LiveCursor(2, 3),
      );
    });

    test('宽高只缩一个轴', () {
      expect(
        const LiveCursor(3, 18).clampedTo(width: 20, height: 5),
        const LiveCursor(3, 4),
      );
    });

    test('负坐标被拉回 0', () {
      // 正常流程不该出现，但真出现时不能留个盘外坐标给后面的指令
      expect(
        const LiveCursor(-3, -7).clampedTo(width: 5, height: 5),
        const LiveCursor(0, 0),
      );
    });

    test('零宽高不会抛异常', () {
      // 窗口还没测量出来时的退化情形，clamp 的下界会大于上界
      expect(
        const LiveCursor(3, 3).clampedTo(width: 0, height: 0),
        const LiveCursor(0, 0),
      );
    });
  });

  group('center 新局落点', () {
    test('偶数尺寸取中点', () {
      expect(LiveCursor.center(width: 12, height: 20), const LiveCursor(6, 10));
    });

    test('奇数尺寸向下取整', () {
      expect(LiveCursor.center(width: 5, height: 5), const LiveCursor(2, 2));
    });

    test('结果一定在盘内', () {
      // 从 1 起：0x0 的盘面没有「里面」，center 只是退化成 (0,0)，见下一个用例
      for (var size = 1; size < 30; size++) {
        final cursor = LiveCursor.center(width: size, height: size);
        expect(
          cursor.isInside(width: size, height: size),
          isTrue,
          reason: '尺寸 $size',
        );
      }
    });

    test('0x0 的盘面没有「里面」', () {
      final cursor = LiveCursor.center(width: 0, height: 0);
      expect(cursor, const LiveCursor(0, 0));
      expect(cursor.isInside(width: 0, height: 0), isFalse);
    });

    test('退化尺寸给 (0,0)', () {
      expect(LiveCursor.center(width: 0, height: 0), const LiveCursor(0, 0));
    });
  });

  group('isInside', () {
    test('四个角都在盘内', () {
      expect(const LiveCursor(0, 0).isInside(width: w, height: h), isTrue);
      expect(const LiveCursor(w - 1, 0).isInside(width: w, height: h), isTrue);
      expect(const LiveCursor(0, h - 1).isInside(width: w, height: h), isTrue);
      expect(
        const LiveCursor(w - 1, h - 1).isInside(width: w, height: h),
        isTrue,
      );
    });

    test('刚出界一格就不算', () {
      expect(const LiveCursor(w, 0).isInside(width: w, height: h), isFalse);
      expect(const LiveCursor(0, h).isInside(width: w, height: h), isFalse);
      expect(const LiveCursor(-1, 0).isInside(width: w, height: h), isFalse);
    });
  });

  group('值相等性', () {
    test('同坐标相等且哈希一致', () {
      expect(const LiveCursor(1, 2), const LiveCursor(1, 2));
      expect(const LiveCursor(1, 2).hashCode, const LiveCursor(1, 2).hashCode);
    });

    test('不同坐标不相等', () {
      expect(const LiveCursor(1, 2), isNot(const LiveCursor(2, 1)));
    });
  });
}
