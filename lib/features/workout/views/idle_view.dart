import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/workout.dart';
import '../../../state/library_controller.dart';
import '../../../state/workout_controller.dart';
import '../widgets/workout_header.dart';

// ── idle：模板 + 历史训练 + 开始入口 ──

class IdleView extends StatelessWidget {
  const IdleView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WorkoutHeader(title: '训练'),
            Expanded(
              child: controller.templates.isEmpty && controller.history.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 14),
                        _StartButton(),
                        const _EmptyHint(
                          text: '还没有训练模板和历史记录\n开始一次训练后可保存为模板',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: _StartButton(),
                        ),
                        if (controller.templates.isNotEmpty) ...[
                          const _SectionTitle('训练模板'),
                          for (final t in controller.templates)
                            _TemplateCard(template: t),
                        ],
                        if (controller.history.isNotEmpty) ...[
                          const _SectionTitle('历史训练'),
                          for (final record in controller.history)
                            _HistoryCard(record: record),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => context.read<WorkoutController>().startPlanning(),
      icon: const Icon(Icons.play_arrow_rounded, size: 22),
      label: const Text('开始训练',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final totalSets = t.entries.fold<int>(0, (s, e) => s + e.sets);
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: () => context.read<WorkoutController>().loadTemplate(t.id),
        leading: const Icon(Icons.fitness_center, size: 22, color: AppColors.accent),
        title: Text(
          t.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${t.entries.length} 个动作 · 共 $totalSets 组',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 20, color: AppColors.textTertiary),
          onPressed: () =>
              context.read<WorkoutController>().deleteTemplate(t.id),
        ),
      ),
    );
  }
}

/// 历史训练卡片：摘要 + 展开看动作明细，可删除。
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final date = DateTime.tryParse(r.dateIso);
    final dateText = date == null
        ? ''
        : '${date.month}月${date.day}日 '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final durationText = r.durationSeconds >= 60
        ? '${(r.durationSeconds / 60).round()} 分钟'
        : '${r.durationSeconds} 秒';
    final library = context.watch<LibraryController>();

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: const Icon(Icons.history, size: 22, color: AppColors.textSecondary),
        title: Text(
          dateText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${r.entries.length} 个动作 · 共 ${r.totalSetsDone} 组 · '
          '感受：${r.feeling} · $durationText',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 20, color: AppColors.textTertiary),
          onPressed: () => context.read<WorkoutController>().deleteRecord(r.id),
        ),
        children: [
          for (final e in r.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      library.byId(e.exerciseId)?.name ?? '未知动作',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${e.completedSets}/${e.sets} 组 · 每组 ${e.reps} 次'
                    '${e.weight == null ? '' : ' · ${formatWeight(e.weight)}kg'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // 按这次训练的计划（组数/次数/重量）重新开始规划
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.read<WorkoutController>().repeatRecord(r.id),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text(
                '再练一次',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
