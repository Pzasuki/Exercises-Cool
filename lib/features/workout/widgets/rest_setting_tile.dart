import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/workout_controller.dart';
import 'steppers.dart';

/// 组间间歇设置（规划页底部）：分钟制（1 分钟起），0 = 关闭。
class RestSettingTile extends StatelessWidget {
  const RestSettingTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final enabled = controller.restSeconds > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '组间倒计时',
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          if (enabled) ...[
            MiniIconButton(
              icon: Icons.remove_circle_outline,
              onPressed: controller.restMinutes <= 1
                  ? null
                  : () => controller
                      .setRestMinutes(controller.restMinutes - 1),
            ),
            Text(
              '${controller.restMinutes} 分钟',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            MiniIconButton(
              icon: Icons.add_circle_outline,
              onPressed: controller.restMinutes >= 10
                  ? null
                  : () =>
                      controller.setRestMinutes(controller.restMinutes + 1),
            ),
            const SizedBox(width: 4),
          ] else ...[
            const Text(
              '关',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: enabled,
            activeThumbColor: AppColors.accent,
            onChanged: (v) =>
                context.read<WorkoutController>().setRestSeconds(v ? 60 : 0),
          ),
        ],
      ),
    );
  }
}
