import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../foundation/ui/spacing.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_state.dart';

class MineCounter extends StatelessWidget {
  const MineCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mineIcon = Image.asset(
      './assets/icons/mine.png',
      width: Spacing.x20,
      height: Spacing.x20,
      fit: BoxFit.contain,
      color: colorScheme.onSurface,
    );
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) {
        return previous.areas != current.areas ||
            previous.loading != current.loading;
      },
      builder: (context, state) {
        if (state.loading && state.minefield.isEmpty) {
          return const SizedBox();
        }
        // Walked once: the getter scans every area, and a negative count
        // changes both the text and the colour.
        final remaining = state.remainingMines;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            mineIcon,
            const SizedBox(width: Spacing.x4),
            Text(
              state.isGameOver
                  ? state.minefield.mines.toString()
                  : remaining.toString(),
              maxLines: 1,
              style: TextStyle(
                fontSize: Spacing.smallText,
                fontWeight: FontWeight.bold,
                color: remaining < 0 ? colorScheme.error : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
