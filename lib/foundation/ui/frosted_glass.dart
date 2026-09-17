import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted-glass surface.
///
/// Blurs whatever is painted behind it and overlays a translucent tint, giving
/// floating UI depth over imagery.
///
/// [BackdropFilter] reads the composited backdrop, so it only affects content
/// drawn in the same layer beneath it. The Flame game canvas is wrapped in its
/// own [RepaintBoundary] (see `GameWidget.addRepaintBoundary`), which a
/// backdrop filter cannot sample — blurring over the minefield is therefore a
/// no-op. Use this widget over Flutter content (dialogs, sheets, images), and
/// use [FrostedSurface] for chrome that floats above the game.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = blurDefault,
    this.tint,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Subtle blur for persistent chrome such as app bars.
  static const double blurSubtle = 12.0;

  /// Stronger blur for modal surfaces such as dialogs.
  static const double blurDefault = 24.0;

  final Widget child;

  /// Standard deviation of the Gaussian blur, in logical pixels.
  final double blur;

  /// Colour painted over the blurred backdrop.
  final Color? tint;

  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final resolvedTint =
        tint ??
        (isDark
            ? colorScheme.surface.withValues(alpha: 0.55)
            : colorScheme.surface.withValues(alpha: 0.7));

    Widget content = DecoratedBox(
      decoration: BoxDecoration(color: resolvedTint),
      child: child,
    );

    // `disableAnimations` reflects the system "remove animations" setting.
    // Treat it as a request for less visual processing and skip the blur.
    if (blur > 0 && !MediaQuery.disableAnimationsOf(context)) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      );
    }

    final radius = borderRadius;
    if (radius == null) {
      return content;
    }
    return ClipRRect(
      borderRadius: radius,
      clipBehavior: clipBehavior,
      child: content,
    );
  }
}

/// A translucent "frosted" panel for chrome floating above the game canvas.
///
/// Unlike [FrostedGlass] this does not use a backdrop filter, so it stays cheap
/// and works above the Flame canvas. The frosted look is suggested by a soft
/// translucent fill plus a hairline highlight, which reads as glass over the
/// board without sampling it.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.opacity = 0.82,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// How opaque the panel is. Higher keeps the game more legible underneath.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(16);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: opacity),
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
