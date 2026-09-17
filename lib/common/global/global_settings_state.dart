import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GlobalSettingsState extends Equatable {
  const GlobalSettingsState({
    required this.colorScheme,
    this.locale,
    this.backgroundImage,
    this.panelBlur = 12.0,
    this.panelOpacity = 0.55,
  });

  final ColorScheme colorScheme;
  final String? locale;

  /// File name of the custom background image, or null for the theme colour.
  final String? backgroundImage;

  /// Blur applied to frosted surfaces.
  final double panelBlur;

  /// Tint opacity of frosted surfaces.
  final double panelOpacity;

  GlobalSettingsState copyWith({
    ColorScheme? colorScheme,
    String? locale,
    String? backgroundImage,
    bool clearBackgroundImage = false,
    double? panelBlur,
    double? panelOpacity,
  }) {
    return GlobalSettingsState(
      colorScheme: colorScheme ?? this.colorScheme,
      locale: locale ?? this.locale,
      backgroundImage:
          clearBackgroundImage
              ? null
              : (backgroundImage ?? this.backgroundImage),
      panelBlur: panelBlur ?? this.panelBlur,
      panelOpacity: panelOpacity ?? this.panelOpacity,
    );
  }

  @override
  List<Object?> get props => [
    colorScheme,
    locale,
    backgroundImage,
    panelBlur,
    panelOpacity,
  ];
}
