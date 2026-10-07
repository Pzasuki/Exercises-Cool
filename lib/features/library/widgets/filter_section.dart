import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../state/library_controller.dart';

/// 筛选分区（.filter-section）：标题 + 芯片组。
/// 数据源为 [LibraryController.orderedValues]——分类按固定业务顺序、
/// 其余按全库数量降序，选中不改变位置（由高亮表达）；
/// 0 结果的芯片直接不显示（已选中的除外，保证可以取消）。
/// 芯片不显示数量数字（facet 计数仅用于上述显隐逻辑）。
/// 芯片为换行流布局。
/// [initialLimit] 非空时收起态只显示前 N 个芯片，「更多」展开其余。
class FilterSection extends StatefulWidget {
  const FilterSection({
    super.key,
    required this.title,
    required this.filterKey,
    this.horizontal = false,
    this.initialLimit,
  });

  final String title;
  final FilterKey filterKey;

  /// true = 单行横向滚动（旧窄屏面板形态，现版面已不再传入 true）。
  final bool horizontal;

  /// 收起态最多显示的芯片数（已选中的始终优先显示）。
  final int? initialLimit;

  @override
  State<FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends State<FilterSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final selected = controller.filtersOf(widget.filterKey);
    final allValues = controller.orderedValues(widget.filterKey);

    // 只显示有结果的芯片；收起态截取前 N 个，「更多」展开其余
    final qualifying = [
      for (final v in allValues)
        if (selected.contains(v) ||
            controller.countFor(widget.filterKey, v) > 0)
          v,
    ];
    final limit = widget.initialLimit;
    final collapsed = limit != null && !_expanded;
    final shown = collapsed && qualifying.length > limit
        ? qualifying.sublist(0, limit)
        : qualifying;
    final hasToggle =
        limit != null && (_expanded || qualifying.length > limit);

    final chips = <Widget>[
      for (final value in shown)
        _FilterChip(
          label: zh(value),
          active: selected.contains(value),
          onTap: () => controller.toggleFilter(widget.filterKey, value),
        ),
    ];
    if (hasToggle) {
      chips.add(_MoreChip(
        expanded: _expanded,
        onTap: () => setState(() => _expanded = !_expanded),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: AppText.overline),
        const SizedBox(height: 8),
        if (widget.horizontal)
          // 窄屏：单行横滑，隐藏滚动条（原版 ::-webkit-scrollbar display:none）
          ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final chip in chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: chip,
                    ),
                ],
              ),
            ),
          )
        else
          Wrap(spacing: 5, runSpacing: 5, children: chips),
      ],
    );
  }
}

/// 筛选芯片（.chip / .chip.active）：软填充胶囊（无描边），选中为
/// 主题色浅底 + 主题色文字。不显示数量数字。
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: active
            ? AppColors.accentMuted
            : (_hover ? AppColors.bgElevated : AppColors.bgInput),
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: AppText.fsCaption,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「更多 / 收起」切换（对应器材等长尾维度的折叠）。
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgInput,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expanded ? '收起' : '更多',
                style: const TextStyle(
                  fontSize: AppText.fsCaption,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
