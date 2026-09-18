import 'package:flutter/widgets.dart';

extension BuildContextExt on BuildContext {
  /// True when the shortest side of this context's viewport is wider than 600
  /// logical pixels, the conventional tablet breakpoint.
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide > 600;
}
