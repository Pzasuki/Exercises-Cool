import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/library_controller.dart';

/// 结果条，对应 .results-bar：已选筛选徽章（可逐个移除）+「清除全部」+ 计数。
/// 原版徽章按 分类 → 器材 → 目标肌肉 的顺序排列。
class ResultsBar extends StatelessWidget {
  const ResultsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;

    final badges = <Widget>[];
    for (final key in FilterKey.values) {
      for (final value in controller.filtersOf(key)) {
        badges.add(
          _ActiveBadge(
            label: zh(value),
            onRemove: () => controller.toggleFilter(key, value),
          ),
        );
      }
    }

    // 背景/边框由 ResultsView 的筛选模块容器统一提供
    return Padding(
      padding: isNarrow
          ? const EdgeInsets.fromLTRB(14, 10, 14, 8)
          : const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...badges,
          if (badges.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.clearAllFilters,
              child: const Text(
                '清除全部',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          Text(
            controller.filtered.length == controller.totalCount
                ? '共 ${controller.totalCount} 个动作'
                : '${controller.filtered.length} / ${controller.totalCount} 个动作',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 已选筛选徽章（.active-badge）：主题色描边胶囊，× 移除单个条件。
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 8, 3),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 13,
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
