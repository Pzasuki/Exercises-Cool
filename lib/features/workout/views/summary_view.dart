import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/workout_controller.dart';
import '../widgets/workout_header.dart';

// ── finished：训练感受 + 总结 / 存模板 ──

/// 训练感受选项（轻 → 重）。
const List<String> _kWorkoutFeelings = ['轻松', '刚好', '有点累', '很累'];

class SummaryView extends StatelessWidget {
  const SummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WorkoutHeader(title: '训练完成'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 56, color: AppColors.accent),
                        const SizedBox(height: 12),
                        Text(
                          '完成 ${controller.session.length} 个动作 · '
                          '共 ${controller.totalSetsDone} 组',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      '这次训练感觉怎么样？',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final f in _kWorkoutFeelings)
                        ChoiceChip(
                          label: Text(f),
                          selected: controller.feeling == f,
                          onSelected: (_) =>
                              context.read<WorkoutController>().setFeeling(f),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: controller.feeling == f
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                          selectedColor: AppColors.accentMuted,
                          side: BorderSide(
                            color: controller.feeling == f
                                ? AppColors.accent
                                : AppColors.border,
                          ),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _templateNameDialog(context);
                      if (name == null || name.trim().isEmpty) return;
                      if (!context.mounted) return;
                      context
                          .read<WorkoutController>()
                          .saveTemplate(name.trim());
                    },
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('存为模板'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () =>
                        context.read<WorkoutController>().finishAndSave(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('完成',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _templateNameDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('存为模板'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '模板名称，如：胸肩日'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
