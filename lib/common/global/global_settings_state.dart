import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GlobalSettingsState extends Equatable {
  const GlobalSettingsState({
    required this.colorScheme,
    this.locale,
    this.backgroundImage,
  });

  final ColorScheme colorScheme;
  final String? locale;

  /// File name of the custom background image, or null for the theme colour.
  final String? backgroundImage;

  GlobalSettingsState copyWith({
    ColorScheme? colorScheme,
    String? locale,
    String? backgroundImage,
    bool clearBackgroundImage = false,
  }) {
    return GlobalSettingsState(
      colorScheme: colorScheme ?? this.colorScheme,
      locale: locale ?? this.locale,
      backgroundImage:
          clearBackgroundImage
              ? null
              : (backgroundImage ?? this.backgroundImage),
    );
  }

  @override
  List<Object?> get props => [colorScheme, locale, backgroundImage];
}
