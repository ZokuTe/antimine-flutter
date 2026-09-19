import 'dart:math' as math;

import 'package:antimine/features/live/logic/edge_indicator.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(400, 300);

  group('光标在窗口内不需要箭头', () {
    test('正中间', () {
      expect(
        edgeIndicatorFor(target: const Offset(200, 150), viewport: viewport),
        isNull,
      );
    });

    test('贴着左上角内侧', () {
      expect(
        edgeIndicatorFor(target: const Offset(1, 1), viewport: viewport),
        isNull,
      );
    });

    test('左下角内侧', () {
      expect(
        edgeIndicatorFor(target: const Offset(1, 298), viewport: viewport),
        isNull,
      );
    });

    test('落在 AppBar 底下也算在窗口内', () {
      // 判定用的是整个窗口而不是安全区：格子本身可见，不该再冒箭头
      expect(
        edgeIndicatorFor(
          target: const Offset(200, 30),
          viewport: viewport,
          inset: const EdgeInsets.only(top: 100),
        ),
        isNull,
      );
    });
  });

  group('跑到窗口外才有箭头', () {
    test('光标在右侧', () {
      final indicator =
          edgeIndicatorFor(target: const Offset(500, 150), viewport: viewport)!;
      expect(indicator.angle, closeTo(0, 1e-9));
      expect(indicator.position.dx, closeTo(400, 1e-9));
      expect(indicator.position.dy, closeTo(150, 1e-9));
    });

    test('光标在左侧', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(-100, 150),
            viewport: viewport,
          )!;
      expect(indicator.angle, closeTo(math.pi, 1e-9));
      expect(indicator.position.dx, closeTo(0, 1e-9));
    });

    test('光标在上方', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(200, -100),
            viewport: viewport,
          )!;
      expect(indicator.angle, closeTo(-math.pi / 2, 1e-9));
      expect(indicator.position.dy, closeTo(0, 1e-9));
    });

    test('光标在下方', () {
      final indicator =
          edgeIndicatorFor(target: const Offset(200, 500), viewport: viewport)!;
      expect(indicator.angle, closeTo(math.pi / 2, 1e-9));
      expect(indicator.position.dy, closeTo(300, 1e-9));
    });

    test('正方形窗口里斜方向正好落在角上', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(500, 500),
            viewport: const Size(400, 400),
          )!;
      expect(indicator.angle, closeTo(math.pi / 4, 1e-9));
      expect(indicator.position.dx, closeTo(400, 1e-9));
      expect(indicator.position.dy, closeTo(400, 1e-9));
    });

    test('非正方形窗口里斜方向只撞更近的那条边', () {
      // 400x300 的窗口，45° 射线先撞下边界而不是角：半宽 200、半高 150，
      // 高度方向的比例先用完，所以交点是 (350, 300) 而不是右下角。
      final indicator =
          edgeIndicatorFor(target: const Offset(500, 450), viewport: viewport)!;
      expect(indicator.angle, closeTo(math.pi / 4, 1e-9));
      expect(indicator.position.dx, closeTo(350, 1e-9));
      expect(indicator.position.dy, closeTo(300, 1e-9));
    });
  });

  group('inset 把箭头推进可见区域', () {
    test('顶部有 AppBar 时箭头压在 AppBar 下沿', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(200, -100),
            viewport: viewport,
            inset: const EdgeInsets.only(top: 100),
          )!;
      expect(indicator.position.dy, closeTo(100, 1e-9));
      // 方向从安全区中心量起，安全区是 (0,100)-(400,300)，中心 y=200
      expect(indicator.angle, closeTo(-math.pi / 2, 1e-9));
    });

    test('左右 inset 一起生效', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(900, 150),
            viewport: viewport,
            inset: const EdgeInsets.symmetric(horizontal: 40),
          )!;
      expect(indicator.position.dx, closeTo(360, 1e-9));
    });

    test('方向从安全区中心量，不是从相机中心', () {
      // inset 只在上边，安全区中心被压低到 y=200。
      // 光标在 (600, 200) 时箭头应该正好朝右；若按窗口中心 y=150 量，
      // 就会带上一个向下的分量。
      final indicator =
          edgeIndicatorFor(
            target: const Offset(600, 200),
            viewport: viewport,
            inset: const EdgeInsets.only(top: 100),
          )!;
      expect(indicator.angle, closeTo(0, 1e-9));
    });
  });

  group('退化输入不会算出 NaN', () {
    test('零尺寸窗口', () {
      expect(
        edgeIndicatorFor(target: const Offset(10, 10), viewport: Size.zero),
        isNull,
      );
    });

    test('负尺寸窗口', () {
      expect(
        edgeIndicatorFor(
          target: const Offset(10, 10),
          viewport: const Size(-100, -100),
        ),
        isNull,
      );
    });

    test('inset 大到吃光窗口时退回整个窗口', () {
      final indicator =
          edgeIndicatorFor(
            target: const Offset(500, 150),
            viewport: viewport,
            inset: const EdgeInsets.all(200),
          )!;
      expect(indicator.position.dx.isNaN, isFalse);
      expect(indicator.angle.isNaN, isFalse);
      expect(indicator.position.dx, closeTo(400, 1e-9));
    });
  });

  test('任意角度下箭头都落在安全区边界上', () {
    const inset = EdgeInsets.only(top: 60, bottom: 80);
    final safe = Rect.fromLTRB(0, 60, 400, 220);
    const far = 5000.0;

    for (var i = 0; i < 360; i++) {
      final angle = i * math.pi / 180;
      final target = Offset(
        200 + far * math.cos(angle),
        140 + far * math.sin(angle),
      );
      final indicator =
          edgeIndicatorFor(target: target, viewport: viewport, inset: inset)!;

      // 角度应指回目标。atan2 的值域是 (-π, π]，输入超过 180° 会被绕回来，
      // 所以按 2π 取模比差值。
      final diff = (indicator.angle - angle).abs() % (2 * math.pi);
      expect(
        math.min(diff, 2 * math.pi - diff),
        closeTo(0, 1e-6),
        reason: '角度 $i°',
      );
      // 位置落在安全区边界上（有一条边贴住，且不越界）
      expect(indicator.position.dx, greaterThanOrEqualTo(-1e-6));
      expect(indicator.position.dx, lessThanOrEqualTo(400 + 1e-6));
      expect(indicator.position.dy, greaterThanOrEqualTo(60 - 1e-6));
      expect(indicator.position.dy, lessThanOrEqualTo(220 + 1e-6));

      final onEdge =
          (indicator.position.dx - safe.left).abs() < 1e-6 ||
          (indicator.position.dx - safe.right).abs() < 1e-6 ||
          (indicator.position.dy - safe.top).abs() < 1e-6 ||
          (indicator.position.dy - safe.bottom).abs() < 1e-6;
      expect(onEdge, isTrue, reason: '角度 $i° 的位置没贴边');
    }
  });
}
