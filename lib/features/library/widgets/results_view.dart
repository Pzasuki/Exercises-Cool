import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/library_controller.dart';
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

    // extendBody：底部叠加悬浮导航栏，网格留出避让高度
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final EdgeInsets padding;
    final SliverGridDelegate delegate;
    if (isCompact) {
      padding = EdgeInsets.fromLTRB(10, 12, 10, 24 + bottomInset);
      delegate = const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.55,
      );
    } else {
      padding = isNarrow
          ? EdgeInsets.fromLTRB(12, 12, 12, 28 + bottomInset)
          : EdgeInsets.fromLTRB(20, 16, 20, 32 + bottomInset);
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
        // 结果条（白底区块）：已选筛选徽章（含分类，可单个移除）+ 清除全部 + 计数，
        // 「全部动作」与分类页两种形态统一由它承担状态展示
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const ResultsBar(),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  title: '未找到相关动作',
                  subtitle: '换个关键词，或清除部分筛选条件试试',
                )
              : GridView.builder(
                  controller: scrollController,
                  padding: padding,
                  gridDelegate: delegate,
                  itemCount: controller.hasMore
                      ? items.length + 1
                      : items.length,
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
