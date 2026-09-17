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
          // Blur only while a background image is set, and never add a tint:
          // the background already carries the scrim, so stacking a second one
          // would make the chip darker than the surface around it.
          final child = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.x16,
              vertical: Spacing.x8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
          );
          if (state.settings.backgroundImage == null) {
            return child;
          }
          return FrostedGlass(
            opacity: 0,
            borderRadius: BorderRadius.circular(Spacing.x8),
            child: child,
          );
        }
      },
    );
  }
}
