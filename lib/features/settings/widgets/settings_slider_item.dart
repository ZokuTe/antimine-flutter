import 'package:flutter/material.dart';

import '../../../foundation/ui/spacing.dart';

/// A settings row with a slider.
///
/// Used for continuous values such as the frosted blur and tint opacity, where
/// a switch would not express the range.
///
/// [onChanged] only fires when the drag ends. Applying the value continuously
/// would rebuild the whole background, and the blur it feeds is a full-screen
/// gaussian filter that has to be re-rasterised on every change — dragging
/// would then stutter. The value shown while dragging comes from local state.
class SettingsSliderItem extends StatefulWidget {
  const SettingsSliderItem({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;

  /// Called once the drag ends, with the final value.
  final ValueChanged<double> onChanged;

  /// Formatter for the current value shown on the right.
  final String Function(double value)? label;

  @override
  State<SettingsSliderItem> createState() => _SettingsSliderItemState();
}

class _SettingsSliderItemState extends State<SettingsSliderItem> {
  double? _draggingValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (_draggingValue ?? widget.value).clamp(
      widget.min,
      widget.max,
    );
    final label = widget.label?.call(value) ?? value.round().toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.x16,
        vertical: Spacing.x8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: (next) => setState(() => _draggingValue = next),
            onChangeEnd: (next) {
              setState(() => _draggingValue = null);
              widget.onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}
