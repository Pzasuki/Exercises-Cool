import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/library_controller.dart';

/// 分类页筛选模块里的状态行：左侧「目标肌肉」快捷芯片（该分类下有
/// ≥2 个肌群时显示，单肌群分类只剩计数），右侧当前结果计数。
/// 分类页形态下结果条不显示（分类徽章与页面标题重复），计数由此承担。
/// 芯片只显示当前有结果的肌群；背景/边框由 ResultsView 的筛选模块容器提供。
class CategoryTargetBar extends StatelessWidget {
  const CategoryTargetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    if (!controller.hasSingleCategory) return const SizedBox.shrink();
    final targets =
        controller.categoryTargets[controller.currentCategory] ?? const [];

    final selected = controller.filtersOf(FilterKey.target);
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;
    // 0 结果的肌群不显示；已选中的保留（即便被器材/搜索临时压到 0，也要能取消）
    final visibleTargets = targets.length < 2
        ? const <String>[]
        : [
            for (final t in targets)
              if (selected.contains(t) ||
                  controller.countFor(FilterKey.target, t) > 0)
                t,
          ];

    Widget chip({
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Material(
        color: active ? AppColors.accentMuted : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding:
          EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 8, isNarrow ? 14 : 20, 8),
      child: Row(
        children: [
          Expanded(
            child: visibleTargets.isEmpty
                ? const SizedBox.shrink()
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          chip(
                            // 「全部」= 清空目标肌群维度后的结果数
                            label:
                                '全部 ${controller.countWithout(FilterKey.target)}',
                            active: selected.isEmpty,
                            onTap: () =>
                                controller.clearFilter(FilterKey.target),
                          ),
                          for (final t in visibleTargets) ...[
                            const SizedBox(width: 5),
                            chip(
                              label:
                                  '${zh(t)} ${controller.countFor(FilterKey.target, t)}',
                              active: selected.contains(t),
                              onTap: () => controller
                                  .toggleFilter(FilterKey.target, t),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          if (visibleTargets.isNotEmpty) const SizedBox(width: 8),
          Text(
            '${controller.filtered.length} / ${controller.totalCount} 个动作',
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
