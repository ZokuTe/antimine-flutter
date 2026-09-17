import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../foundation/i18n/translations.g.dart';
import '../../game/game_route.dart';
import '../../home/home_route.dart';
import '../bloc/startup_bloc.dart';
import '../bloc/startup_state.dart';

class StartUpScreen extends StatefulWidget {
  const StartUpScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _StartUpScreen();
  }
}

class _StartUpScreen extends State<StartUpScreen> {
  bool _initializationStarted = false;

  @override
  Widget build(BuildContext context) {
    // The first post-frame callback can observe a pre-layout window size (0x0
    // on Android, 1x1 on desktop), which produced an invalid minefield. Build
    // instead, where MediaQuery has been resolved, and only start once a real
    // size is available.
    final screenSize = MediaQuery.of(context).size;
    if (!_initializationStarted &&
        screenSize.width > 0 &&
        screenSize.height > 0) {
      _initializationStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StartUpBloc>().initializeGame(screenSize: screenSize);
        }
      });
    }

    return BlocListener<StartUpBloc, StartupState>(
      listener: (context, state) {
        if (state.initialized) {
          if (state.openGameDirectly) {
            GameRoute.open(context);
          } else {
            HomeRoute.open(context);
          }
        }
      },
      child: Scaffold(
        body: Semantics(label: t.loading, child: const SizedBox.expand()),
      ),
    );
  }
}
