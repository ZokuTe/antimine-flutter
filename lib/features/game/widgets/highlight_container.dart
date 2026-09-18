import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../foundation/ui/spacing.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_state.dart';

/// The chip above the board holding the clock and the mine counter.
///
/// Uses a translucent fill rather than a backdrop blur: the chip rebuilds on
/// every clock tick, and re-running a backdrop filter that often costs more
/// than the effect is worth here.
class HighlightContainer extends StatelessWidget {
  const HighlightContainer({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (previous, current) {
        return previous.minefield != current.minefield;
      },
      builder: (context, state) {
        if (state.minefield.isEmpty) {
          return const SizedBox();
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: _fillOpacity),
            borderRadius: BorderRadius.circular(Spacing.x8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.x16,
              vertical: Spacing.x8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
          ),
        );
      },
    );
  }

  static const double _fillOpacity = 0.12;
}
