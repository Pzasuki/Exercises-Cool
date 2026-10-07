import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// 训练各视图共用的顶栏：标题 + 右侧动作区。
class WorkoutHeader extends StatelessWidget {
  const WorkoutHeader({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(title, style: AppText.pageTitle),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}
