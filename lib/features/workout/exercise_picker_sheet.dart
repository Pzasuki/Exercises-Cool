import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/exercise.dart';
import '../../state/favorites_service.dart';
import '../../state/library_controller.dart';

/// 训练挑动作弹层：「收藏」与「搜索动作库」两个页签，均为卡片网格，
/// 多选打勾后由底部「添加 N 个动作」批量带回。
Future<List<String>?> showExercisePicker(BuildContext context) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (context) => const _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  int _tab = 0;
  final Set<String> _selected = {};

  void _toggle(String exerciseId) {
    setState(() {
      if (!_selected.remove(exerciseId)) _selected.add(exerciseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 不用 TabBarView：底部弹层内嵌 PageView 的手势竞技场在部分嵌套场景下
    // 会与列表点击互相干扰（点按不响应），这里用分段按钮直接切换内容。
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('收藏')),
                ButtonSegment(value: 1, label: Text('搜索动作库')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: AppColors.accent,
                selectedBackgroundColor: AppColors.accentMuted,
              ),
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Flexible(
            child: _tab == 0
                ? _FavoritePickerTab(
                    selected: _selected,
                    onToggle: _toggle,
                  )
                : _SearchPickerTab(
                    selected: _selected,
                    onToggle: _toggle,
                  ),
          ),
          // 底部批量添加
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.border,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(
                _selected.isEmpty ? '选择要添加的动作' : '添加 ${_selected.length} 个动作',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 选中的动作 id 集合与切换回调，两个页签共享。
typedef _SelectionCallback = void Function(String exerciseId);

/// 收藏页签：横滑选择收藏夹，夹内动作以卡片网格展示。
class _FavoritePickerTab extends StatelessWidget {
  const _FavoritePickerTab({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final _SelectionCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FavoritesService>();
    final library = context.watch<LibraryController>();
    final folders =
        service.folders.where((f) => f.exerciseIds.isNotEmpty).toList();
    if (folders.isEmpty) {
      return const _PickerHint(text: '还没有收藏动作\n去动作库打开动作详情，点收藏试试');
    }
    final folderId = folders.first.id;
    final exercises = [
      for (final id in service.folders
          .where((f) => f.id == folderId)
          .expand((f) => f.exerciseIds))
        ?library.byId(id),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final folder in folders)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${folder.name} ${folder.exerciseIds.length}'),
                    selected: folder.id == folderId,
                    onSelected: (_) {},
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: folder.id == folderId
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    selectedColor: AppColors.accentMuted,
                    side: BorderSide(
                      color: folder.id == folderId
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: exercises.isEmpty
              ? const _PickerHint(text: '这个收藏夹还没有动作')
              : _PickerGrid(
                  exercises: exercises,
                  selected: selected,
                  onToggle: onToggle,
                ),
        ),
      ],
    );
  }
}

/// 搜索动作库页签：两级结构，按**器材**分类——
/// 一级：器材卡片总览（含代表图与数量，徒手/哑铃/拉索/杠铃…）；
/// 二级：该器材内按**部位**分组的模块（胸部/背部/…）。
/// 搜索框在两级都可用：总览级搜全库，器材级只搜该器材。
class _SearchPickerTab extends StatefulWidget {
  const _SearchPickerTab({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final _SelectionCallback onToggle;

  @override
  State<_SearchPickerTab> createState() => _SearchPickerTabState();
}

class _SearchPickerTabState extends State<_SearchPickerTab> {
  /// 选中的器材分类，null = 器材总览。
  String? _equipment;

  /// 部位筛选（chips 行），null = 全部部位；两级通用。
  String? _categoryFilter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final q = _query.trim().toLowerCase();

    // 当前层级的动作全集：总览 = 全库，器材级 = 该器材
    final all = _equipment == null
        ? library.allExercises
        : [
            for (final e in library.allExercises)
              if (e.equipment == _equipment) e,
          ];
    // 部位筛选叠加（全部 = 不过滤）
    final scoped = _categoryFilter == null
        ? all
        : [
            for (final e in all)
              if (e.category == _categoryFilter) e,
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_equipment != null)
          _CategoryHeader(
            name: zh(_equipment!),
            count: scoped.length,
            onBack: () => setState(() {
              _equipment = null;
              _query = '';
            }),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            key: const Key('exercisePickerSearch'),
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '搜索动作…',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
        // 部位筛选 chips（两级通用；0 结果的芯片隐藏，已选中的保留）
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            children: [
              _CategoryChip(
                label: '全部 ${all.length}',
                selected: _categoryFilter == null,
                onTap: () => setState(() => _categoryFilter = null),
              ),
              for (final cat in library.categoryOrder)
                if (_categoryFilter == cat ||
                    all.any((e) => e.category == cat)) ...[
                  const SizedBox(width: 6),
                  _CategoryChip(
                    label:
                        '${zh(cat)} ${all.where((e) => e.category == cat).length}',
                    selected: _categoryFilter == cat,
                    onTap: () => setState(() => _categoryFilter = cat),
                  ),
                ],
            ],
          ),
        ),
        Flexible(child: _buildContent(library, q, scoped)),
      ],
    );
  }

  Widget _buildContent(
      LibraryController library, String q, List<Exercise> scoped) {
    // 搜索优先：有输入时直接展示结果网格（忽略器材分组）
    if (q.isNotEmpty) {
      final results = scoped
          .where((e) => e.searchIndex.contains(q))
          .toList(growable: false);
      return results.isEmpty
          ? const _PickerHint(text: '未找到相关动作')
          : _PickerGrid(
              exercises: results,
              selected: widget.selected,
              onToggle: widget.onToggle,
            );
    }

    // 一级：器材卡片总览（部位筛选后数量为该部位范围内的，0 结果的器材隐藏）
    if (_equipment == null) {
      final equipmentList =
          library.filterValues[FilterKey.equipment] ?? const <String>[];
      final visibleEquipment = [
        for (final eq in equipmentList)
          if (scoped.where((e) => e.equipment == eq) case final list
              when list.isNotEmpty)
            (eq, list.length),
      ];
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: visibleEquipment.length,
        itemBuilder: (context, index) {
          final (eq, count) = visibleEquipment[index];
          return _PickerCategoryCard(
            category: eq,
            count: count,
            representative: library.equipmentRepresentative[eq],
            onTap: () => setState(() {
              _equipment = eq;
              _query = '';
            }),
          );
        },
      );
    }

    // 二级：按部位分组的模块（固定业务顺序；部位筛选后只剩选中的组）
    final sections = <(String, List<Exercise>)>[];
    for (final cat in library.categoryOrder) {
      final list =
          scoped.where((e) => e.category == cat).toList(growable: false);
      if (list.isNotEmpty) sections.add((cat, list));
    }
    if (sections.isEmpty) return const _PickerHint(text: '未找到相关动作');

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final (eq, list) in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              '${zh(eq)} ${list.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _PickerGrid(
            exercises: list,
            selected: widget.selected,
            onToggle: widget.onToggle,
            shrinkWrap: true,
          ),
        ],
      ],
    );
  }
}

