import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/library_controller.dart';
import 'category_target_bar.dart';
import 'empty_state.dart';
import 'exercise_card.dart';
import 'results_bar.dart';

/// 结果视图：结果条 + 目标肌群快捷行 + 卡片网格（无限滚动）。
/// 浏览页与总览页的搜索结果共用；网格三档布局对应
/// .exercise-grid / .grid-wrapper 的桌面、768、480 三档媒体查询。
class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final items = controller.visibleExercises;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width <= 480; // @media 480：固定两列
    final isNarrow = width < kNarrowBreakpoint;

    final EdgeInsets padding;
    final SliverGridDelegate delegate;
    if (isCompact) {
      padding = const EdgeInsets.fromLTRB(10, 12, 10, 24);
      delegate = const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.55,
      );
    } else {
      padding = isNarrow
          ? const EdgeInsets.fromLTRB(12, 12, 12, 28)
          : const EdgeInsets.fromLTRB(20, 16, 20, 32);
      delegate = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isNarrow
            ? AppDimens.gridCardMaxExtentNarrow
            : AppDimens.gridCardMaxExtent,
        mainAxisSpacing: isNarrow
            ? AppDimens.gridSpacingNarrow
            : AppDimens.gridSpacing,
        crossAxisSpacing: isNarrow
            ? AppDimens.gridSpacingNarrow
            : AppDimens.gridSpacing,
        // 卡片 = 3:4 媒体区 + 名称/标签区，整体比例近似取值；
        // 媒体区用 Expanded 吸收剩余高度，不会溢出。
        childAspectRatio: 0.55,
      );
    }

    return Column(
      children: [
        // 筛选模块：结果条与状态行（快捷行 + 计数）共用一个白色区块，
        // 避免灰白交替的割裂感（器材/搜索仍在上方面板内，同属一块筛选区）。
        // 分类页形态下结果条不显示——分类徽章与页面标题重复，
        // 计数由状态行右侧承担；「全部动作」视图保留完整结果条。
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              if (!controller.hasSingleCategory) const ResultsBar(),
              const CategoryTargetBar(),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState()
              : GridView.builder(
                  controller: scrollController,
                  padding: padding,
                  gridDelegate: delegate,
                  itemCount:
                      controller.hasMore ? items.length + 1 : items.length,
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      // 尾部加载指示（对应 .load-spinner）
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return ExerciseCard(exercise: items[index]);
                  },
                ),
        ),
      ],
    );
  }
}
