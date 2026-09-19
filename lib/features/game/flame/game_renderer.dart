import 'dart:async';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../common/models/game_settings.dart';
import '../../../common/models/input/game_input.dart';
import '../../../common/models/input/input_type.dart';
import '../../../common/models/skins/skin.dart';
import '../../../common/models/themes/game_theme.dart';
import '../../../foundation/side_effect/side_effect_bloc.dart';
import '../../../foundation/side_effect/side_effect_event.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_state.dart';

import '../screen/game_params.dart';
import 'components/camera_center_component.dart';
import 'components/cover_layer_component.dart';
import 'components/ground_layer_component.dart';
import 'components/hover_component.dart';
import 'components/icons_layer_component.dart';
import 'components/share_component.dart';

class GameRenderer extends FlameGame
    with ScaleDetector, ScrollDetector, TapCallbacks, DoubleTapDetector {
  GameRenderer({
    required this.gameBloc,
    required this.sideEffectBloc,
    required this.skin,
    required this.theme,
    required this.areaSize,
    required this.settings,
  }) {
    // `Game.initializeGestures` registers the double-tap recognizer because
    // this class declares the mixin, so the map starts out containing it.
    // Touching `gestureDetectors` builds that map; `_syncDoubleTapRegistration`
    // then drops the entry if the scheme has no use for the gesture.
    _doubleTapRegistered = true;
    _syncDoubleTapRegistration();
  }

  final GameBloc gameBloc;
  final SideEffectBloc sideEffectBloc;
  final Skin skin;
  final GameTheme theme;
  final double areaSize;
  final GameSettings settings;

  late CameraCenterComponent cameraCenter;
  late HoverComponent hoverComponent;
  late CoverLayerComponent coverComponent;
  late GroundLayerComponent groundComponent;
  late IconsLayerComponent iconsComponent;
  late ShareComponent shareComponent;
  late FlameMultiBlocProvider blocComponent;

  /// Whether the double-tap recognizer is currently registered.
  bool _doubleTapRegistered = true;

  /// Registers or drops the double-tap recognizer to match the active scheme.
  ///
  /// `DoubleTapGestureRecognizer` keeps the gesture arena open for
  /// [kDoubleTapTimeout] so it can tell a double tap from two single ones, and
  /// that makes every single tap take ~300 ms to arrive. The recognizer is
  /// therefore only kept when the scheme actually needs it.
  ///
  /// "Needs it" is not the same as "binds `doubleTap`": in two of the schemes
  /// `doubleTap` resolves to the same action as `singleTap`, so the gesture is
  /// reachable by tapping once and the wait buys nothing. The check compares
  /// the bound actions instead of looking for the key.
  ///
  /// The scheme can be changed while a game is running, so this is re-checked
  /// on every state update rather than only at construction.
  void _syncDoubleTapRegistration() {
    final needed = _schemeNeedsDoubleTap();

    if (needed == _doubleTapRegistered) {
      return;
    }

    if (needed) {
      // Mirrors what `Game.initializeGestures` wires up for
      // `DoubleTapDetector`, so a scheme switch re-enables the recognizer with
      // exactly the callbacks it would have had at construction.
      gestureDetectors.add(DoubleTapGestureRecognizer.new, (
        DoubleTapGestureRecognizer instance,
      ) {
        instance.onDoubleTap = onDoubleTap;
        instance.onDoubleTapDown = handleDoubleTapDown;
        instance.onDoubleTapCancel = onDoubleTapCancel;
      });
    } else {
      gestureDetectors.remove<DoubleTapGestureRecognizer>();
    }
    _doubleTapRegistered = needed;
  }

  /// True when double-tapping reaches an action no other bound gesture does.
  bool _schemeNeedsDoubleTap() {
    final map = GameInput.fromId(settings.controlType).inputMap;
    final doubleTap = map[InputType.doubleTap];

    if (doubleTap == null) {
      return false;
    }
    return doubleTap != map[InputType.singleTap] &&
        doubleTap != map[InputType.longTap];
  }

  late bool isPortrait;
  late GameParams params;
  late double appBarHeight;

  double _startZoom = 1.0;
  bool _engineReady = false;
  bool _consumeInput = false;
  Vector2? _lastInputPosition;
  double? _lastInteractionTime;

  /// The size of the screen.
  Vector2 get screenSize => camera.viewport.size;

  @override
  Color backgroundColor() {
    // With a custom background image the canvas must not paint over it. The
    // board is drawn on top of the app background, which keeps the image
    // visible behind the minefield.
    if (settings.backgroundImage != null) {
      return const Color(0x00000000);
    }
    return theme.background;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    gameBloc.onScreenResize(size);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Pause the loop once nothing has happened for a while. Without this the
    // engine renders continuously even when the board is static, which keeps
    // the CPU busy and heats the device.
    final lastInteractionTime = _lastInteractionTime;
    if (lastInteractionTime == null) {
      return;
    }
    final diff = currentTime() - lastInteractionTime;
    if (diff > _idleThreshold) {
      _lastInteractionTime = null;
      pauseEngine();
      debugPrint('> Idle for $diff seconds, pausing engine');
    }
  }

  /// Marks the game as active and restarts the loop if it had stopped.
  ///
  /// Called from every input handler; without it a paused loop would never
  /// process the next touch.
  void pauseEngineWhenIdle() {
    _lastInteractionTime = currentTime();
    if (paused) {
      resumeEngine();
      debugPrint('> Resuming engine');
    }
  }

  void updateGame(GameParams params, bool isPortrait, double appBarHeight) {
    this.isPortrait = isPortrait;
    this.params = params;
    this.appBarHeight = appBarHeight;
    // The control scheme can be changed from the settings while a game is
    // open, so the gesture set is re-checked whenever the game is rebuilt.
    _syncDoubleTapRegistration();
  }

  @override
  void onDetach() {
    super.onDetach();
    for (final child in children) {
      child.removeFromParent();
    }

    world.removeAll(world.children);
    world.removeFromParent();

    groundComponent.removeFromParent();
    groundComponent.onRemove();
    coverComponent.removeFromParent();
    coverComponent.onRemove();
    iconsComponent.removeFromParent();
    iconsComponent.onRemove();
    hoverComponent.removeFromParent();
    hoverComponent.onRemove();
    cameraCenter.removeFromParent();
    cameraCenter.onRemove();
    shareComponent.removeFromParent();
    shareComponent.onRemove();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    world.add(
      FlameMultiBlocProvider(
        providers: [
          FlameBlocProvider<GameBloc, GameState>.value(value: gameBloc),
          FlameBlocProvider<SideEffectBloc, SideEffectEvent?>.value(
            value: sideEffectBloc,
          ),
        ],
        children: [
          groundComponent = GroundLayerComponent(
            areaSize: areaSize,
            skin: skin,
            theme: theme,
          ),
          coverComponent = CoverLayerComponent(
            areaSize: areaSize,
            skin: skin,
            theme: theme,
          ),
          iconsComponent = IconsLayerComponent(
            areaSize: areaSize,
            skin: skin,
            theme: theme,
          ),
          hoverComponent = HoverComponent(
            areaSize: areaSize,
            skin: skin,
            theme: theme,
          ),
          cameraCenter = CameraCenterComponent(
            isPortrait: isPortrait,
            appBarHeight: appBarHeight,
            areaSize: areaSize,
          ),
          shareComponent = ShareComponent(),
        ],
      ),
    );

    coverComponent.visible = false;
    groundComponent.visible = false;
    iconsComponent.visible = false;

    coverComponent.onNewState(gameBloc.state);
    groundComponent.onNewState(gameBloc.state);
    iconsComponent.onNewState(gameBloc.state);

    Future.wait([
      groundComponent.mounted,
      coverComponent.mounted,
      hoverComponent.mounted,
      iconsComponent.mounted,
      cameraCenter.mounted,
      shareComponent.mounted,
    ]).then((_) => engineReady());
  }

  void engineReady() {
    cameraCenter.onNewState(gameBloc.state);
    _engineReady = true;
    _startGame();
  }

  void _startGame() {
    final cameraPosition = settings.cameraPosition;
    if (cameraPosition != null && !params.isPreview) {
      cameraCenter.position = cameraPosition;
    } else {
      cameraCenter.position = Vector2.zero();
    }

    if (params.isPreview) {
      gameBloc.loadPreviewGame(params.saveId);
    } else if (params.saveId != null || gameBloc.state.id != null) {
      final id = params.saveId ?? gameBloc.state.id;
      if (params.restart) {
        gameBloc.restartSaveGame(id);
      } else {
        gameBloc.continueSaveGame(id);
      }
    } else if (params.isContinue) {
      gameBloc.continueSaveGame();
    } else {
      gameBloc.newGame(
        difficulty: params.difficulty,
        seed: params.seed,
        initialPosition: params.initialPosition,
      );
    }

    final cameraZoom = settings.cameraZoom;
    if (cameraZoom != null && !params.isPreview) {
      camera.viewfinder.zoom = cameraZoom;
    }

    coverComponent.visible = true;
    groundComponent.visible = true;
    iconsComponent.visible = true;

    // Arm the idle timer. update() only pauses once it has a timestamp, so
    // without this a game that is started and then left alone would keep the
    // loop running forever.
    _lastInteractionTime = currentTime();
  }

  void _changeCameraZoom(double zoom) {
    if (zoom > _maxZoom) {
      zoom = _maxZoom;
    } else if (zoom < _minZoom) {
      zoom = _minZoom;
    }
    camera.viewfinder.zoom = zoom;
  }

  Vector2 _getGlobalPosition(Vector2 localPosition) {
    final zoom = camera.viewfinder.zoom;
    final adjustedScreenSize = screenSize * 0.5 / zoom;
    final adjustedLocalPosition = localPosition / zoom;
    return cameraCenter.position + adjustedLocalPosition - adjustedScreenSize;
  }

  Vector2 _getAreaCoordinates(Vector2 localPosition) {
    final minefield = gameBloc.state.minefield.vecSize;
    final cameraFix = minefield * areaSize * 0.5;
    final globalPosition = _getGlobalPosition(localPosition) + cameraFix;
    return Vector2(
      (globalPosition.x ~/ areaSize).toDouble(),
      (globalPosition.y ~/ areaSize).toDouble(),
    );
  }

  /// [_getAreaCoordinates] 的逆变换：格子 → 窗口坐标。
  ///
  /// 刻意紧挨着正变换放。这一对映射分开写迟早会漂，而漂了的表现是光标指着
  /// 一个格子、指令却落在另一个格子上，很难查。
  ///
  /// 返回格子的**左上角**：正变换里 `~/ areaSize` 的分界点正是这个位置，
  /// 所以 `onTapDown` 里 `hoverComponent.position = target * areaSize` 用的是同一个点。
  /// 要格子中心得自己加半个格。
  Vector2 _getLocalPositionOfArea(Vector2 area) {
    final minefield = gameBloc.state.minefield.vecSize;
    final cameraFix = minefield * areaSize * 0.5;
    final zoom = camera.viewfinder.zoom;
    return (area * areaSize - cameraFix - cameraCenter.position) * zoom +
        screenSize * 0.5;
  }

  /// 格子中心在窗口坐标系里的位置，直播覆盖层用它放高亮和出屏箭头。
  ///
  /// 坐标空间与 `onTapDown` 的 `event.localPosition` 一致，所以覆盖层可以
  /// 直接拿它当 `Positioned` 的偏移用。
  Offset screenCenterOfArea(int x, int y) {
    final zoom = camera.viewfinder.zoom;
    final topLeft = _getLocalPositionOfArea(
      Vector2(x.toDouble(), y.toDouble()),
    );
    return Offset(
      topLeft.x + areaSize * 0.5 * zoom,
      topLeft.y + areaSize * 0.5 * zoom,
    );
  }

  /// 一个格子在当前缩放下占多少像素。
  double get areaScreenSize => areaSize * camera.viewfinder.zoom;

  /// 覆盖层能不能安全地做坐标换算。
  ///
  /// `cameraCenter` 是 late 字段，`onLoad` 跑完之前访问会抛
  /// LateInitializationError，所以外面的覆盖层必须先问这个，不能直接算。
  bool get canProjectAreas => _engineReady;

  @override
  void onScaleStart(info) {
    pauseEngineWhenIdle();
    _startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    pauseEngineWhenIdle();

    // Consume any event if the camera is moving.
    _consumeInput = true;

    // ScaleDetector handles both scale and pan gestures.
    final minefield = gameBloc.state.minefield;
    final currentScale = info.scale.global;
    if (!currentScale.isIdentity()) {
      // Scale gesture
      _changeCameraZoom(_startZoom * currentScale.y);
    } else {
      // Pan gesture
      cameraCenter.changeCameraPosition(
        minefield,
        info.delta.global.x,
        info.delta.global.y,
      );
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    gameBloc.saveCameraState(position: cameraCenter.position, zoom: _startZoom);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    pauseEngineWhenIdle();
    bool isZoomIn = info.scrollDelta.global.y.isNegative;
    if (isZoomIn) {
      _changeCameraZoom(camera.viewfinder.zoom * _zoomThresholdOnScroll);
    } else {
      _changeCameraZoom(camera.viewfinder.zoom / _zoomThresholdOnScroll);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Route through the idle helper so the loop restarts *and* the idle timer
    // is armed; a bare resume would leave it null and it would never pause
    // again.
    pauseEngineWhenIdle();
    final target = _getAreaCoordinates(event.localPosition);

    final minefield = gameBloc.state.minefield;
    if (minefield.contains(target.x, target.y)) {
      _consumeInput = false;
      _lastInputPosition = event.localPosition;

      hoverComponent
        ..enabled = _engineReady
        ..position = target * areaSize;
    } else {
      hoverComponent.enabled = false;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    // A tap that completes without onTapCancel is a real tap, not a pan: the
    // gesture recognizer only cancels once the pointer moves beyond its slop.
    _consumeTapUp(event.localPosition);
  }

  void _consumeTapUp(Vector2 localPosition) {
    pauseEngineWhenIdle();
    hoverComponent.enabled = false;
    final lastInputPosition = _lastInputPosition;
    if (lastInputPosition != null && !_consumeInput) {
      _consumeInput = true;
      final target = _getAreaCoordinates(localPosition);
      gameBloc.tapArea(target, theme.connectAreas);
      _lastInputPosition = null;
    }
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    hoverComponent.enabled = false;
    _consumeInput = true;
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    pauseEngineWhenIdle();
    final target = _getAreaCoordinates(event.localPosition);
    _consumeInput = true;
    gameBloc.longTapArea(target);
    hoverComponent.enabled = false;
  }

  @override
  void onDoubleTapDown(TapDownInfo info) {
    pauseEngineWhenIdle();
    hoverComponent.enabled = _engineReady;
    _lastInputPosition = info.eventPosition.global;
  }

  @override
  void onDoubleTap() {
    pauseEngineWhenIdle();
    final lastInputPosition = _lastInputPosition;
    if (lastInputPosition != null) {
      _consumeInput = true;
      hoverComponent.enabled = false;
      final target = _getAreaCoordinates(lastInputPosition);
      gameBloc.doubleTapArea(target);
      _lastInputPosition = null;
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);

    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        gameBloc.onResumeEngine();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        gameBloc.onPauseEngine();
        break;
    }
  }

  void shareGame({required String hash, required String minefieldSize}) async {
    resumeEngine();

    final minefield = gameBloc.state.minefield;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = theme.background;
    final padding = areaSize;

    String title;
    if (minefield.width >= 20) {
      title = 'Antimine Minesweeper - $minefieldSize\n$hash';
    } else {
      title = 'Antimine - $minefieldSize\n$hash';
    }

    final width = (areaSize * minefield.width + padding * 2).toInt();
    final height = (areaSize * minefield.height + padding * 3.5).toInt();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    canvas.translate(width * 0.5, height * 0.5 + padding * 0.5);

    groundComponent.render(canvas);
    coverComponent.render(canvas);
    iconsComponent.render(canvas);

    TextSpan span = TextSpan(
      style: TextStyle(
        color: theme.cover,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      text: title,
    );
    TextPainter textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-width * 0.5 + padding, -height * 0.5 + padding * 0.33),
    );

    debugPrint('> Generating share picture to $hash...');

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final pngByteData = await image.toByteData(format: ImageByteFormat.png);
    if (pngByteData != null) {
      await gameBloc.sharePicture(pngByteData);
    }
  }

  /// The zoom factor to apply when scrolling.
  static const double _zoomThresholdOnScroll = 1.1;
  static const double _maxZoom = 5.0;
  static const double _minZoom = 0.3;
  static const double _idleThreshold = 2.0;
}
