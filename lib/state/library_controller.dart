import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../data/models/exercise.dart';

/// 筛选维度，对应 JS `state.filters` 的三个 Set。
enum FilterKey { category, equipment, target }

/// 分类的固定展示顺序（业务指定：胸 → 背 → 肩 → 腰腹 → 上臂 → 大腿 →
/// 前臂 → 小腿 → 颈 → 有氧），总览卡片与分类芯片共用；数据里出现
/// 未知分类时排在最后。
const List<String> kCategoryDisplayOrder = [
  'chest',
  'back',
  'shoulders',
  'waist',
  'upper arms',
  'upper legs',
  'lower arms',
  'lower legs',
  'neck',
  'cardio',
];

int _categoryRank(String category) {
  final index = kCategoryDisplayOrder.indexOf(category);
  return index == -1 ? kCategoryDisplayOrder.length : index;
}

/// 动作库状态：搜索、筛选、分页，以及两级浏览（分类总览 → 分类内浏览）。
/// 对应 index.html 的 state / applyFilters / appendNextPage，
/// 分类入口等新增能力见 MIGRATION.md 阶段8。
class LibraryController extends ChangeNotifier {
  LibraryController(List<Exercise> exercises)
      : _exercises = List.unmodifiable(exercises) {
    _buildFilterValues();
    _buildCategoryIndex();
    _applyFilters(notify: false);
  }

  final List<Exercise> _exercises;
  Timer? _debounce;

  /// 搜索框原文（未 trim）：供输入框回显同步，避免打字途中的尾随空格被回写。
  /// 筛选匹配与「是否处于搜索态」判定一律走 [activeQuery]。
  String _search = '';
  final Set<String> _categoryFilter = {};
  final Set<String> _equipmentFilter = {};
  final Set<String> _targetFilter = {};

  List<Exercise> _filtered = const [];
  int _visibleCount = kPageSize;

  /// 三个维度下所有可选值（已选置顶，其余按全量数量降序），对应 JS `filterValuesCache`。
  final Map<FilterKey, List<String>> filterValues = {};

  /// 各维度值的静态总量（全库计数），用于芯片的稳定排序。
  final Map<FilterKey, Map<String, int>> _valueTotals = {};

  /// 当前筛选下各维度值的 facet 计数（其余维度筛选 + 搜索生效时的结果数），
  /// 每次筛选变化重建；芯片计数与 0 结果置灰都以此为准。
  final Map<FilterKey, Map<String, int>> facetCounts = {};

  /// 分类 → 全库数量（总览卡片用）。
  late final Map<String, int> categoryCounts;

  /// 分类 → 代表动作（数据顺序第一条，总览卡片配图用）。
  late final Map<String, Exercise> categoryRepresentative;

  /// 分类 → 该分类下的目标肌群（按全量数量降序），分类页快捷行用。
  late final Map<String, List<String>> categoryTargets;

  /// id → 动作（收藏夹/训练清单按 id 引用动作，展示时反查）。
  late final Map<String, Exercise> exerciseById;

  /// 器材 → 全库数量 / 代表动作（挑动作总览的器材卡片用）。
  late final Map<String, int> equipmentCounts;
  late final Map<String, Exercise> equipmentRepresentative;

  /// 按 id 查动作；不存在（数据更新后被移除）时返回 null。
  Exercise? byId(String id) => exerciseById[id];

  /// 总览页分类卡片的展示顺序（固定业务顺序，见 [kCategoryDisplayOrder]）。
  late final List<String> categoryOrder;

  List<Exercise> get filtered => _filtered;

  /// 全库动作（只读）。训练挑动作等场景直接检索全库，不走页面筛选。
  List<Exercise> get allExercises => _exercises;

  /// 当前应展示的条目（无限滚动分页窗口）。
  List<Exercise> get visibleExercises =>
      _filtered.take(_visibleCount).toList(growable: false);

  bool get hasMore => _visibleCount < _filtered.length;
  int get totalCount => _exercises.length;

