import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_bloc/flame_bloc.dart';

import '../../../../common/models/area.dart';
import '../../../../common/models/minefield.dart';
import '../../../../common/models/skins/skin.dart';
import '../../../../common/models/themes/game_theme.dart';
import '../../bloc/game_bloc.dart';
import '../../bloc/game_state.dart';
import '../../logic/batch_list.dart';
import '../../flame/game_renderer.dart';
import 'component_constants.dart';

class CommonLayerComponent extends ShapeComponent
    with
        HasGameRef<GameRenderer>,
        FlameBlocListenable<GameBloc, GameState>,
        Snapshot {
  Minefield? minefield;
  Iterable<Area>? areas;

  final double areaSize;
  final Skin skin;
  final GameTheme theme;

  late Sprite sprite;
  late Image atlas;

  /// The atlas is only available after `onLoad`, which can run after the first
  /// `onNewState`, so the batch is built lazily once both have happened.
  bool _atlasLoaded = false;

  SpriteBatch? spriteBatch;

  BatchList? batchList;
  bool visible = true;

  CommonLayerComponent({
    required this.areaSize,
    required this.skin,
    required this.theme,
  }) {
    paint
      ..isAntiAlias = false
      ..strokeWidth = 0.0
      ..filterQuality = FilterQuality.none;
  }

  /// Builds the batch once the atlas has loaded and a board exists.
  ///
  /// `onNewState` runs before `onLoad` finishes, so the batch cannot be built
  /// at the point the layout is computed; whichever of the two arrives last
  /// triggers this.
  void rebuildSpriteBatch() {
    final batchList = this.batchList;
    if (!_atlasLoaded || batchList == null) {
      return;
    }
    // Always replace the batch, including with an empty one: keeping the
    // previous game's batch here is what let its sprites outlive it.
    spriteBatch = batchList.toSpriteBatch(atlas);
    invalidateSnapshot();
  }

  @override
  Future<void> onLoad() async {
    atlas = await gameRef.images.load(skin.skin);
    sprite = Sprite(
      atlas,
      srcPosition: Vector2.zero(),
      srcSize: ComponentConstants.srcSize,
    );
    _atlasLoaded = true;
    rebuildSpriteBatch();
  }

  @override
  void update(double dt) {
    _refreshFilterQuality();
  }

  /// Set when the batch this layer draws has been rebuilt. The cached
  /// snapshot is dropped on the next render, which records the new batch once
  /// and then reuses it.
  bool _snapshotStale = true;

  /// Marks the cached snapshot as no longer matching the board.
  ///
  /// Every subclass rebuilds its `batchList` in `onNewState`, so the cache has
  /// to be dropped there or the layer would keep drawing the previous frame
  /// forever.
  void invalidateSnapshot() {
    _snapshotStale = true;
  }

  @override
  void renderTree(Canvas canvas) {
    // `Snapshot` records whatever `render` draws, and `render` bails out while
    // the layer is hidden. Recording in that state would cache an empty
    // picture and mark it valid, so the layer would draw nothing even after
    // being shown again — which is how flags from the previous game survived
    // into the next one. Snapshots are therefore only taken when visible.
    if (!visible) {
      clearSnapshot();
      _snapshotStale = true;
      return;
    }

    // Must run before the mixin inspects its cached picture: `clearSnapshot`
    // inside `render` would be too late, because the mixin decides whether to
    // replay or record without ever calling `render` again.
    if (_snapshotStale) {
      clearSnapshot();
      _snapshotStale = false;
    }
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    if (!visible) {
      return;
    }

    final batch = spriteBatch;

    if (batch != null && !batch.isEmpty) {
      // This draw is what the `Snapshot` mixin records. Once a picture exists
      // the mixin replays it instead of calling this again, so the per-frame
      // atlas re-encoding happens once per board change rather than once per
      // frame.
      batch.render(
        canvas,
        cullRect: gameRef.camera.visibleWorldRect,
        paint: paint,
      );
    }
  }

  Rect rectOf(int x, int y) {
    return Rect.fromLTWH(
      x * ComponentConstants.spriteSize,
      y * ComponentConstants.spriteSize,
      ComponentConstants.spriteSize,
      ComponentConstants.spriteSize,
    );
  }

  Rect subRectOf(int x, int y, int subX, int subY) {
    const subSize = ComponentConstants.spriteSize * 0.5;
    return Rect.fromLTWH(
      x * ComponentConstants.spriteSize + subX * subSize,
      y * ComponentConstants.spriteSize + subY * subSize,
      subSize,
      subSize,
    );
  }

  Rect verticalHalfRectOf(int x, int y) {
    const size = ComponentConstants.spriteSize;
    const subSize = size * 0.5;
    return Rect.fromLTWH(x * size, y * size + 0.25 * size, size, subSize);
  }

  Rect horizontalHalfRectOf(int x, int y) {
    const size = ComponentConstants.spriteSize;
    const subSize = size * 0.5;
    return Rect.fromLTWH(x * size + 0.25 * size, y * size, subSize, size);
  }

  void _refreshFilterQuality() {
    final quality = _filterQualityFor(gameRef.camera.viewfinder.zoom);
    if (paint.filterQuality == quality) {
      return;
    }
    paint.filterQuality = quality;
    // The filter is part of the recorded picture, so a zoom that crosses a
    // quality step has to drop the cache or the layer keeps drawing at the
    // previous quality.
    invalidateSnapshot();
  }

  static FilterQuality _filterQualityFor(double zoom) {
    if (zoom >= 2.0) {
      return FilterQuality.high;
    }
    if (zoom >= 1.0) {
      return FilterQuality.medium;
    }
    if (zoom <= 0.2) {
      return FilterQuality.none;
    }
    return FilterQuality.low;
  }
}
