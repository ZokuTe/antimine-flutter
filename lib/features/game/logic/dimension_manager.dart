import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';

class DimensionManager {
  DimensionManager({bool? isMobile}) : isMobile = isMobile ?? _isMobile();

  late Size screenSize;
  final bool isMobile;

  /// Smallest minefield the game can create. Guards against a collapsed or
  /// not-yet-measured window producing a non-positive dimension, which would
  /// otherwise crash when the area list is generated.
  static const int minMinefieldDimension = 5;

  void init({required Size screenSize}) {
    this.screenSize = screenSize;
  }

  double appBarHeight(BuildContext context) {
    return Scaffold.of(context).appBarMaxHeight ?? 0;
  }

  /// The conventional tablet breakpoint, applied to the window this manager
  /// was initialised with. Deriving it from [screenSize] rather than reading a
  /// process-wide view keeps the decision tied to the window being laid out.
  bool get isTablet => screenSize.shortestSide > 600;

  double calcAreaSize() {
    final areaColumns = isTablet ? 20 : 12;
    final size = screenSize;
    final width = size.width;
    final height = size.height;
    return max(min(width, height) / areaColumns, 35);
  }

  Size standardMinefieldSize() {
    final areaSize = calcAreaSize();
    // screenSize can still be the pre-layout window size (0x0 or 1x1) when the
    // minefield is first built, which would yield negative dimensions. Clamp
    // into a usable range instead of producing an invalid minefield.
    final width = max(screenSize.width ~/ areaSize - 1, minMinefieldDimension);
    final height = max(
      screenSize.height ~/ areaSize - 7,
      minMinefieldDimension,
    );
    return Size(width.toDouble(), height.toDouble());
  }

  static bool _isMobile() {
    return Platform.isAndroid || Platform.isIOS || Platform.isFuchsia;
  }
}
