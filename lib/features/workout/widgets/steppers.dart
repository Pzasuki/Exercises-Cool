import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// 小号图标按钮（紧凑点击区，避免行溢出）。
class MiniIconButton extends StatelessWidget {
  const MiniIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: AppColors.textTertiary),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 整数步进器（组数/次数）：label + − 值 +。
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  static const int _step = 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        MiniIconButton(
          icon: Icons.remove_circle_outline,
          onPressed: value - _step >= min ? () => onChanged(value - _step) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        MiniIconButton(
          icon: Icons.add_circle_outline,
          onPressed: value + _step <= max ? () => onChanged(value + _step) : null,
        ),
      ],
    );
  }
}

/// 重量步进（kg，可选）：未设置时点 + 从 10kg 起，减到 2.5 以下回到未设置。
class WeightStepper extends StatelessWidget {
  const WeightStepper({super.key, required this.weight, required this.onChanged});

  final double? weight;
  final ValueChanged<double?> onChanged;

  static const double _step = 2.5;
  static const double _max = 500;

  @override
  Widget build(BuildContext context) {
    final w = weight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '重量',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        MiniIconButton(
          icon: Icons.remove_circle_outline,
          onPressed: w == null
              ? null
              : () => onChanged(w - _step < _step ? null : w - _step),
        ),
        SizedBox(
          width: 52,
          child: Text(
            w == null ? '未设置' : '${formatWeight(w)}kg',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: w == null ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ),
        MiniIconButton(
          icon: Icons.add_circle_outline,
          onPressed: w != null && w + _step > _max
              ? null
              : () => onChanged(w == null ? 10 : w + _step),
        ),
      ],
    );
  }
}
