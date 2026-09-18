import 'package:flutter/material.dart';

class ControlSlider extends StatefulWidget {
  const ControlSlider({
    super.key,
    required this.initialValue,
    required this.maxValue,
    required this.minValue,
    this.onChanged,
  }) : assert(initialValue >= minValue),
       assert(initialValue <= maxValue),
       assert(maxValue > minValue),
       assert(minValue < maxValue);

  final int initialValue;
  final int maxValue;
  final int minValue;
  final ValueChanged<int>? onChanged;

  @override
  State<StatefulWidget> createState() {
    return _ControlSliderState();
  }
}

class _ControlSliderState extends State<ControlSlider> {
  double _value = 0.0;

  @override
  void initState() {
    super.initState();
    _value = _toSliderValue(widget.initialValue);
  }

  @override
  void didUpdateWidget(ControlSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent owns the value, so a change made elsewhere (a settings reset,
    // a restored profile) must move the thumb rather than be ignored.
    if (oldWidget.initialValue != widget.initialValue ||
        oldWidget.minValue != widget.minValue ||
        oldWidget.maxValue != widget.maxValue) {
      _value = _toSliderValue(widget.initialValue);
    }
  }

  double _toSliderValue(int value) {
    final diff = widget.maxValue - widget.minValue;
    return ((value - widget.minValue) / diff) * 100.0;
  }

  int _toSettingValue(double value) {
    final diff = widget.maxValue - widget.minValue;
    return (widget.minValue + (diff * value / 100)).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _value.toDouble(),
      min: 0.0,
      max: 100.0,
      label: "${_value.truncateToDouble()} %",
      onChanged: (double value) {
        setState(() {
          _value = value;
        });

        widget.onChanged?.call(_toSettingValue(value));
      },
    );
  }
}
