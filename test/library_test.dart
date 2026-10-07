import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/data/models/exercise.dart';
import 'package:exercises_app/state/library_controller.dart';

Exercise _ex(
  int i, {
  String? name,
  String? category,
  String? equipment,
  String? target,
}) =>
    Exercise.fromJson({
      'id': i.toString().padLeft(4, '0'),
      'name': name ?? '动作$i',
      'category': category ?? 'chest',
      'body_part': category ?? 'chest',
      'equipment': equipment ?? 'dumbbell',
      'instructions': {'zh': '整段说明'},
      'instruction_steps': {
        'zh': ['步骤一', '步骤二'],
      },
      'muscle_group': 'pectorals',
      'secondary_muscles': ['triceps'],
      'target': target ?? 'pectorals',
      'image': 'images/0000-test.webp',
      'gif_url': 'videos/0000-test.webp',
      'media_id': 'test$i',
      'created_at': '2026-03-18T12:31:32Z',
      'attribution': '© test',
    });

void main() {
  group('Exercise.fromJson', () {
    test('解析完整记录并生成 assets 路径', () {
      final ex = Exercise.fromJson(const {
        'id': '0001',
        'name': '四分之三仰卧起坐',
        'category': 'waist',
        'body_part': 'waist',
        'equipment': 'body weight',
        'instructions': {'zh': '整段说明'},
        'instruction_steps': {
          'zh': ['步骤一', '步骤二', '步骤三', '步骤四', '步骤五'],
        },
        'muscle_group': 'hip flexors',
        'secondary_muscles': ['hip flexors', 'lower back'],
        'target': 'abs',
        'image': 'images/0001-2gPfomN.webp',
        'gif_url': 'videos/0001-2gPfomN.webp',
        'media_id': '2gPfomN',
        'created_at': '2026-03-18T12:31:32Z',
        'attribution': '© Gym visual',
      });

      expect(ex.name, '四分之三仰卧起坐');
      expect(ex.displaySteps, hasLength(5));
      expect(ex.thumbnailAsset, 'assets/images/0001-2gPfomN.webp');
      expect(ex.animationAsset, 'assets/videos/0001-2gPfomN.webp');
      expect(ex.secondaryMusclesOnly, ['hip flexors', 'lower back']);
      expect(ex.searchIndex.contains('abs'), isTrue);
    });

    test('缺失字段回退为空值不抛异常', () {
      final ex = Exercise.fromJson(const {'id': '0002', 'name': 'x'});
      expect(ex.category, '');
      expect(ex.displaySteps, isEmpty);
      expect(ex.secondaryMuscles, isEmpty);
    });
  });

  group('LibraryController', () {
    test('筛选与取消筛选', () {
      final controller = LibraryController([
        _ex(1, category: 'chest', target: 'pectorals'),
        _ex(2, category: 'waist', target: 'abs'),
        _ex(3, category: 'chest', target: 'delts'),
      ]);

      expect(controller.filtered, hasLength(3));

      controller.toggleFilter(FilterKey.category, 'chest');
      expect(controller.filtered, hasLength(2));

      controller.toggleFilter(FilterKey.target, 'pectorals');
      expect(controller.filtered, hasLength(1));

      controller.clearAllFilters();
      expect(controller.filtered, hasLength(3));
    });

    test('搜索（防抖后生效）', () async {
      final controller = LibraryController([
        _ex(1, name: 'Barbell Curl', equipment: 'barbell'),
        _ex(2, name: '深蹲'),
      ]);

      controller.setSearch('barbell');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(controller.filtered, hasLength(1));
      expect(controller.filtered.first.name, 'Barbell Curl');

      controller.clearSearch();
      expect(controller.filtered, hasLength(2));
    });

    test('选中不改变候选值顺序（由高亮表达选择状态）', () {
      final controller = LibraryController([
        _ex(1, category: 'chest'),
        _ex(2, category: 'waist'),
        _ex(3, category: 'back'),
      ]);

      controller.toggleFilter(FilterKey.category, 'waist');
      // 分类维度按固定业务顺序（kCategoryDisplayOrder），选中不置顶
      expect(controller.orderedValues(FilterKey.category), [
        'chest',
        'back',
        'waist',
      ]);
    });

    test('分类按固定业务顺序，其余维度按全库数量降序', () {
      final controller = LibraryController([
        _ex(1, category: 'waist'),
        _ex(2, category: 'chest'),
        _ex(3, category: 'chest'),
        _ex(4, category: 'chest'),
        _ex(5, category: 'shoulders'),
        _ex(6, category: 'back'),
        _ex(7, category: 'back'),
      ]);

      // 分类维度：kCategoryDisplayOrder 顺序（chest → back → shoulders → waist）
      expect(controller.orderedValues(FilterKey.category), [
        'chest',
        'back',
        'shoulders',
        'waist',
      ]);
      // 总览卡片同一顺序
      expect(controller.categoryOrder, [
        'chest',
        'back',
        'shoulders',
        'waist',
      ]);

      // 器材维度（非分类）：数量降序、同数字母序
      final controller2 = LibraryController([
        _ex(1, equipment: 'dumbbell'),
        _ex(2, equipment: 'barbell'),
        _ex(3, equipment: 'barbell'),
      ]);
      expect(controller2.orderedValues(FilterKey.equipment), [
        'barbell', // 2
        'dumbbell', // 1
      ]);
    });

    test('facet 计数：其余维度筛选 + 搜索生效下的结果数', () {
      final controller = LibraryController([
        _ex(1, category: 'chest', equipment: 'barbell'),
        _ex(2, category: 'chest', equipment: 'dumbbell'),
        _ex(3, category: 'waist', equipment: 'barbell'),
      ]);

      // 无筛选时每个值的 facet 计数 = 全库计数
      expect(controller.countFor(FilterKey.category, 'chest'), 2);
      expect(controller.countFor(FilterKey.category, 'waist'), 1);
      expect(controller.countFor(FilterKey.equipment, 'barbell'), 2);
      expect(controller.countFor(FilterKey.equipment, 'dumbbell'), 1);

      // 选了 chest 后，equipment 的 facet 计数只在 chest 内统计
      controller.toggleFilter(FilterKey.category, 'chest');
      expect(controller.countFor(FilterKey.equipment, 'barbell'), 1);
      expect(controller.countFor(FilterKey.equipment, 'dumbbell'), 1);
      // 本维度忽略自身已选：腰腹仍显示 1（保持可多选叠加）
      expect(controller.countFor(FilterKey.category, 'waist'), 1);

      // 「忽略某维度」的计数：忽略 category 后总数回到 3
      expect(controller.countWithout(FilterKey.category), 3);
      // 忽略 equipment（未选）= 当前结果数
      expect(controller.countWithout(FilterKey.equipment), 2);
    });

    test('enterCategory：重置搜索与其他筛选，仅保留该分类', () async {
      final controller = LibraryController([
        _ex(1, category: 'chest', equipment: 'barbell', name: '卧推'),
        _ex(2, category: 'chest', equipment: 'dumbbell'),
        _ex(3, category: 'waist', equipment: 'barbell'),
      ]);

      controller.setSearch('卧推');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.toggleFilter(FilterKey.equipment, 'barbell');
      expect(controller.hasActiveFilters, isTrue);

      controller.enterCategory('waist');
      expect(controller.search, isEmpty);
      expect(controller.filtersOf(FilterKey.equipment), isEmpty);
      expect(controller.filtersOf(FilterKey.category), <String>{'waist'});
      expect(controller.currentCategory, 'waist');
      expect(controller.hasSingleCategory, isTrue);
      expect(controller.filtered, hasLength(1));
    });

    test('分类索引：数量 / 代表动作 / 分类内目标肌群降序', () {
      final controller = LibraryController([
        _ex(1, category: 'chest', target: 'pectorals'),
        _ex(2, category: 'chest', target: 'pectorals'),
        _ex(3, category: 'chest', target: 'serratus anterior'),
        _ex(4, category: 'waist', target: 'abs'),
      ]);

      expect(controller.categoryCounts, {'chest': 3, 'waist': 1});
      // 代表动作 = 数据顺序第一条
      expect(controller.categoryRepresentative['chest']!.id, '0001');
      expect(controller.categoryTargets['chest'], [
        'pectorals', // 2
        'serratus anterior', // 1
      ]);
      expect(controller.categoryTargets['waist'], ['abs']);
    });

    test('分页：默认60条，loadMore 追加剩余', () {
      final controller = LibraryController(List.generate(70, _ex));

      expect(controller.visibleExercises, hasLength(60));
      expect(controller.hasMore, isTrue);

      controller.loadMore();
      expect(controller.visibleExercises, hasLength(70));
      expect(controller.hasMore, isFalse);
    });
  });
}
