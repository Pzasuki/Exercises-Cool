import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/library_controller.dart';
import '../../../state/workout_controller.dart';
import '../exercise_picker_sheet.dart';
import '../widgets/rest_setting_tile.dart';
import '../widgets/steppers.dart';
import '../widgets/workout_header.dart';

// ── planning：动作清单编辑 ──

class PlanningView extends StatelessWidget {
  const PlanningView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final library = context.watch<LibraryController>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkoutHeader(
              title: '规划训练',
              actions: [
                TextButton(
                  onPressed: () =>
                      context.read<WorkoutController>().cancelPlanning(),
                  child: const Text('取消'),
                ),
              ],
            ),
            Expanded(
              child: controller.session.isEmpty
                  ? const Center(
                      child: Text(
                        '从收藏夹或动作库挑选动作\n每个动作可设置组数、次数与重量',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: controller.session.length,
                      itemBuilder: (context, index) {
                        final entry = controller.session[index];
                        final ex = library.byId(entry.exerciseId);
                        return _PlanEntryCard(
                          index: index,
                          name: ex?.name ?? '未知动作',
                          subtitle: ex == null
                              ? ''
                              : '${zh(ex.target)} · ${zh(ex.equipment)}',
                          thumbnail: ex?.thumbnailAsset,
                          entry: entry,
                        );
                      },
                    ),
            ),
            const RestSettingTile(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ids = await showExercisePicker(context);
                        if (ids == null || ids.isEmpty || !context.mounted) {
                          return;
                        }
                        final controller = context.read<WorkoutController>();
                        for (final id in ids) {
                          controller.addExercise(id);
                        }
                        // 首次添加动作：引导设置默认组数/次数/重量
                        if (!controller.defaultsConfigured && context.mounted) {
                          await _showDefaultsDialog(context);
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('添加动作'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.session.isEmpty
                          ? null
                          : () =>
                              context.read<WorkoutController>().startSession(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: const Text('开始',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
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
}

/// 单条规划卡片：缩略图 + 组/次/重量步进 + 上移/下移/删除。
/// 步进区用 Wrap 兜底、图标按钮收紧点击区，避免窄屏溢出。
class _PlanEntryCard extends StatelessWidget {
  const _PlanEntryCard({
    required this.index,
    required this.name,
    required this.subtitle,
    required this.thumbnail,
    required this.entry,
  });

  final int index;
  final String name;
  final String subtitle;
  final String? thumbnail;
  final SessionEntry entry;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<WorkoutController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: thumbnail == null
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: ColoredBox(color: AppColors.bgElevated))
                      : Image.asset(thumbnail!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.bgElevated)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MiniIconButton(
                      icon: Icons.arrow_upward_rounded,
                      tooltip: '上移',
                      onPressed: index == 0
                          ? null
                          : () => controller.moveEntry(index, -1),
                    ),
                    MiniIconButton(
                      icon: Icons.arrow_downward_rounded,
                      tooltip: '下移',
                      onPressed: () => controller.moveEntry(index, 1),
                    ),
                  ],
                ),
                MiniIconButton(
                  icon: Icons.close,
                  tooltip: '移除',
                  onPressed: () => controller.removeEntry(index),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Wrap 兜底：窄屏放不下时自动换行，杜绝溢出
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                NumberStepper(
                  label: '组',
                  value: entry.sets,
                  min: 1,
                  max: 20,
                  onChanged: (v) => controller.updateEntry(index, sets: v),
                ),
                NumberStepper(
                  label: '次/组',
                  value: entry.reps,
                  min: 1,
                  max: 100,
                  onChanged: (v) => controller.updateEntry(index, reps: v),
                ),
                WeightStepper(
                  weight: entry.weight,
                  onChanged: (v) => controller
                      .updateEntry(index, weight: v, clearWeight: v == null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 首次添加动作的默认参数引导：设置常用组数/次数/重量（可选），
/// 保存后套用到本次清单及之后添加的动作；跳过则保持 3 组 × 10 次。
Future<void> _showDefaultsDialog(BuildContext context) async {
  final controller = context.read<WorkoutController>();
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DefaultsDialog(
      initialSets: controller.defaultSets,
      initialReps: controller.defaultReps,
      initialWeight: controller.defaultWeight,
    ),
  );
  if (!context.mounted) return;
  if (saved == true) return; // 弹窗内已调 saveDefaults
  controller.skipDefaultsSetup();
}

class _DefaultsDialog extends StatefulWidget {
  const _DefaultsDialog({
    required this.initialSets,
    required this.initialReps,
    required this.initialWeight,
  });

  final int initialSets;
  final int initialReps;
  final double? initialWeight;

  @override
  State<_DefaultsDialog> createState() => _DefaultsDialogState();
}

class _DefaultsDialogState extends State<_DefaultsDialog> {
  late int _sets;
  late int _reps;
  late double? _weight;

  @override
  void initState() {
    super.initState();
    _sets = widget.initialSets;
    _reps = widget.initialReps;
    _weight = widget.initialWeight;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置默认训练参数'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '为常用的组数、次数和重量设一个默认值，之后添加的动作会自动套用（可随时单独调整）。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NumberStepper(
                label: '组',
                value: _sets,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _sets = v),
              ),
              NumberStepper(
                label: '次/组',
                value: _reps,
                min: 1,
                max: 100,
                onChanged: (v) => setState(() => _reps = v),
              ),
              WeightStepper(
                weight: _weight,
                onChanged: (v) => setState(() => _weight = v),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('跳过',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            context.read<WorkoutController>().saveDefaults(
                  sets: _sets,
                  reps: _reps,
                  weight: _weight,
                );
            Navigator.pop(context, true);
          },
          child: const Text('保存',
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
