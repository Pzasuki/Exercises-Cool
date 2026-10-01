import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/zh_terms.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/library_controller.dart';

/// 筛选分区（.filter-section）：标题 + 带计数的芯片组。
/// 数据源为 [LibraryController.orderedValues]——已选中的芯片自动排到最前，
/// 其余按全库数量降序；芯片计数为当前 facet 计数（点选后会得到的结果数），
/// 0 结果的芯片直接不显示（已选中的除外，保证可以取消）。
/// 宽屏芯片自动换行；窄屏单行横向滚动（对应 @media 768 的 .filter-options）。
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

  /// 窄屏模式下芯片排成单行横向滚动（滚动条隐藏）。
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
          count: controller.countFor(widget.filterKey, value),
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
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
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

/// 筛选芯片（.chip / .chip.active）：胶囊形，选中为主题色，
/// 悬停时边框加深、文字变主色；带 facet 计数。
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
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
        color: active ? AppColors.accentMuted : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active
                ? AppColors.accent
                : (_hover ? AppColors.borderHover : AppColors.border),
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              '${widget.label} ${widget.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppColors.accent
                    : (_hover
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
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
      color: Colors.transparent,
      shape: StadiumBorder(side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expanded ? '收起' : '更多',
                style: const TextStyle(
                  fontSize: 12,
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
