import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../state/library_controller.dart';
import 'widgets/filter_panel.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/results_view.dart';
import 'widgets/search_field.dart';

/// 分类浏览页（两级浏览的二级）：宽屏「侧栏 + 结果视图」，
/// 窄屏「返回 + 搜索 + 筛选按钮」工具栏 + 结果视图——筛选收进
/// 底部弹层（[showFilterSheet]），网格占满全屏；已选条件由结果条
/// （ResultsBar 窄屏单行形态）承担。从总览页带着分类筛选进入。
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 无限滚动：接近底部时加载下一页
  /// （对应 IntersectionObserver rootMargin 200px 的 sentinel）。
  void _onScroll() {
    if (_scrollController.position.extentAfter < 600) {
      context.read<LibraryController>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 返回主页时清除搜索并清掉分类残留（controller.returnToOverview）：
    // 分类不清会让主页搜索被残留分类隐性过滤；主页回到分类总览而非搜索
    // 结果。搜索态收起键盘由系统返回默认行为完成，本页内不清内容。
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) context.read<LibraryController>().returnToOverview();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= kNarrowBreakpoint;
          final content = ResultsView(scrollController: _scrollController);

          if (isWide) {
            // 桌面布局：固定宽度侧栏 + 内容区（.app-shell grid）
            return Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: kSidebarWidth, child: FilterPanel()),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: content),
                ],
              ),
            );
          }

          // 移动布局：工具栏（返回 + 搜索 + 筛选入口）+ 结果视图
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _NarrowHeader(onOpenFilter: () => showFilterSheet(context)),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 窄屏工具栏：返回总览 + 搜索框 + 筛选按钮（带已选数量徽章）。
class _NarrowHeader extends StatelessWidget {
  const _NarrowHeader({required this.onOpenFilter});

  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    final filterCount = context.select<LibraryController, int>(
      (c) => c.activeFilterCount,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const Expanded(child: SearchField()),
          const SizedBox(width: 8),
          _FilterButton(count: filterCount, onTap: onOpenFilter),
        ],
      ),
    );
  }
}

/// 「筛选」入口：图标 + 文字 + 已选数量徽章（无选中时徽章隐藏）。
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? AppColors.accentMuted : AppColors.bgElevated,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.accent : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '筛选',
                style: TextStyle(
                  fontSize: AppText.fsCaption,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
