import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 窗口边缘的方向指示器。
///
/// 只在光标跑到窗口外面时才需要——[position] 已经落在安全区的边界上，
/// [angle] 是箭头该转的角度（弧度，0 指向右，顺时针为正，和 `Canvas.rotate` 一致）。
class EdgeIndicator {
  const EdgeIndicator({required this.position, required this.angle});

  final Offset position;
  final double angle;

  @override
  bool operator ==(Object other) =>
      other is EdgeIndicator &&
      other.position == position &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(position, angle);

  @override
  String toString() =>
      'EdgeIndicator(${position.dx.toStringAsFixed(1)}, '
      '${position.dy.toStringAsFixed(1)}, $angle)';
}

/// 算出光标跑出窗口后，边缘箭头该出现在哪、朝哪边。
///
/// [target] 是光标在窗口坐标系里的位置，[viewport] 是窗口大小。
/// 返回 `null` 表示光标还在窗口里，不需要箭头——该在原地画高亮。
///
/// [inset] 用来把箭头推进可见区域：顶部有 AppBar、底部有操作栏，
/// 贴在真正边缘会被它们盖掉。
///
/// 方向是从安全区**中心**量过去的，不是从相机中心。两者在 inset 不对称时
/// 并不重合，而玩家视线盯的是可见区域中心。
EdgeIndicator? edgeIndicatorFor({
  required Offset target,
  required Size viewport,
  EdgeInsets inset = EdgeInsets.zero,
}) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    return null;
  }

  // 判定「在不在窗口里」用的是整个窗口，不是安全区：光标落在 AppBar 底下时
  // 格子本身是可见的，不该再冒一个箭头出来。
  if ((Offset.zero & viewport).contains(target)) {
    return null;
  }

  final safe = _safeRect(viewport, inset);
  final center = safe.center;
  final delta = target - center;

  // 射线与安全区边界求交：两个轴各算一次，取更早撞上的那个。
  // 某个分量为 0 时该轴不构成限制，记成无穷大。
  final halfWidth = safe.width / 2;
  final halfHeight = safe.height / 2;
  final scaleX =
      delta.dx.abs() < _epsilon ? double.infinity : halfWidth / delta.dx.abs();
  final scaleY =
      delta.dy.abs() < _epsilon ? double.infinity : halfHeight / delta.dy.abs();

  final scale = math.min(scaleX, scaleY);
  if (!scale.isFinite) {
    // 目标既在窗口外又和中心重合，说明窗口退化成了零面积，没什么可指的。
    return null;
  }

  return EdgeIndicator(
    position: center + delta * scale,
    angle: math.atan2(delta.dy, delta.dx),
  );
}

/// 扣掉 inset 之后仍可用的区域。inset 大到把窗口吃光时退回整个窗口，
/// 免得算出负的宽高再变成 NaN。
Rect _safeRect(Size viewport, EdgeInsets inset) {
  final rect = Rect.fromLTRB(
    inset.left,
    inset.top,
    viewport.width - inset.right,
    viewport.height - inset.bottom,
  );
  if (rect.width <= 0 || rect.height <= 0) {
    return Offset.zero & viewport;
  }
  return rect;
}

const double _epsilon = 1e-9;
