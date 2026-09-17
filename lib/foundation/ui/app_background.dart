import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'frosted_theme.dart';

/// Paints the game background: the theme colour, or a user-selected image with
/// a scrim over it.
///
/// The scrim is what keeps the UI legible. A photo behind text is unreadable
/// without one, so the scrim is derived from the active theme rather than being
/// configurable.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    required this.image,
    required this.fallbackColor,
  });

  final Widget child;

  /// The stored background image, or null to use [fallbackColor].
  final File? image;

  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final file = image;
    if (file == null) {
      return ColoredBox(color: fallbackColor, child: child);
    }

    final theme = FrostedTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // The scrim is what keeps text legible over an arbitrary photo, so it reuses
    // the panel opacity control: 0% leaves the image untouched, 100% hides it.
    final scrim = colorScheme.surface.withValues(alpha: theme.opacity);

    Widget background = Image.file(
      file,
      fit: BoxFit.cover,
      // Decode at roughly screen resolution. A full-resolution photo can be
      // tens of megabytes in memory, which risks killing the app.
      cacheWidth: _decodeWidth(context),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(color: fallbackColor),
    );

    // Blur the image itself, not the backdrop: a backdrop filter cannot sample
    // this far down the tree, and blurring here also softens the photo so the
    // UI on top stays readable.
    if (theme.blur > 0 && !MediaQuery.disableAnimationsOf(context)) {
      background = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: theme.blur, sigmaY: theme.blur),
        child: background,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [background, ColoredBox(color: scrim), child],
    );
  }

  /// Target decode width in physical pixels.
  static int _decodeWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width * media.devicePixelRatio;
    // Cap it: past a point the extra pixels are invisible given the scrim.
    return width.clamp(360, 1440).round();
  }
}