  /// 搜索框原文（未 trim，输入框回显同步用）。
  String get search => _search;

  /// 生效搜索词（trim 后）：筛选匹配与搜索态判定都以此为准，
  /// 纯空白输入不构成搜索。
  String get activeQuery => _search.trim();

  bool get hasActiveFilters =>
      _categoryFilter.isNotEmpty ||
      _equipmentFilter.isNotEmpty ||
      _targetFilter.isNotEmpty ||
      activeQuery.isNotEmpty;

  /// 已选筛选条件总数（不含搜索，对应窄屏按钮上的 #sidebar-toggle-count）。
  int get activeFilterCount =>
      _categoryFilter.length + _equipmentFilter.length + _targetFilter.length;

  /// 当前恰好选中一个分类（分类页形态：显示标题与目标肌群快捷行）。
  bool get hasSingleCategory => _categoryFilter.length == 1;

  /// 单一分类模式下选中的分类名；否则为空串。
  String get currentCategory =>
      hasSingleCategory ? _categoryFilter.first : '';

  Set<String> filtersOf(FilterKey key) => switch (key) {
        FilterKey.category => _categoryFilter,
        FilterKey.equipment => _equipmentFilter,
        FilterKey.target => _targetFilter,
      };

  /// 搜索输入（内部防抖，对应 wireEvents 里的 debounce 250ms）。
  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(kSearchDebounce, () {
      _search = value;
      _applyFilters();
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    _search = '';
    _applyFilters();
  }

  void toggleFilter(FilterKey key, String value) {
    final set = filtersOf(key);
    if (set.contains(value)) {
      set.remove(value);
    } else {
      set.add(value);
    }
    _applyFilters();
  }

  /// 清空某一维度的全部已选（目标肌群快捷行的「全部」芯片）。
  void clearFilter(FilterKey key) {
    filtersOf(key).clear();
    _applyFilters();
  }

  /// 从总览页进入某分类：重置搜索与其他筛选，仅保留该分类，
  /// 保证每次从首页进入都是干净的浏览状态。
  void enterCategory(String category) {
    _debounce?.cancel();
    _search = '';
    _categoryFilter
      ..clear()
      ..add(category);
    _equipmentFilter.clear();
    _targetFilter.clear();
    _applyFilters();
  }

  /// 从浏览页返回总览页（LibraryScreen 的 PopScope 回调）：
  /// 清除搜索并清掉分类残留——分类不清会让主页搜索被残留分类隐性过滤，
  /// 而结果条又被 hasSingleCategory 隐藏，用户看不到任何提示。
  /// 器材/目标筛选保留：回主页搜索时它们会以徽章形式可见地生效。
  void returnToOverview() {
    _debounce?.cancel();
    _search = '';
    _categoryFilter.clear();
    _applyFilters();
  }

  /// 清空搜索与全部筛选（对应 clearAllFilters）。
  void clearAllFilters() {
    _debounce?.cancel();
    _search = '';
    _categoryFilter.clear();
    _equipmentFilter.clear();
    _targetFilter.clear();
    _applyFilters();
  }

  /// 无限滚动：加载下一页（对应 appendNextPage）。
  void loadMore() {
    if (!hasMore) return;
    _visibleCount += kPageSize;
    notifyListeners();
  }

  /// 已选中的值排到最前面，其余按全库数量降序、同数按字母序
  /// （常用值稳定地排在前面对应 orderedValues）。
  List<String> orderedValues(FilterKey key) {
    final selected = filtersOf(key);
    final all = filterValues[key] ?? const <String>[];
    return [
      ...all.where(selected.contains),
      ...all.where((v) => !selected.contains(v)),
    ];
  }

  /// 当前筛选（除 [key] 维度外）下某值的 facet 计数，即点选它会得到的结果数。
  int countFor(FilterKey key, String value) =>
      facetCounts[key]?[value] ?? 0;

  /// 忽略 [key] 维度筛选后的结果数（快捷行的「全部」芯片计数）。
  int countWithout(FilterKey key) {
    final q = activeQuery.toLowerCase();
    var count = 0;
    for (final e in _exercises) {
      if (_matches(e, q, except: key)) count++;
    }
    return count;
  }

  void _buildFilterValues() {
    for (final key in FilterKey.values) {
      final counts = <String, int>{};
      for (final e in _exercises) {
        final value = _fieldOf(e, key);
        counts[value] = (counts[value] ?? 0) + 1;
      }
      _valueTotals[key] = counts;
      filterValues[key] = counts.keys.toList()
        ..sort((a, b) {
          // 分类维度按固定业务顺序，其余维度按全库数量降序、同数字母序
          if (key == FilterKey.category) {
            final byRank = _categoryRank(a).compareTo(_categoryRank(b));
            if (byRank != 0) return byRank;
          }
          final byCount = counts[b]!.compareTo(counts[a]!);
          return byCount != 0 ? byCount : a.compareTo(b);
        });
    }
  }

  void _buildCategoryIndex() {
    final counts = <String, int>{};
    final representatives = <String, Exercise>{};
    final targetCounts = <String, Map<String, int>>{};
    for (final e in _exercises) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
      representatives.putIfAbsent(e.category, () => e);
      final targets =
          targetCounts.putIfAbsent(e.category, () => {});
      targets[e.target] = (targets[e.target] ?? 0) + 1;
    }
    categoryCounts = Map.unmodifiable(counts);
    categoryRepresentative = Map.unmodifiable(representatives);
    exerciseById = Map.unmodifiable({
      for (final e in _exercises) e.id: e,
    });

    // 器材索引（挑动作弹层的一级分类）
    final equipCounts = <String, int>{};
    final equipReps = <String, Exercise>{};
    for (final e in _exercises) {
      equipCounts[e.equipment] = (equipCounts[e.equipment] ?? 0) + 1;
      equipReps.putIfAbsent(e.equipment, () => e);
    }
    equipmentCounts = Map.unmodifiable(equipCounts);
    equipmentRepresentative = Map.unmodifiable(equipReps);
    categoryOrder = (counts.keys.toList()
          ..sort((a, b) {
            final byRank = _categoryRank(a).compareTo(_categoryRank(b));
            return byRank != 0 ? byRank : a.compareTo(b);
          }))
        .toList(growable: false);
    categoryTargets = Map.unmodifiable({
      for (final entry in targetCounts.entries)
        entry.key: entry.value.keys.toList()
          ..sort((a, b) {
            final byCount =
                entry.value[b]!.compareTo(entry.value[a]!);
            return byCount != 0 ? byCount : a.compareTo(b);
          }),
    });
  }

