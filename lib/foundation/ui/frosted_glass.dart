import 'dart:ui';

import 'package:flutter/material.dart';

import 'frosted_theme.dart';

/// A frosted-glass surface: blurs what is painted behind it and overlays a
/// translucent tint.
///
/// Blur and tint opacity come from [FrostedTheme]; pass [blur] or [opacity] to
/// override them for one surface.
///
/// The backdrop is always clipped to this widget's bounds. `BackdropFilter`
/// filters the whole layer it belongs to, so without a clip it would blur the
/// entire screen instead of just this panel.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.blur,
    this.opacity,
    this.tint,
    this.borderRadius,
  });

  final Widget child;

  /// Overrides the theme blur.
  final double? blur;

  /// Overrides the theme tint opacity.
  final double? opacity;

  /// Overrides the derived tint colour.
  final Color? tint;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = FrostedTheme.of(context);
    final resolvedBlur = (blur ?? theme.blur).clamp(
      FrostedTheme.minBlur,
      FrostedTheme.maxBlur,
    );
    final resolvedOpacity = (opacity ?? theme.opacity).clamp(
      FrostedTheme.minOpacity,
      FrostedTheme.maxOpacity,
    );

    final colorScheme = Theme.of(context).colorScheme;
    final resolvedTint =
        tint ?? colorScheme.surface.withValues(alpha: resolvedOpacity);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(color: resolvedTint),
      child: child,
    );

    // `disableAnimations` reflects the system "remove animations" setting.
    // Treat it as a request for less visual processing and skip the blur.
    final canBlur =
        resolvedBlur > 0 && !MediaQuery.disableAnimationsOf(context);
    if (canBlur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: resolvedBlur, sigmaY: resolvedBlur),
        child: content,
      );
    }

    // Always clip: the blur must not escape this widget's bounds.
    final radius = borderRadius;
    return radius == null
        ? ClipRect(child: content)
        : ClipRRect(borderRadius: radius, child: content);
  }
}
