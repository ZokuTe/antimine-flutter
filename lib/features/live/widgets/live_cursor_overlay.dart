import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/flame/game_renderer.dart';
import '../logic/edge_indicator.dart';
import '../logic/live_cursor.dart';

/// 共享光标的覆盖层：光标在窗口里就画一个框，跑出去了就在边缘画箭头。
///
/// **整层包在 [IgnorePointer] 里**——这是主播还能自己操作的关键。弹幕玩法
/// 不能把主播的点击挡掉，所以这一层只画东西，不接收任何指针事件。
///
/// 位置每帧现算：相机可以被平移和缩放，光标在世界里不动，屏幕位置却会变。
/// 用 Ticker 而不是监听 bloc 状态，是因为相机的变化不经过 bloc——它直接改
/// Flame 的 `camera`。桌面端常驻一个轻量 ticker 是可以接受的代价，换来的
/// 是不用在每个相机入口手动通知覆盖层。
class LiveCursorOverlay extends StatefulWidget {
  const LiveCursorOverlay({
    super.key,
    required this.renderer,
    required this.cursor,
    this.inset = EdgeInsets.zero,
  });

  final GameRenderer renderer;

  /// 共享光标在哪一格。
  final LiveCursor cursor;

  /// 避开 AppBar 和底部操作栏。箭头会被推进这个内边距之内。
  final EdgeInsets inset;

  /// 光标高亮的颜色。挑的是在深色和浅色盘面上都能看清的高饱和色。
  static const accent = Color(0xFF00E5FF);

  @override
  State<LiveCursorOverlay> createState() => _LiveCursorOverlayState();
}

class _LiveCursorOverlayState extends State<LiveCursorOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  Offset? _center;
  double _areaSize = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _syncPosition())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 每帧重算屏幕位置，值没变就跳过 rebuild。
  void _syncPosition() {
    if (!mounted || !widget.renderer.canProjectAreas) {
      return;
    }

    final center = widget.renderer.screenCenterOfArea(
      widget.cursor.x,
      widget.cursor.y,
    );
    final areaSize = widget.renderer.areaScreenSize;

    if (_center == center && _areaSize == areaSize) {
      return;
    }

    setState(() {
      _center = center;
      _areaSize = areaSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;

    // 整层是 IgnorePointer，所以就算它一直占着整块区域，主播的点击也照样
    // 穿透到游戏。不需要在别处再包一层。
    if (center == null) {
      // GameRenderer 还在 onLoad，量不出坐标，先不画。
      return const IgnorePointer(child: SizedBox.shrink());
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: LayoutBuilder(
          builder:
              (context, constraints) => _buildContent(
                constraintSize: constraints.biggest,
                center: center,
              ),
        ),
      ),
    );
  }

  Widget _buildContent({required Size constraintSize, required Offset center}) {
    final indicator = edgeIndicatorFor(
      target: center,
      viewport: constraintSize,
      inset: widget.inset,
    );

    // 光标在窗口外：原地不画东西，只在边缘给个方向。
    if (indicator != null) {
      return _buildArrow(indicator);
    }
    return _buildCursor(center);
  }

  Widget _buildCursor(Offset center) {
    // 跟着格子大小走，但夹一下：缩到很小时也得看得见，放到很大时别糊满屏。
    final side = _areaSize.clamp(14.0, 120.0);

    return Stack(
      children: [
        Positioned(
          left: center.dx - side / 2,
          top: center.dy - side / 2,
          width: side,
          height: side,
          child: DecoratedBox(
            key: const ValueKey('live-cursor'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(side * 0.15),
              // 白色描边打底 + 高饱和色，深浅盘面上都能看清。
              border: Border.all(
                color: LiveCursorOverlay.accent,
                width: (side * 0.08).clamp(1.5, 4.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArrow(EdgeIndicator indicator) {
    const size = 36.0;
    return Stack(
      children: [
        Positioned(
          left: indicator.position.dx - size / 2,
          top: indicator.position.dy - size / 2,
          width: size,
          height: size,
          // 角度 0 指向右，和 Icons.play_arrow 的朝向一致。
          child: Transform.rotate(
            angle: indicator.angle,
            child: const DecoratedBox(
              key: ValueKey('live-edge-arrow'),
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Icon(
                Icons.play_arrow_rounded,
                size: size,
                color: LiveCursorOverlay.accent,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
