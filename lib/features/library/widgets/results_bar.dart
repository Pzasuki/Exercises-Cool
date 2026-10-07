import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../state/library_controller.dart';

/// 结果条：结果计数 +（分类页形态下）分类名标题。
/// 不展示已选筛选内容——选择状态统一由筛选入口承担（窄屏「筛选」
/// 弹层 / 宽屏侧栏芯片），避免同一份筛选状态在页面顶部重复出现。
class ResultsBar extends StatelessWidget {
  const ResultsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;

    return Padding(
      padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 10, isNarrow ? 14 : 20, 10),
      child: Row(
        children: [
          // 分类页形态：分类名即页面标题（全部动作形态不重复占位）
          if (controller.hasSingleCategory) ...[
            Text(
              zh(controller.currentCategory),
              style: const TextStyle(
                fontSize: AppText.fsHeading,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              controller.filtered.length == controller.totalCount
                  ? '共 ${controller.totalCount} 个动作'
                  : '${controller.filtered.length} / ${controller.totalCount} 个动作',
              maxLines: 1,
              style: const TextStyle(
                fontSize: AppText.fsCaption,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
