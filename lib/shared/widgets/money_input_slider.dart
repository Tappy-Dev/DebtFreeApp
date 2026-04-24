import 'package:flutter/material.dart';

class MoneyInputSlider extends StatefulWidget {
  const MoneyInputSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.prefix = '\u00A3',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String prefix;
  final ValueChanged<double> onChanged;

  @override
  State<MoneyInputSlider> createState() => _MoneyInputSliderState();
}

class _MoneyInputSliderState extends State<MoneyInputSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value.clamp(widget.min, widget.max);
  }

  @override
  void didUpdateWidget(MoneyInputSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value.clamp(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '${widget.prefix}${_currentValue.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Slider(
            value: _currentValue,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: (double value) {
              setState(() {
                _currentValue = value;
              });
              widget.onChanged(value);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${widget.prefix}${widget.min.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${widget.prefix}${widget.max.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
