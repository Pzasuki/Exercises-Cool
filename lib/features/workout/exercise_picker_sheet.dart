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

/// 搜索页签：默认按部位分类展示全库动作（类似主界面），
/// 搜索框可叠加检索（searchIndex），与动作库页面的筛选状态无关。
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
  String _query = '';

  /// 选中的部位分类，null = 全部。
  String? _category;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final q = _query.trim().toLowerCase();
    final results = library.allExercises
        .where(
          (e) =>
              (_category == null || e.category == _category) &&
              (q.isEmpty || e.searchIndex.contains(q)),
        )
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        // 部位分类 chips（与主界面同一套固定顺序 + 全库计数）
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            children: [
              _CategoryChip(
                label: '全部 ${library.totalCount}',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in library.categoryOrder) ...[
                const SizedBox(width: 6),
                _CategoryChip(
                  label: '${zh(c)} ${library.categoryCounts[c] ?? 0}',
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const _PickerHint(text: '未找到相关动作')
              : _PickerGrid(
                  exercises: results,
                  selected: widget.selected,
                  onToggle: widget.onToggle,
                ),
        ),
      ],
    );
  }
}

/// 2 列动作卡片网格（缩略图 + 名称 + 标签），点选打勾加入待添加。
class _PickerGrid extends StatelessWidget {
  const _PickerGrid({
    required this.exercises,
    required this.selected,
    required this.onToggle,
  });

  final List<Exercise> exercises;
  final Set<String> selected;
  final _SelectionCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
