import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
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
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  const _StartButton(),
                  if (controller.templates.isEmpty &&
                      controller.history.isEmpty) ...[
                    const SizedBox(height: 28),
                    // 首次使用：引导性空状态（图标 + 说明）
                    Icon(Icons.fitness_center_rounded,
                        size: 40, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    const _EmptyHint(
                      text: '还没有训练模板和历史记录\n开始一次训练后可保存为模板',
                    ),
                  ] else ...[
                    if (controller.templates.isNotEmpty) ...[
                      _SectionHeader(
                        title: '训练模板',
                        trailing: '${controller.templates.length}',
                      ),
                      for (final t in controller.templates)
                        _TemplateCard(template: t),
                    ],
                    if (controller.history.isNotEmpty) ...[
                      _SectionHeader(
                        title: '历史训练',
                        trailing: '${controller.history.length}',
                      ),
                      for (final record in controller.history)
                        _HistoryCard(record: record),
                    ],
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

/// 主 CTA：训练页最重要的动作，占据视觉首位。
class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => context.read<WorkoutController>().startPlanning(),
      icon: const Icon(Icons.play_arrow_rounded, size: 24),
      label: const Text(
        '开始训练',
        style: TextStyle(
          fontSize: AppText.fsHeading,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
      ),
    );
  }
}

/// 分区标题：名称 + 右侧数量。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
      child: Row(
        children: [
          Text(title, style: AppText.sectionTitle),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(
              fontSize: AppText.fsCaption,
              fontWeight: FontWeight.w600,
              fontFeatures: AppText.tabularNums,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AppText.fsBodySm,
        height: 1.6,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// 模板卡片：主题色图标位 + 名称 + 元信息 + 删除。
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final totalSets = t.entries.fold<int>(0, (s, e) => s + e.sets);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.read<WorkoutController>().loadTemplate(t.id),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppText.fsBody,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${t.entries.length} 个动作 · 共 $totalSets 组',
                      style: const TextStyle(
                        fontSize: AppText.fsCaption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                tooltip: '删除模板',
                onPressed: () =>
                    context.read<WorkoutController>().deleteTemplate(t.id),
              ),
            ],
          ),
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
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          dateText,
          style: const TextStyle(
            fontSize: AppText.fsBody,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${r.entries.length} 个动作 · 共 ${r.totalSetsDone} 组 · '
          '感受：${r.feeling} · $durationText',
          style: const TextStyle(
            fontSize: AppText.fsCaption,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: AppColors.textTertiary,
          ),
          tooltip: '删除记录',
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
                        fontSize: AppText.fsBodySm,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
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
                style: TextStyle(
                  fontSize: AppText.fsBodySm,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
