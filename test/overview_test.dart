import 'package:flutter/material.dart' show Icons, Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/features/library/widgets/category_target_bar.dart';
import 'package:exercises_app/features/library/widgets/results_bar.dart';
import 'package:exercises_app/features/library/widgets/search_field.dart';

import 'helpers.dart';

/// 两级浏览测试：总览首页渲染 / 搜索切换结果视图 / 点分类进入浏览页 /
/// 目标肌群快捷行收窄（见 MIGRATION.md 阶段8）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder quickChip(String label) => find.descendant(
        of: find.byType(CategoryTargetBar),
        matching: find.textContaining(label),
      );

  testWidgets('总览页：部位卡片按数量降序，点卡片进入分类浏览', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final chestCount = exercises.where((e) => e.category == 'chest').length;

    await pumpApp(tester, exercises);
    // 卡片带数量（上臂 292 为最大分类）
    expect(find.text('上臂'), findsOneWidget);
    expect(find.text('292 个动作'), findsOneWidget);

    // 固定业务顺序：宽屏一行 4 张，第一行从左到右 胸部→背部→肩部→腰腹
    double dxOf(String label) =>
        tester.getTopLeft(find.text(label)).dx;
    expect(dxOf('胸部'), lessThan(dxOf('背部')));
    expect(dxOf('背部'), lessThan(dxOf('肩部')));
    expect(dxOf('肩部'), lessThan(dxOf('腰腹')));
    // 第二行起：上臂 → 大腿 → 前臂 → 小腿 → 颈部 → 有氧
    expect(tester.getTopLeft(find.text('上臂')).dy,
        greaterThan(tester.getTopLeft(find.text('胸部')).dy));
    expect(dxOf('上臂'), lessThan(dxOf('大腿')));

    // 点「胸部」卡片 → 浏览页带分类筛选
    await tester.tap(find.text('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('$chestCount / 1324 个动作'), findsOneWidget);

    // 返回总览
    await tester.tap(backButton());
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('全部动作'), findsOneWidget);
  });

  testWidgets('总览页搜索：切换为结果视图，清除后回到分类卡片', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final expected =
        exercises.where((e) => e.searchIndex.contains('深蹲')).length;

    await pumpApp(tester, exercises);
    expect(find.text('全部动作'), findsOneWidget);

    await tester.enterText(find.byType(SearchField), '深蹲');
    await pumpFor(tester, const Duration(milliseconds: 400));

    // 搜索生效：结果条出现，分类卡片隐藏
    expect(find.text('$expected / 1324 个动作'), findsOneWidget);
    expect(find.text('全部动作'), findsNothing);

    // 点搜索框 × 清除 → 回到总览
    await tester.tap(
      find.descendant(
        of: find.byType(SearchField),
        matching: find.byIcon(Icons.close),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('全部动作'), findsOneWidget);
  });

  testWidgets('分类页目标肌群快捷行：点击收窄，「全部」恢复', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));

    // 进入胸部分类（含 2 个目标肌群：胸大肌 158 / 前锯肌 5）
    await tester.tap(find.text('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(quickChip('全部 163'), findsOneWidget);
    expect(quickChip('胸大肌 158'), findsOneWidget);

    await tester.tap(quickChip('胸大肌'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('158 / 1324 个动作'), findsOneWidget);

    // 点「全部」恢复到分类全量
    await tester.tap(quickChip('全部'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('163 / 1324 个动作'), findsOneWidget);
  });

  testWidgets('单肌群分类不显示快捷行', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));

    // 腰腹只有腹肌一个目标肌群，快捷行应隐藏（无「全部」芯片）
    await tester.tap(find.text('腰腹'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('169 / 1324 个动作'), findsOneWidget);
    expect(quickChip('全部'), findsNothing);
  });

  testWidgets('分类页侧栏只留器材、无结果条；回全部动作后三组恢复', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final chestCount = exercises.where((e) => e.category == 'chest').length;
    await pumpApp(tester, exercises);

    await tester.tap(find.text('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    // 分类页形态：分类/目标肌肉组隐藏（分别由总览页与快捷行承担），只留器材；
    // 结果条不显示，计数由状态行承担
    expect(find.text('分类'), findsNothing);
    expect(find.text('目标肌肉'), findsNothing);
    expect(find.text('器材'), findsOneWidget);
    expect(find.byType(ResultsBar), findsNothing);
    expect(find.text('$chestCount / 1324 个动作'), findsOneWidget);

    // 返回总览，再进「全部动作」→ 三组与结果条恢复
    await tester.tap(backButton());
    await pumpFor(tester, const Duration(milliseconds: 300));
    await enterBrowse(tester);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('器材'), findsOneWidget);
    expect(find.text('目标肌肉'), findsOneWidget);
    expect(find.byType(ResultsBar), findsOneWidget);
  });

  testWidgets('窄屏分类页：标题栏显示分类名与返回键', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await tester.tap(find.text('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    // 分类页形态：快捷行出现（胸部含 2 个肌群）
    expect(quickChip('全部 163'), findsOneWidget);
    await tester.tap(backButton());
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('全部动作'), findsOneWidget); // 回到总览
  });
}
