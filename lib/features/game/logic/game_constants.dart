import 'package:flutter/foundation.dart';

class GameConstants {
  GameConstants._();

  static const useNativeCreator = true;
  static const minSafeArea = 9;
  static const maxMinefieldWidth = 100;
  static const maxMinefieldHeight = 100;

  /// The clock advances in whole seconds because that is all the display
  /// shows, and every tick costs a state rebuild that fans out to each
  /// `FlameBlocListenable` on the board. Ticking faster than the display
  /// cannot change what is shown.
  static const tickDuration = Duration(seconds: 1);
  static const hintCooldown =
      kDebugMode
          ? Duration(seconds: 0, milliseconds: 500)
          : Duration(seconds: 2, milliseconds: 500);
  static const throwConfettiMin = Duration(seconds: 3);
  static const confettiDuration = Duration(seconds: 3);
  static const hintReward = 5;
  static const initialHintCount = 5;
  static final revealedOpacity = (0.6 * 255.0).toInt();
  static const dimOpacity = 127;

  static const safeAreaEnabled = true;
  static const lockSmallGamesOnScreen = false;
}