/// 二级页头部：返回 + 部位名 + 数量。
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.name,
    required this.count,
    required this.onBack,
  });

  final String name;
  final int count;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '$name · $count 个动作',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 部位卡片（类似主页总览）：代表图 + 名称 + 数量。
class _PickerCategoryCard extends StatelessWidget {
  const _PickerCategoryCard({
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
  Widget build(BuildContext context) {
    final rep = representative;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.border),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    zh(category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count 个动作',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
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

/// 2 列动作卡片网格（缩略图 + 名称 + 标签），点选打勾加入待添加。
class _PickerGrid extends StatelessWidget {
  const _PickerGrid({
    required this.exercises,
    required this.selected,
    required this.onToggle,
    this.shrinkWrap = false,
  });

  final List<Exercise> exercises;
  final Set<String> selected;
  final _SelectionCallback onToggle;

  /// true = 嵌入外层滚动（器材分组模块），自身不滚动。
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 0, 12, shrinkWrap ? 8 : 8),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        return _PickCard(
          exercise: ex,
          selected: selected.contains(ex.id),
          onTap: () => onToggle(ex.id),
        );
      },
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  final Exercise exercise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        // 边框画在子组件之上，避免图片盖住四角弧线
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    ex.thumbnailAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.bgElevated),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 15, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ex.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${zh(ex.target)} · ${zh(ex.equipment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
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

/// 部位筛选芯片（与主页筛选一致的胶囊样式）。
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? AppColors.accent : AppColors.textSecondary,
      ),
      selectedColor: AppColors.accentMuted,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PickerHint extends StatelessWidget {
  const _PickerHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
