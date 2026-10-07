import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../state/library_controller.dart';
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
    final library = context.watch<LibraryController>();
    final durationText = _formatDuration(controller.sessionDurationSeconds);
    // 总重量：有重量条目 Σ 完成组数×次数×重量；全徒手时不展示该格
    final totalVolume = _totalVolume(controller);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WorkoutHeader(title: '训练完成'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  // ── 完成徽章 + 结果摘要 ──
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.accentMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 40,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '完成 ${controller.session.length} 个动作 · '
                          '共 ${controller.totalSetsDone} 组',
                          style: const TextStyle(
                            fontSize: AppText.fsHeading,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // ── 数据卡：用时 + 总重量（全徒手时只有用时）──
                  _StatsCard(
                    cells: [
                      ('用时', durationText),
                      if (totalVolume > 0) ('总重量', '${formatWeight(totalVolume)}kg'),
                    ],
                  ),
                  // ── 动作明细 ──
                  if (controller.session.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
                      child: Text('动作明细', style: AppText.sectionTitle),
                    ),
                    _DetailCard(controller: controller, library: library),
                  ],
                  const SizedBox(height: 24),
                  // ── 训练感受 ──
                  const Center(
                    child: Text(
                      '这次训练感觉怎么样？',
                      style: TextStyle(
                        fontSize: AppText.fsBodySm,
                        color: AppColors.textSecondary,
                      ),
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
                            fontSize: AppText.fsCaption,
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
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
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
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        fontSize: AppText.fsHeading,
                        fontWeight: FontWeight.w700,
                      ),
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

  static double _totalVolume(WorkoutController controller) {
    var volume = 0.0;
    for (final e in controller.session) {
      final w = e.weight;
      if (w != null) volume += w * e.reps * e.completedSets;
    }
    return volume;
  }

  static String _formatDuration(int seconds) {
    if (seconds >= 60) return '${(seconds / 60).round()} 分钟';
    return '$seconds 秒';
  }
}

/// 统计卡：等分的「标签 + 数值」单元格，竖线分隔。
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 30,
                color: AppColors.border,
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    cells[i].$2,
                    style: const TextStyle(
                      fontSize: AppText.fsHeading,
                      fontWeight: FontWeight.w800,
                      fontFeatures: AppText.tabularNums,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cells[i].$1,
                    style: const TextStyle(
                      fontSize: AppText.fsMicro,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 逐动作明细卡：缩略图 + 动作名 + 完成组数/次数/重量。
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.controller, required this.library});

  final WorkoutController controller;
  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < controller.session.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 62, color: AppColors.border),
            _DetailRow(
              name: library.byId(controller.session[i].exerciseId)?.name ??
                  '未知动作',
              thumbnail:
                  library.byId(controller.session[i].exerciseId)?.thumbnailAsset,
              entry: controller.session[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.name,
    required this.thumbnail,
    required this.entry,
  });

  final String name;
  final String? thumbnail;
  final SessionEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: thumbnail == null
                ? const SizedBox(
                    width: 42,
                    height: 42,
                    child: ColoredBox(color: AppColors.bgElevated))
                : Image.asset(thumbnail!,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.bgElevated)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppText.fsBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${e.completedSets}/${e.sets} 组 · 每组 ${e.reps} 次'
            '${e.weight == null ? '' : ' · ${formatWeight(e.weight)}kg'}',
            style: const TextStyle(
              fontSize: AppText.fsCaption,
              fontFeatures: AppText.tabularNums,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
