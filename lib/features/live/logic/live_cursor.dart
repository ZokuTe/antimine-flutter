import 'live_command.dart';

/// 所有人共享的那个光标，用**格子坐标**表示。
///
/// 刻意不存屏幕坐标：主播平移或缩放相机时光标得留在同一个格子上，
/// 存屏幕坐标会跟着漂。屏幕位置由 `GameRenderer` 的逆变换现算。
class LiveCursor {
  const LiveCursor(this.x, this.y);

  final int x;
  final int y;

  /// 按方向挪一格，撞到边界就停在原地。
  ///
  /// 不做环绕：人多的时候来回反向的弹幕会把光标推得完全不可预测，
  /// 撞边停住至少是可解释的。
  LiveCursor movedBy(
    CursorDirection direction, {
    required int width,
    required int height,
  }) {
    final next = switch (direction) {
      CursorDirection.up => LiveCursor(x, y - 1),
      CursorDirection.down => LiveCursor(x, y + 1),
      CursorDirection.left => LiveCursor(x - 1, y),
      CursorDirection.right => LiveCursor(x + 1, y),
    };
    return next.clampedTo(width: width, height: height);
  }

  /// 夹进 `width`×`height` 的范围里。
  ///
  /// 换局之后必须调一次：标准局和自定义局的盘面尺寸不同，光标会停在一个
  /// 新盘面上不存在的格子里，后续指令就落在盘外了。
  LiveCursor clampedTo({required int width, required int height}) {
    final maxX = width - 1;
    final maxY = height - 1;
    // 宽高可能是 0（窗口还没测量出来），此时 max 为负，clamp 的上下界会反过来，
    // 所以先兜住。
    return LiveCursor(
      maxX < 0 ? 0 : x.clamp(0, maxX),
      maxY < 0 ? 0 : y.clamp(0, maxY),
    );
  }

  /// 盘面中央，新局的落点。
  static LiveCursor center({required int width, required int height}) {
    return LiveCursor(
      width ~/ 2,
      height ~/ 2,
    ).clampedTo(width: width, height: height);
  }

  bool isInside({required int width, required int height}) {
    return x >= 0 && y >= 0 && x < width && y < height;
  }

  @override
  bool operator ==(Object other) {
    return other is LiveCursor && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'LiveCursor($x, $y)';
}
