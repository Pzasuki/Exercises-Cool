import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../state/library_controller.dart';
import 'widgets/filter_panel.dart';
import 'widgets/results_view.dart';

/// 分类浏览页（两级浏览的二级）：宽屏「侧栏 + 结果视图」，
/// 窄屏「返回标题栏 + 可折叠面板（max-height 45vh）+ 结果视图」。
/// 从总览页带着分类筛选进入；结果条、目标肌群快捷行与网格见 ResultsView。
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const String _prefKeyCollapsed = 'sidebarCollapsed';

  final ScrollController _scrollController = ScrollController();

  /// 窄屏下顶部筛选面板是否展开（对应 .sidebar.collapsed 的折叠逻辑）。
  bool _panelOpen = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restorePanelState();
  }

  /// 恢复窄屏面板折叠状态（对应原版 localStorage['sidebarCollapsed']）。
  /// 原版写入 collapsed='1'、启动却检查 '0'，等于永远回到展开——这里按正确语义存取。
  Future<void> _restorePanelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _panelOpen = prefs.getString(_prefKeyCollapsed) != '1');
    } catch (_) {
      // 存储不可用（如测试环境未注册插件）时保持默认展开
    }
  }

  Future<void> _togglePanel() async {
    setState(() => _panelOpen = !_panelOpen);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyCollapsed, _panelOpen ? '0' : '1');
    } catch (_) {}
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

          // 移动布局：返回标题栏 + 可折叠筛选面板 + 内容区
          return Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, inner) => Column(
                  children: [
                    _NarrowHeader(
                      expanded: _panelOpen,
                      onToggle: _togglePanel,
                    ),
                    if (_panelOpen)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: inner.maxHeight * 0.45,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurface,
                          border: Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: const FilterPanel(),
                      ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 窄屏顶栏：返回总览 + 当前分类标题 + 筛选折叠按钮
/// （对应移动端 .sidebar-header 与 .sidebar-toggle-btn，按钮带已选数量徽章）。
class _NarrowHeader extends StatelessWidget {
  const _NarrowHeader({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final title = controller.hasSingleCategory
        ? zh(controller.currentCategory)
        : '全部动作';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
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
            splashRadius: 20,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _ToggleChip(
            count: controller.activeFilterCount,
            expanded: expanded,
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}

/// 「筛选」折叠按钮（.sidebar-toggle-btn）：文字 + 数量徽章 + 旋转箭头。
/// 收起时箭头转向右侧（对应 .sidebar.collapsed 的 chevron 旋转）。
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '筛选',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
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
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
