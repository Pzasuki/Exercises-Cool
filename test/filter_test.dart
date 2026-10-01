import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/features/library/widgets/filter_section.dart';
import 'package:exercises_app/features/library/widgets/filter_panel.dart';
import 'package:exercises_app/features/library/widgets/results_bar.dart';

import 'helpers.dart';

/// 筛选面板交互测试：真实数据驱动（总览页 → 浏览页 → 侧栏芯片）。
///
/// 注意：「胸部」等术语同时出现在侧栏芯片和卡片标签上，
/// 点击芯片时必须把 finder 限定在 [FilterPanel] 内；
/// 芯片文本带 facet 计数（如「胸部 163」），用 textContaining 匹配。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder sectionChip(String label) => find.descendant(
        of: find.byType(FilterSection),
        matching: find.textContaining(label),
      );

  testWidgets('宽屏：点击分类芯片后计数更新，再点取消恢复', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final chestCount = exercises.where((e) => e.category == 'chest').length;
    expect(chestCount, greaterThan(0));

    await pumpApp(tester, exercises);
    await enterBrowse(tester);
    expect(find.text('共 1324 个动作'), findsOneWidget);

    await tester.tap(panelChip('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('$chestCount / 1324 个动作'), findsOneWidget);

    // 选中分类后进入分类页形态：结果条不显示（徽章与标题重复），
    // 侧栏只剩器材；返回总览退出
    expect(find.byType(ResultsBar), findsNothing);
    await tester.tap(backButton());
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('全部动作'), findsOneWidget);
  });

  testWidgets('窄屏：筛选按钮出现已选数量徽章', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final chestCount = exercises.where((e) => e.category == 'chest').length;

    await pumpApp(tester, exercises);
    await enterBrowse(tester);
    expect(find.text('筛选'), findsOneWidget);

    // 窄屏分类芯片为单行横滑，「胸部」按固定业务顺序是首屏第一个芯片
    await tester.tap(panelChip('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 100));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('$chestCount / 1324 个动作'), findsOneWidget);
  });

  testWidgets('器材组默认折叠：长尾隐藏，「更多」展开后可见', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);

    // 收起态：只有 1 个动作的「轮胎」等长尾芯片不显示
    expect(sectionChip('轮胎'), findsNothing);
    expect(find.text('更多'), findsOneWidget);

    await tester.tap(find.text('更多'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(sectionChip('轮胎'), findsOneWidget);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(sectionChip('轮胎'), findsNothing);
    expect(find.text('更多'), findsOneWidget);
  });

  testWidgets('选中分类后其他维度 0 结果的芯片直接隐藏', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final chestCount = exercises.where((e) => e.category == 'chest').length;
    await pumpApp(tester, exercises);
    await enterBrowse(tester);

    await tester.tap(panelChip('胸部'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('$chestCount / 1324 个动作'), findsOneWidget);

    // 器材组只显示胸部下有动作的 16 种器材：椭圆机等 0 结果的不出现
    expect(find.textContaining('椭圆机'), findsNothing);

    // 展开「更多」后依旧只显示有结果的芯片（滚轮 2 可见，0 结果仍隐藏）
    await tester.tap(find.text('更多'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.textContaining('椭圆机'), findsNothing);
    expect(sectionChip('滚轮'), findsOneWidget);
  });
}
