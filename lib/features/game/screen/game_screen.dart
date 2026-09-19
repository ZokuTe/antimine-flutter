import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../common/alert/game_alert.dart';
import '../../../common/models/game_settings.dart';
import '../../../common/models/skins/skin.dart';
import '../../../common/models/themes/game_theme.dart';
import '../../../foundation/i18n/translations.g.dart';
import '../../../foundation/side_effect/side_effect_bloc.dart';
import '../../../foundation/side_effect/side_effect_event.dart';
import '../../dialogs/game_over_dialog.dart';
import '../../dialogs/victory_dialog.dart';
import '../../live/bloc/live_bloc.dart';
import '../../live/bloc/live_state.dart';
import '../../live/live_support.dart';
import '../../live/widgets/live_cursor_overlay.dart';
import '../../share/share_game_modal.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_side_effect.dart';
import '../bloc/game_state.dart';
import '../logic/dimension_manager.dart';
import '../flame/game_renderer.dart';
import '../widgets/action_switcher.dart';
import '../widgets/game_loading_indicator.dart';
import '../widgets/game_preview_button_bar.dart';
import '../widgets/game_timer.dart';
import '../widgets/highlight_container.dart';
import '../widgets/initial_label.dart';
import '../widgets/mine_counter.dart';
import '../widgets/trailing_action.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.skin,
    required this.theme,
    required this.dimensionManager,
    required this.settings,
  });

  final Skin skin;
  final GameTheme theme;
  final DimensionManager dimensionManager;
  final GameSettings settings;

  @override
  State<StatefulWidget> createState() {
    return _GameScreenState();
  }
}

class _GameScreenState extends State<GameScreen> {
  late final GameBloc _gameBloc;
  late final LiveBloc _liveBloc;
  late GameRenderer _gameRenderer;
  StreamSubscription<GameState>? _gameStates;

  @override
  void initState() {
    super.initState();
    // 提前抓好引用：dispose 里再 context.read 已经太晚，那时 element 已离开树，
    // 向上查祖先会失败。
    _gameBloc = context.read<GameBloc>();
    _liveBloc = context.read<LiveBloc>();

    _gameRenderer = GameRenderer(
      skin: widget.skin,
      theme: widget.theme,
      areaSize: widget.dimensionManager.calcAreaSize(),
      gameBloc: _gameBloc,
      sideEffectBloc: context.read<SideEffectBloc>(),
      settings: widget.settings,
    );

    // 把盘面交给直播那边：动作出口 + 当前尺寸。
    // 连接本身是 App 级的，换局不会断。
    _liveBloc.attach(
      applyAction: _gameBloc.applyLiveAction,
      width: _gameBloc.state.minefield.width,
      height: _gameBloc.state.minefield.height,
    );

    // 换局或换自定义尺寸之后，光标得跟着收进新盘面，否则会停在一个不存在的
    // 格子上，之后所有指令都落在盘外。
    _gameStates = _gameBloc.stream.listen((gameState) {
      _liveBloc.updateBounds(
        width: gameState.minefield.width,
        height: gameState.minefield.height,
      );
    });
  }

  @override
  void dispose() {
    _gameStates?.cancel();
    _liveBloc.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) => previous.params != current.params,
      builder: (context, state) {
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: BackButton(onPressed: () => _backNavigate(context)),
            actions: [
              if (!state.params.isPreview)
                TrailingAction(settings: widget.settings),
            ],
            centerTitle: true,
            title: HighlightContainer(
              children: [
                if (widget.settings.showClock) const GameTimer(),
                const MineCounter(),
              ],
            ),
            elevation: 0,
            // Translucent rather than blurred: this bar sits above the board,
            // which redraws continuously while playing, so a backdrop filter
            // here costs more than it adds.
            flexibleSpace: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.6),
              child: SizedBox(
                height: kToolbarHeight + MediaQuery.paddingOf(context).top,
                width: double.infinity,
              ),
            ),
          ),
          extendBody: true,
          bottomNavigationBar:
              [
                if (state.params.isPreview && state.params.saveId == null)
                  const GamePreviewBottomBar(),
              ].firstOrNull,
          body: BlocListener<SideEffectBloc, SideEffectEvent?>(
            listener: (context, state) => _handleSideEffect(context, state),
            child: Builder(
              builder: (context) {
                _gameRenderer.updateGame(
                  state.params,
                  isPortrait,
                  widget.dimensionManager.appBarHeight(context),
                );

                return Stack(
                  children: [
                    GameWidget(game: _gameRenderer),
                    // 直播覆盖层：共享光标 + 出屏箭头。整层 IgnorePointer，
                    // 主播自己的点击原样穿透到下面的 GameWidget。
                    if (isLiveSupported)
                      BlocBuilder<LiveBloc, LiveState>(
                        builder: (context, liveState) {
                          final cursor = liveState.cursor;
                          if (cursor == null ||
                              !liveState.isConnected ||
                              state.params.isPreview) {
                            return const SizedBox.shrink();
                          }
                          return LiveCursorOverlay(
                            renderer: _gameRenderer,
                            cursor: cursor,
                            // 贴在真正边缘的箭头会被 AppBar 盖掉
                            inset: EdgeInsets.only(
                              top:
                                  kToolbarHeight +
                                  MediaQuery.paddingOf(context).top,
                            ),
                          );
                        },
                      ),
                    const GameLoadingIndicator(),
                    if (!state.params.isPreview) const InitialLabel(),
                    if (!state.params.isPreview ||
                        (state.params.isPreview && state.params.saveId != null))
                      ActionSwitcher(
                        isPortrait: isPortrait,
                        controlTypeId: widget.settings.controlType,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _backNavigate(BuildContext context) {
    final params = context.read<GameBloc>().state.params;
    if (!params.isPreview) {
      context.read<GameBloc>()
        ..stopMusic()
        ..saveGame();
    }
    context.pop();
  }

  void _handleSideEffect(BuildContext context, SideEffectEvent? event) {
    final gameBloc = context.read<GameBloc>();

    if (event is VictoryEffect) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => VictoryDialog(
              outContext: context,
              bloc: gameBloc,
              settings: widget.settings,
            ),
      );
    } else if (event is GameOverEffect) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => GameOverDialog(
              outContext: context,
              bloc: gameBloc,
              settings: widget.settings,
            ),
      );
    } else if (event is NoMoreHintsEffect) {
      showGameAlert(
        context: context,
        title: t.help,
        content: t.cant_do_it_now,
        primaryAction: t.ok,
      );
    } else if (event is ShareFailedEffect) {
      showGameAlert(
        context: context,
        title: t.error,
        content: t.fail_to_share,
        primaryAction: t.ok,
      );
    } else if (event is ShareGameRequestEffect) {
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return ShareGameModal(
            onImage: () {
              gameBloc.shareGameImage();
            },
            onCode: () {
              gameBloc.shareCode();
            },
          );
        },
      );
    }
  }
}
