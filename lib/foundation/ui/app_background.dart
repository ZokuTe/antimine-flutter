import 'dart:io';

import 'package:flutter/material.dart';

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

    final brightness = Theme.of(context).colorScheme.brightness;
    // Light themes need a light scrim (and vice versa) for the on-surface text
    // to stay readable.
    final scrim =
        brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.72);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          fit: BoxFit.cover,
          // Decode at roughly screen resolution. A full-resolution photo can be
          // tens of megabytes in memory, which risks killing the app.
          cacheWidth: _decodeWidth(context),
          gaplessPlayback: true,
          errorBuilder:
              (_, _, _) => ColoredBox(color: fallbackColor),
        ),
        ColoredBox(color: scrim),
        child,
      ],
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
