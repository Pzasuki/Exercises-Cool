import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/exercise.dart';
import '../../state/library_controller.dart';
import '../library/library_screen.dart';
import '../library/widgets/app_logo.dart';
import '../library/widgets/results_view.dart';
import '../library/widgets/search_field.dart';

/// 分类总览首页（两级浏览的一级）：
/// 顶栏 logo + 搜索，「全部动作」入口 + 部位卡片网格（名称 + 数量 + 代表图）。
/// 搜索激活（防抖生效）时正文切换为共用结果视图；点部位卡片进入
/// [LibraryScreen] 分类浏览（见 MIGRATION.md 阶段8）。
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
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

  void _onScroll() {
    if (_scrollController.position.extentAfter < 600) {
      context.read<LibraryController>().loadMore();
    }
  }

  void _openBrowse() {
    // 进入浏览页前释放搜索焦点：浏览页工具栏有自己的搜索框，
    // 焦点不释放会让输入法跟着路由进新页面
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    // 搜索态判定用 trim 后的生效词：纯空白输入不切换到结果视图
    final searching = controller.activeQuery.isNotEmpty;

    // 主页搜索态按系统返回：清除搜索回到分类总览，而不是退出应用；
    // 非搜索态不拦截，再次返回走系统默认行为（退出应用）。
    return PopScope(
      canPop: !searching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.read<LibraryController>().clearSearch();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: searching
                    ? ResultsView(scrollController: _scrollController)
                    : _CategoryOverview(onOpenAll: _openBrowse),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶栏：logo + 搜索框（搜索时保留在顶部，可继续编辑或清空回总览）。
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;
    return Container(
      padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 10, isNarrow ? 14 : 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          AppLogo(),
          SizedBox(width: 12),
          Expanded(child: SearchField()),
        ],
      ),
    );
  }
}

/// 部位总览：「全部动作」横幅 + 分类卡片网格。
class _CategoryOverview extends StatelessWidget {
  const _CategoryOverview({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    final isNarrow = MediaQuery.sizeOf(context).width < kNarrowBreakpoint;
    final isCompact = MediaQuery.sizeOf(context).width <= 480;

    // 固定业务顺序（胸→背→肩→腰腹→…），见 kCategoryDisplayOrder
    final categories = controller.categoryOrder;

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final EdgeInsets gridPadding = isCompact
        ? EdgeInsets.fromLTRB(10, 10, 10, 24 + bottomInset)
        : EdgeInsets.fromLTRB(
            isNarrow ? 12 : 20, 12, isNarrow ? 12 : 20, 24 + bottomInset);
    final SliverGridDelegate delegate = isCompact
        ? const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
          )
        : SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          );

    return Column(
      children: [
        Padding(
          padding: gridPadding.copyWith(bottom: 0),
          child: _AllExercisesCard(count: controller.totalCount, onTap: () {
            context.read<LibraryController>().clearAllFilters();
            onOpenAll();
          }),
        ),
        // 分区标签：与网格同一 max-width 居中，宽窄屏都对齐网格左缘
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kOverviewMaxWidth),
            child: Padding(
              padding: gridPadding.copyWith(top: 14, bottom: 6),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('按部位浏览', style: AppText.sectionTitle),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kOverviewMaxWidth),
              child: GridView.builder(
                padding: gridPadding,
                gridDelegate: delegate,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryCard(
                    category: category,
                    count: controller.categoryCounts[category]!,
                    representative:
                        controller.categoryRepresentative[category],
                    onTap: () {
                      context
                          .read<LibraryController>()
                          .enterCategory(category);
                      onOpenAll();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 「全部动作」入口卡：进入不带分类筛选的浏览页。
class _AllExercisesCard extends StatelessWidget {
  const _AllExercisesCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentMuted,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(color: AppColors.accent),
          ),
          child: Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              const Text(
                '全部动作',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$count 个动作',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 部位卡片：代表图 + 名称 + 数量。悬停上浮样式与动作卡片一致。
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.representative,
    required this.onTap,
  });

  final String category;
  final int count;
  final Exercise? representative;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final rep = widget.representative;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            boxShadow: _hovering
                ? const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          // 边框画在子组件之上：否则铺满的图片会盖住边框，四角只剩残缺弧线。
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: _hovering ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: rep == null
                    ? const ColoredBox(color: AppColors.bgElevated)
                    : Image.asset(
                        rep.thumbnailAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.bgElevated),
                      ),
              ),
              Container(
                color: AppColors.bgSurface,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zh(widget.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppText.fsBodySm,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.count} 个动作',
                      style: const TextStyle(
                        fontSize: AppText.fsMicro,
                        color: AppColors.textSecondary,
                      ),
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
