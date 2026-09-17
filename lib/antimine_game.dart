import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'common/global/global_settings_bloc.dart';
import 'common/global/global_settings_state.dart';
import 'foundation/i18n/translations.g.dart';
import 'foundation/io/background_image_manager.dart';
import 'foundation/ui/app_background.dart';
import 'foundation/ui/frosted_theme.dart';
import 'game_routing.dart';

class AntimineGame extends StatefulWidget {
  const AntimineGame({super.key});

  @override
  State<StatefulWidget> createState() {
    return AntimineGameState();
  }
}

class AntimineGameState extends State<AntimineGame> {
  late RouterConfig<Object> _routerConfig;

  /// Resolved lazily per background name. Holding the File avoids hitting the
  /// filesystem on every rebuild.
  String? _resolvedName;
  File? _resolvedFile;

  @override
  void initState() {
    super.initState();
    _routerConfig = GameRouting.routeConfig;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GlobalSettingsBloc, GlobalSettingsState>(
      builder: (context, state) {
        final locale = state.locale;
        final parts = locale?.split(RegExp('[_-]'));
        final languageCode = parts?.firstOrNull;
        final countryCode = parts != null && parts.length > 1 ? parts[1] : null;
        if (locale != null) {
          LocaleSettings.setLocaleRaw(locale);
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                state.colorScheme.brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
            statusBarColor: state.colorScheme.surface,
            systemNavigationBarColor: state.colorScheme.surface,
            // statusBarIconBrightness: state.colorScheme.brightness,
            // systemNavigationBarIconBrightness: state.colorScheme.brightness,
          ),
          child: MaterialApp.router(
            title: t.app_name,
            debugShowCheckedModeBanner: false,
            locale: languageCode != null
                ? Locale(languageCode, countryCode)
                : null,
            theme: ThemeData(
              colorScheme: state.colorScheme,
              useMaterial3: true,
              // Screens paint no background of their own so the custom
              // background below shows through.
              scaffoldBackgroundColor: Colors.transparent,
              // App bars are transparent by default so the background image
              // shows through everywhere, not just on the game screen.
              // Individual screens that need a blurred bar add it themselves.
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              extensions: [
                FrostedTheme(
                  blur: state.panelBlur,
                  opacity: state.panelOpacity,
                ),
              ],
            ),
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _routerConfig,
            builder: (context, child) {
              _resolveBackground(state.backgroundImage);
              return AppBackground(
                image: _resolvedFile,
                fallbackColor: state.colorScheme.surface,
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }

  /// Resolves the stored background name to a file, at most once per name.
  void _resolveBackground(String? name) {
    if (name == _resolvedName) {
      return;
    }
    _resolvedName = name;
    _resolvedFile = null;
    if (name == null) {
      return;
    }
    unawaited(
      BackgroundImageManager()
          .resolve(name)
          .then((file) {
            if (mounted && _resolvedName == name) {
              setState(() => _resolvedFile = file);
            }
          })
          .catchError((Object _) => null),
    );
  }
}

