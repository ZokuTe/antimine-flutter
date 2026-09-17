import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../foundation/ui/frosted_glass.dart';
import '../../../../foundation/ui/spacing.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_state.dart';

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
        } else {
          // No tint: the background already carries the scrim, and stacking a
          // second one here would make the chip darker than the surface it
          // sits on. Only the blur is applied, so the chip reads as part of
          // the background.
          return FrostedGlass(
            opacity: 0,
            borderRadius: BorderRadius.circular(Spacing.x8),
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
        }
      },
    );
  }
}
