import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '动作 ${controller.currentIndex + 1} / ${controller.session.length}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ex?.name ?? '未知动作',
                      style: const TextStyle(
                        fontSize: 20,
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
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < entry.completedSets
                                  ? AppColors.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: i < entry.completedSets
                                    ? AppColors.accent
                                    : AppColors.borderHover,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          '第 ${entry.completedSets + 1} / ${entry.sets} 组 · '
                          '每组 ${entry.reps} 次'
                          '${entry.weight == null ? '' : ' · ${formatWeight(entry.weight)}kg'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (isResting) ...[
                      const SizedBox(height: 28),
                      // 间歇倒计时（休息时最需要的信息，保持在详情正文上方）
                      Column(
                        children: [
                          const Text(
                            '组间休息',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatClock(controller.restRemaining),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                    ],
                    // 当前动作按「动作详情」的样式完整展示（动图 + 部位/器材/
                    // 目标肌肉 + 肌群 + 步骤），与详情弹窗共用 ExerciseDetailBody；
                    // 放在组进度/倒计时之后，向下滚动翻看，不挤占操作区
                    if (ex != null) ...[
                      const SizedBox(height: 24),
                      ExerciseDetailBody(exercise: ex),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: isResting
                        ? null
                        : () => context.read<WorkoutController>().completeSet(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.border,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      isResting ? '休息中…' : '完成一组',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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
