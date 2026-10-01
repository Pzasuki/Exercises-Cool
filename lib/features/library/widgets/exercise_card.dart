import 'package:flutter/material.dart';

import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/exercise.dart';
import '../../detail/exercise_detail_sheet.dart';

/// 动作卡片，对应 CSS .exercise-card：3:4 媒体区 + 名称 + 分类/器材标签。
/// 桌面端悬停、触屏端长按都切换为动图预览（对应 .card-gif 的 hover 逻辑；
/// 原版移动端靠触摸触发 :hover，这里用长按显式承接）；点击打开详情弹窗。
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _hovering = false;
  bool _longPressing = false;

  /// 预览激活态（桌面悬停或触屏长按）：切动图 + 上浮描边。
  bool get _active => _hovering || _longPressing;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => showExerciseDetail(context, ex),
        onLongPressStart: (_) => setState(() => _longPressing = true),
        onLongPressEnd: (_) => setState(() => _longPressing = false),
        onLongPressCancel: () => setState(() => _longPressing = false),
        // 对应 .exercise-card:hover：上浮 3px、主题色描边、阴影（150ms 过渡）
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _active ? -3 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            boxShadow: _active
                ? const [
                    // rgba(0,0,0,0.1) 0 8px 24px
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          // 边框画在子组件之上（foregroundDecoration）：否则铺满媒体区的
          // 图片会盖住 decoration 里的边框，四角只剩残缺的弧线。
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: _active ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // 对应 .card-thumb/.card-gif：激活时静图淡出、动图淡入（200ms）
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: _active
                      ? KeyedSubtree(
                          key: const ValueKey('anim'),
                          child: Image.asset(
                            ex.animationAsset,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: AppColors.bgElevated),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('thumb'),
                          child: Image.asset(
                            ex.thumbnailAsset,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: AppColors.bgElevated),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ex.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // 对应 .card-tags（flex-wrap）：标签按内容自适应宽度，放不下时换行
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _Tag(
                          text: zh(ex.category),
                          bg: AppColors.tagCatBg,
                          fg: AppColors.tagCatText,
                        ),
                        _Tag(
                          text: zh(ex.equipment),
                          bg: AppColors.tagEquipBg,
                          fg: AppColors.tagEquipText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小标签（.tag / .tag-cat / .tag-equip）。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
