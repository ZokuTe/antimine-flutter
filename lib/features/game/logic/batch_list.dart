import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../common/models/minefield.dart';
import '../flame/components/component_constants.dart';

/// Accumulates the sprites one board layer draws, in world coordinates.
///
/// Each cell is baked into an absolute [RSTransform] (the layer itself sits at
/// the origin), so the batch is a flat list of positioned quads sharing one
/// atlas. The entries are staged here and flushed into a
/// [SpriteBatch] by [toSpriteBatch], because the batch needs the atlas, which
/// is only available once the layer has finished loading it.
class BatchList {
  BatchList({required double areaSize, required this.minefield})
    : areaSize = areaSize.roundToDouble();

  final List<RSTransform> _transforms = [];
  final List<Rect> _rects = [];
  final List<Color> _colors = [];

  /// The sprites staged so far, exposed for inspection and tests.
  List<RSTransform> get transforms => List.unmodifiable(_transforms);
  List<Rect> get rects => List.unmodifiable(_rects);
  List<Color> get colors => List.unmodifiable(_colors);

  double _x = 0;
  double _y = 0;
  Color color = Colors.white;

  final double areaSize;
  final Minefield minefield;

  bool get isEmpty => _rects.isEmpty;

  Vector2 get position => Vector2(_x.toDouble(), _y.toDouble());

  set x(double x) {
    _x = x;
  }

  set y(double y) {
    _y = y;
  }

  void add(Rect rect, [int padding = 0, double dx = 0.0, double dy = 0.0]) {
    _transforms.add(_transformOf(_x, _y, padding, dx, dy));
    _rects.add(rect);
    _colors.add(color);
  }

  void clear() {
    _transforms.clear();
    _rects.clear();
    _colors.clear();
  }

  /// Flushes the staged sprites into a [SpriteBatch] bound to [atlas].
  ///
  /// [SpriteBatch.render] scans its colours to decide whether it can pass a
  /// null colour list to `drawAtlas`, so the batch is built once per board
  /// change and reused from the layer's snapshot rather than per frame.
  SpriteBatch toSpriteBatch(Image atlas) {
    final batch = SpriteBatch(
      atlas,
      defaultColor: Colors.white,
      defaultBlendMode: BlendMode.modulate,
    );
    for (var i = 0; i < _rects.length; i++) {
      batch.addTransform(
        source: _rects[i],
        transform: _transforms[i],
        color: _colors[i],
      );
    }
    return batch;
  }

  RSTransform _transformOf(
    double x,
    double y, [
    int padding = 0,
    double dx = 0.0,
    double dy = 0.0,
  ]) {
    final areaSize = this.areaSize;
    final scale =
        (areaSize - padding + extraPadding).toDouble() /
        ComponentConstants.spriteSize;
    final double tx =
        (x + dx) * areaSize -
        extraPadding2 +
        padding * 0.5 -
        minefield.width * areaSize * 0.5;
    final double ty =
        (y + dy) * areaSize -
        extraPadding2 +
        padding * 0.5 -
        minefield.height * areaSize * 0.5;
    return RSTransform(scale, 0.0, tx, ty);
  }

  static const extraPadding = 0.5;
  static const extraPadding2 = extraPadding * 0.5;
}
