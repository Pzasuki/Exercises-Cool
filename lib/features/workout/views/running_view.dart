import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/library_controller.dart';
import '../../../state/workout_controller.dart';
import '../../detail/exercise_detail_sheet.dart';
import '../widgets/workout_header.dart';

// ── running：做组打点 + 间歇倒计时 ──

class RunningView extends StatelessWidget {
  const RunningView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final library = context.watch<LibraryController>();
    final entry = controller.currentEntry;
    final ex = library.byId(entry.exerciseId);
    final isResting = controller.resting;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkoutHeader(
              title: '训练中',
              actions: [
                TextButton(
                  onPressed: () => _confirmAbandon(context),
                  child: const Text('结束',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '动作 ${controller.currentIndex + 1} / ${controller.session.length}',
                      style: const TextStyle(
                        fontSize: AppText.fsCaption,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ex?.name ?? '未知动作',
                      style: const TextStyle(
                        fontSize: AppText.fsTitleLg,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 组进度：已完成实心圆 + 未完成空心圆
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < entry.sets; i++)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < entry.completedSets
                                  ? AppColors.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: i < entry.completedSets
                                    ? AppColors.accent
                                    : AppColors.borderHover,
                                width: 1.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          '第 ${entry.completedSets + 1} / ${entry.sets} 组 · '
                          '每组 ${entry.reps} 次'
                          '${entry.weight == null ? '' : ' · ${formatWeight(entry.weight)}kg'}',
                          style: const TextStyle(
                            fontSize: AppText.fsBodySm,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppText.tabularNums,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    // 休息块：出现/消失带高度与透明度过渡，不打断滚动位置
                    ClipRect(
                      child: AnimatedAlign(
                        alignment: Alignment.topCenter,
                        heightFactor: isResting ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: isResting ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: _RestCard(controller: controller),
                        ),
                      ),
                    ),
                    // 当前动作精简展示：白卡动图 + 动作步骤（元信息/肌群
                    // 在做组间隙没有阅读价值，已省略）；向下滚动翻看
                    if (ex != null) ...[
                      const SizedBox(height: 24),
                      ExerciseDetailBody(exercise: ex, minimal: true),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: isResting
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            context.read<WorkoutController>().completeSet();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.border,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: AppColors.textSecondary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                    child: Text(
                      isResting ? '休息中…' : '完成一组',
                      style: const TextStyle(
                        fontSize: AppText.fsHeading,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        context.read<WorkoutController>().skipExercise(),
                    child: const Text(
                      '跳过该动作',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束训练？'),
        content: const Text('已完成的组数会保留在总结页'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续训练'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<WorkoutController>().abandonSession();
  }
}

/// 组间休息卡：倒计时（等宽数字防跳动）+ 剩余进度条 + 快捷操作。
/// 关闭状态保持挂载（AnimatedAlign 收起高度），避免动画期间子树重建。
class _RestCard extends StatelessWidget {
  const _RestCard({required this.controller});

  final WorkoutController controller;

  @override
  Widget build(BuildContext context) {
    final total = controller.restSeconds;
    final progress =
        total <= 0 ? 0.0 : (controller.restRemaining / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 15, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                '组间休息',
                style: TextStyle(
                  fontSize: AppText.fsBodySm,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatClock(controller.restRemaining),
            style: TextStyle(
              fontSize: AppText.fsTimer,
              height: 1.15,
              fontWeight: FontWeight.w800,
              fontFeatures: AppText.tabularNums,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => context
                    .read<WorkoutController>()
                    .addRestTime(15),
                child: const Text('+15s'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () =>
                    context.read<WorkoutController>().skipRest(),
                child: const Text('跳过休息'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