  static String _fieldOf(Exercise e, FilterKey key) => switch (key) {
        FilterKey.category => e.category,
        FilterKey.equipment => e.equipment,
        FilterKey.target => e.target,
      };

  /// [except] 用于 facet 计数：忽略该维度的已选条件。
  bool _matches(Exercise e, String q, {FilterKey? except}) {
    if (q.isNotEmpty && !e.searchIndex.contains(q)) return false;
    for (final key in FilterKey.values) {
      if (key == except) continue;
      final set = filtersOf(key);
      if (set.isNotEmpty && !set.contains(_fieldOf(e, key))) {
        return false;
      }
    }
    return true;
  }

  void _applyFilters({bool notify = true}) {
    final q = activeQuery.toLowerCase();
    _filtered = _exercises
        .where((e) => _matches(e, q))
        .toList(growable: false);
    _visibleCount = kPageSize;
    _recomputeFacetCounts(q);
    if (notify) notifyListeners();
  }

  void _recomputeFacetCounts(String q) {
    for (final key in FilterKey.values) {
      final counts = <String, int>{};
      for (final e in _exercises) {
        if (!_matches(e, q, except: key)) continue;
        final value = _fieldOf(e, key);
        counts[value] = (counts[value] ?? 0) + 1;
      }
      facetCounts[key] = counts;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
