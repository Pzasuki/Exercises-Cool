import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/exercise.dart';
import '../favorites/folder_picker_sheet.dart';
import '../../state/favorites_service.dart';

/// 打开动作详情，对应 JS openModal()：
/// - 宽屏（≥768px）：居中弹窗（.modal-panel：min(660px,100%)、毛玻璃遮罩、Esc/遮罩关闭）
/// - 窄屏：底部弹层（@media 768：max-height 92dvh、上圆角）
/// 两种形态共用 [_DetailContent]。
/// 多语言步骤页签：原版同样只接 zh（`const langs = ['zh']`），
/// 数据加入其他语言后再在步骤区加 TabBar。
Future<void> showExerciseDetail(BuildContext context, Exercise exercise) {
  // 打开前释放输入焦点：从搜索结果点卡片时，避免输入法悬在弹层下、
  // 关闭后又被拉起
  FocusManager.instance.primaryFocus?.unfocus();
  final isWide = MediaQuery.sizeOf(context).width >= kNarrowBreakpoint;
  if (isWide) {
    return _showCenteredDialog(context, exercise);
  }
  return _showBottomSheet(context, exercise);
}

Future<void> _showCenteredDialog(BuildContext context, Exercise exercise) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭详情',
    // rgba(0,0,0,0.45)，对应 .modal-overlay background
    barrierColor: const Color(0x73000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Stack(
      children: [
        // 毛玻璃遮罩：颜色由上面的 barrier 绘制，这里只负责模糊
        // （对应 backdrop-filter: blur(6px)）。IgnorePointer 让点击穿透到 barrier。
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Center(
          // Esc 关闭（对应 keydown Escape → closeModal）
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _ModalPanel(exercise: exercise),
          ),
        ),
      ],
    ),
    transitionBuilder:
        (context, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// 居中弹窗面板（.modal-panel）：宽 min(660, 视口-32)、高 ≤ 视口-40，
/// 内容超出时面板内部滚动。
class _ModalPanel extends StatelessWidget {
  const _ModalPanel({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(660.0, size.width - 32),
        maxHeight: size.height - 40,
      ),
      child: Material(
        color: AppColors.bgSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          side: const BorderSide(color: AppColors.border),
        ),
        child: _DetailContent(exercise: exercise, centered: true),
      ),
    );
  }
}

Future<void> _showBottomSheet(BuildContext context, Exercise exercise) {
  final size = MediaQuery.sizeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgSurface,
    constraints: BoxConstraints(maxHeight: size.height * 0.92),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusXl),
      ),
    ),
    builder: (_) => _DetailContent(exercise: exercise, centered: false),
  );
}

/// 详情内容（.modal-header）：桌面弹窗与移动弹层共用。
/// 正文（媒体/元信息/肌群/步骤）抽为公开的 [ExerciseDetailBody]，
/// 训练执行页按需求以同样的详情样式展示当前动作。
class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.exercise, required this.centered});

  final Exercise exercise;

  /// true = 桌面居中弹窗形态（内边距 18 / 动图限高 320）。
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 480; // @media 480：内边距 16
    final hPad = compact ? 16.0 : 18.0;
    final gifMaxHeight = centered ? 320.0 : 240.0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          hPad,
          centered ? 18 : 16,
          hPad,
          centered ? 22 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── .modal-header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ex.name,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _FavoriteButton(exerciseId: ex.id),
                const SizedBox(width: 8),
                const _CloseButton(),
              ],
            ),
            const SizedBox(height: 14),
            ExerciseDetailBody(exercise: ex, gifMaxHeight: gifMaxHeight),
          ],
        ),
      ),
    );
  }
}

/// 详情正文（.modal-media/.modal-meta/.modal-muscles/.modal-instructions）：
/// 动图媒体区、部位/器材/目标肌肉元信息、主要/次要肌群、编号步骤。
/// 详情弹窗与训练执行页（训练中查看当前动作）共用，保证两处样式一致。
class ExerciseDetailBody extends StatelessWidget {
  const ExerciseDetailBody({
    super.key,
    required this.exercise,
    this.gifMaxHeight = 240,
    this.minimal = false,
  });

  final Exercise exercise;

  /// 动图区限高：桌面居中弹窗 320 / 弹层与执行页 240。
  final double gifMaxHeight;

