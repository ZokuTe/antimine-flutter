import 'package:flutter/material.dart';

/// Tunable values for frosted surfaces.
///
/// Delivered through the theme so every surface picks up the same values,
/// including dialogs that are pushed onto a different route.
@immutable
class FrostedTheme extends ThemeExtension<FrostedTheme> {
  const FrostedTheme({required this.blur, required this.opacity});

  /// Gaussian blur standard deviation. Zero disables the blur entirely, which
  /// also skips the [BackdropFilter] so there is no compositing cost.
  final double blur;

  /// Opacity of the tint painted over the blurred backdrop. Lower values let
  /// more of the content behind show through.
  final double opacity;

  static const double minBlur = 0.0;
  static const double maxBlur = 40.0;
  static const double minOpacity = 0.0;
  static const double maxOpacity = 1.0;

  static const FrostedTheme fallback = FrostedTheme(blur: 12.0, opacity: 0.55);

  /// Reads the current values, or [fallback] when the theme has none.
  static FrostedTheme of(BuildContext context) {
    return Theme.of(context).extension<FrostedTheme>() ?? fallback;
  }

  @override
  FrostedTheme copyWith({double? blur, double? opacity}) {
    return FrostedTheme(
      blur: blur ?? this.blur,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  FrostedTheme lerp(ThemeExtension<FrostedTheme>? other, double t) {
    if (other is! FrostedTheme) {
      return this;
    }
    return FrostedTheme(
      blur: blur + (other.blur - blur) * t,
      opacity: opacity + (other.opacity - opacity) * t,
    );
  }
}
