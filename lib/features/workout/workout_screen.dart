import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/workout.dart';
import '../../state/library_controller.dart';
import '../../state/workout_controller.dart';
import 'exercise_picker_sheet.dart';

/// 训练 Tab：按控制器状态机分流
/// idle（模板 + 历史 + 开始入口）→ planning（挑动作/组次/重量/间歇）→
/// running（做组打点 + 间歇倒计时）→ finished（感受 + 总结/存模板）。
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return switch (controller.status) {
      WorkoutStatus.idle => const _IdleView(),
      WorkoutStatus.planning => const _PlanningView(),
      WorkoutStatus.running => const _RunningView(),
      WorkoutStatus.finished => const _SummaryView(),
    };
  }
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}

// ── idle：模板 + 历史训练 + 开始入口 ──

class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _WorkoutHeader(title: '训练'),
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
        ],
      ),
    );
  }
}

// ── planning：动作清单编辑 ──

class _PlanningView extends StatelessWidget {
  const _PlanningView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final library = context.watch<LibraryController>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WorkoutHeader(
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
            const _RestSettingTile(),
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
                    _MiniIconButton(
                      icon: Icons.arrow_upward_rounded,
                      tooltip: '上移',
                      onPressed: index == 0
                          ? null
                          : () => controller.moveEntry(index, -1),
                    ),
                    _MiniIconButton(
                      icon: Icons.arrow_downward_rounded,
                      tooltip: '下移',
                      onPressed: () => controller.moveEntry(index, 1),
                    ),
                  ],
                ),
                _MiniIconButton(
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
                _Stepper(
                  label: '组',
                  value: entry.sets,
                  min: 1,
                  max: 20,
                  onChanged: (v) => controller.updateEntry(index, sets: v),
                ),
                _Stepper(
                  label: '次/组',
                  value: entry.reps,
                  min: 1,
                  max: 100,
                  onChanged: (v) => controller.updateEntry(index, reps: v),
                ),
                _WeightStepper(
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

/// 小号图标按钮（紧凑点击区，避免行溢出）。
class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: AppColors.textTertiary),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  static const int _step = 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        _MiniIconButton(
          icon: Icons.remove_circle_outline,
          onPressed: value - _step >= min ? () => onChanged(value - _step) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _MiniIconButton(
          icon: Icons.add_circle_outline,
          onPressed: value + _step <= max ? () => onChanged(value + _step) : null,
        ),
      ],
    );
  }
}

/// 重量步进（kg，可选）：未设置时点 + 从 10kg 起，减到 2.5 以下回到未设置。
class _WeightStepper extends StatelessWidget {
  const _WeightStepper({required this.weight, required this.onChanged});

  final double? weight;
  final ValueChanged<double?> onChanged;

  static const double _step = 2.5;
  static const double _max = 500;

  @override
  Widget build(BuildContext context) {
    final w = weight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '重量',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        _MiniIconButton(
          icon: Icons.remove_circle_outline,
          onPressed: w == null
              ? null
              : () => onChanged(w - _step < _step ? null : w - _step),
        ),
        SizedBox(
          width: 52,
          child: Text(
            w == null ? '未设置' : '${formatWeight(w)}kg',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: w == null ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
        ),
        _MiniIconButton(
          icon: Icons.add_circle_outline,
          onPressed: w != null && w + _step > _max
              ? null
              : () => onChanged(w == null ? 10 : w + _step),
        ),
      ],
    );
  }
}

/// 组间间歇设置（规划页底部）：分钟制（1 分钟起），0 = 关闭。
class _RestSettingTile extends StatelessWidget {
  const _RestSettingTile();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final enabled = controller.restSeconds > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '组间倒计时',
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          if (enabled) ...[
            _MiniIconButton(
              icon: Icons.remove_circle_outline,
              onPressed: controller.restMinutes <= 1
                  ? null
                  : () => controller
                      .setRestMinutes(controller.restMinutes - 1),
            ),
            Text(
              '${controller.restMinutes} 分钟',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            _MiniIconButton(
              icon: Icons.add_circle_outline,
              onPressed: controller.restMinutes >= 10
                  ? null
                  : () =>
                      controller.setRestMinutes(controller.restMinutes + 1),
            ),
            const SizedBox(width: 4),
          ] else ...[
            const Text(
              '关',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: enabled,
            activeThumbColor: AppColors.accent,
            onChanged: (v) =>
                context.read<WorkoutController>().setRestSeconds(v ? 60 : 0),
          ),
        ],
      ),
    );
  }
}

// ── running：做组打点 + 间歇倒计时 ──

class _RunningView extends StatelessWidget {
  const _RunningView();

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
            _WorkoutHeader(
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
                      // 间歇倒计时
                      Column(
                        children: [
                          const Text(
                            '组间休息',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatSeconds(controller.restRemaining),
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

// ── finished：训练感受 + 总结 / 存模板 ──

class _SummaryView extends StatelessWidget {
  const _SummaryView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _WorkoutHeader(title: '训练完成'),
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
                      for (final f in kWorkoutFeelings)
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

/// 训练感受选项（轻 → 重）。
const List<String> kWorkoutFeelings = ['轻松', '刚好', '有点累', '很累'];

/// 重量显示：整数不带小数位，其余保留 1 位。
String formatWeight(double? weight) {
  if (weight == null) return '';
  return weight % 1 == 0
      ? weight.toStringAsFixed(0)
      : weight.toStringAsFixed(1);
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
              _Stepper(
                label: '组',
                value: _sets,
                min: 1,
                max: 20,
                onChanged: (v) => setState(() => _sets = v),
              ),
              _Stepper(
                label: '次/组',
                value: _reps,
                min: 1,
                max: 100,
                onChanged: (v) => setState(() => _reps = v),
              ),
              _WeightStepper(
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

String _formatSeconds(int total) {
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
