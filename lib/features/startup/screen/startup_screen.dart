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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs after the first build with inherited widgets resolved, so
    // MediaQuery has a real size (the first post-frame callback can observe a
    // pre-layout 0x0 on Android or 1x1 on desktop, which produced an invalid
    // minefield). It also re-runs on a metrics change, so a resize before the
    // game starts is picked up rather than ignored.
    if (_initializationStarted) {
      return;
    }

    final screenSize = MediaQuery.sizeOf(context);
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return;
    }

    _initializationStarted = true;
    context.read<StartUpBloc>().initializeGame(screenSize: screenSize);
  }

  @override
  Widget build(BuildContext context) {
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