  /// 精简形态（训练执行页）：仅保留动图与动作步骤——做组间隙没有时间
  /// 阅读元信息与肌群。动图在两种形态下都用白底卡片：
  /// 插画本身是白底，白卡可与其无缝融合（训练页与详情弹窗一致）。
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    final steps = ex.displaySteps;
    // 次要肌群：优先 secondary_muscles，为空时回退 muscle_group，
    // 并剔除与主要目标重复的项（对应 openModal 的 primary/secondary 逻辑）。
    final secondaryRaw = ex.secondaryMuscles.isNotEmpty
        ? ex.secondaryMuscles
        : (ex.muscleGroup.isNotEmpty ? [ex.muscleGroup] : const <String>[]);
    final secondary =
        secondaryRaw.where((m) => m != ex.target).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── .modal-media ──
        Container(
          constraints: BoxConstraints(maxHeight: gifMaxHeight),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.asset(
            ex.animationAsset,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SizedBox(height: gifMaxHeight),
          ),
        ),
        const SizedBox(height: 14),
        if (!minimal) ...[
          // ── .modal-meta ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(label: '部位', value: zh(ex.bodyPart)),
              _MetaChip(label: '器材', value: zh(ex.equipment)),
              _MetaChip(label: '目标肌肉', value: zh(ex.target)),
            ],
          ),
          const SizedBox(height: 14),
          // ── .modal-muscles（底部带分隔线）──
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('肌肉'),
                const SizedBox(height: 10),
                _MusclesGrid(
                  primary:
                      ex.target.isEmpty ? const <String>[] : [ex.target],
                  secondary: secondary,
                ),
              ],
            ),
          ),
        ],
        // ── .modal-instructions ──
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('动作步骤'),
              const SizedBox(height: 10),
              if (steps.isEmpty)
                const Text(
                  '暂无步骤说明',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                ...List.generate(
                  steps.length,
                  (i) => _Step(index: i + 1, text: steps[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 收藏按钮：已收藏（任一收藏夹）为实心主题色，点击打开收藏夹选择弹层。
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final favorited =
        context.watch<FavoritesService>().isFavorite(exerciseId);
    return Material(
      color: favorited ? AppColors.accentMuted : AppColors.bgElevated,
      shape: CircleBorder(
        side: BorderSide(
          color: favorited ? AppColors.accent : AppColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        // 点按：只有默认收藏夹时直接收进/移出；有其他收藏夹时弹层选择
        // 去处（弹层里也可取消勾选移出）。长按 = 打开收藏夹选择弹层
        onTap: () {
          HapticFeedback.selectionClick();
          final service = context.read<FavoritesService>();
          if (service.folders.length > 1) {
            showFavoriteFolderPicker(context, exerciseId);
          } else {
            service.toggleDefault(exerciseId);
          }
        },
        onLongPress: () => showFavoriteFolderPicker(context, exerciseId),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            favorited ? Icons.favorite : Icons.favorite_outline,
            size: 17,
            color: favorited ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 关闭按钮（.modal-close）：28px 圆形，悬停变主题色。
class _CloseButton extends StatefulWidget {
  const _CloseButton();

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: _hover ? AppColors.accentMuted : AppColors.bgElevated,
        shape: CircleBorder(
          side: BorderSide(
            color: _hover ? AppColors.accent : AppColors.border,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 元信息小卡（.meta-chip）：上标签下值。
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppText.fsMicro,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppText.fsBodySm,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.overline);
  }
}

/// 肌群区（.muscles-grid）：按内容区实际宽度分流——放得下就一行两列并排，
/// 否则单列堆叠。（不用窗口宽度判断：手机上弹层内容区足够放下两列）
class _MusclesGrid extends StatelessWidget {
  const _MusclesGrid({required this.primary, required this.secondary});

  final List<String> primary;
  final List<String> secondary;

  @override
  Widget build(BuildContext context) {
    final groups = <Widget>[
      if (primary.isNotEmpty)
        _MuscleGroup(title: '主要肌群', names: primary, isPrimary: true),
      if (secondary.isNotEmpty)
        _MuscleGroup(title: '次要肌群', names: secondary, isPrimary: false),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 300) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final g in groups) ...[
                Expanded(child: g),
                if (g != groups.last) const SizedBox(width: 8),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: g,
              ),
          ],
        );
      },
    );
  }
}

class _MuscleGroup extends StatelessWidget {
  const _MuscleGroup({
    required this.title,
    required this.names,
    required this.isPrimary,
  });

  final String title;
  final List<String> names;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.overline),
            const SizedBox(height: 7),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final n in names) _MuscleTag(name: n, isPrimary: isPrimary),
              ],
            ),
          ],
        ),
    );
  }
}

class _MuscleTag extends StatelessWidget {
  const _MuscleTag({required this.name, required this.isPrimary});

  final String name;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.accent : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isPrimary ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Text(
        zh(name),
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
          color: isPrimary ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// 编号步骤（.instruction-step）。
class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
