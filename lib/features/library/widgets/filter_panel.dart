import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../state/library_controller.dart';
import 'app_logo.dart';
import 'filter_section.dart';
import 'search_field.dart';

/// 侧栏筛选面板，对应 .sidebar（logo + 搜索框 + 筛选芯片组）。
/// 宽屏显示返回按钮 + logo、芯片自动换行；窄屏顶栏已带返回与标题，
/// 芯片变单行横向滚动。
/// 分区按浏览形态分流（见 MIGRATION.md 阶段8）：从总览进入具体分类后
/// 只保留「器材」——分类切换属于总览页的职责，目标肌肉由页面顶部的
/// 快捷行承担；「全部动作」视图无快捷行，三组分区齐全。
/// 器材组默认收起只显示前 8 个有结果的值（长尾降噪）。
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;
    final categoryMode = context.watch<LibraryController>().hasSingleCategory;
    return Material(
      color: AppColors.bgSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isNarrow) ...[
              Row(
                children: [
                  const _BackButton(),
                  const SizedBox(width: 6),
                  const AppLogo(),
                ],
              ),
              const SizedBox(height: 14),
            ],
            const SearchField(),
            const SizedBox(height: 16),
            if (!categoryMode) ...[
              FilterSection(
                title: '分类',
                filterKey: FilterKey.category,
                horizontal: isNarrow,
              ),
              const SizedBox(height: 14),
            ],
            FilterSection(
              title: '器材',
              filterKey: FilterKey.equipment,
              horizontal: isNarrow,
              initialLimit: 8,
            ),
            if (!categoryMode) ...[
              const SizedBox(height: 14),
              FilterSection(
                title: '目标肌肉',
                filterKey: FilterKey.target,
                horizontal: isNarrow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 返回总览页（宽屏侧栏顶部；窄屏由页面顶栏的返回键承担）。
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}
