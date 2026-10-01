import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/core/theme/app_colors.dart';
import 'package:exercises_app/features/library/widgets/filter_panel.dart';
import 'package:exercises_app/features/library/widgets/results_bar.dart';
import 'package:exercises_app/features/library/widgets/results_view.dart';

import 'helpers.dart';

/// 阶段5 交互细节测试：结果条徽章 / 清除全部 / 卡片悬停动图 / 窄屏两列网格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('结果条：点芯片出现徽章与「清除全部」，× 移除单个条件', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);
    expect(find.text('清除全部'), findsNothing);

    // 用器材芯片（分类芯片选中后会进入分类页形态，结果条随之隐藏）
    await tester.tap(panelChip('哑铃'));
    await pumpFor(tester, const Duration(milliseconds: 100));

    expect(find.text('清除全部'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ResultsBar), matching: find.text('哑铃')),
      findsOneWidget,
    );

    // 点徽章上的 × 移除
    await tester.tap(
      find.descendant(
        of: find.byType(ResultsBar),
        matching: find.byIcon(Icons.close),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('清除全部'), findsNothing);
    expect(find.text('共 1324 个动作'), findsOneWidget);
  });

  testWidgets('清除全部：筛选与搜索框一起清空', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    await pumpApp(tester, exercises);
    await enterBrowse(tester);

    // 搜索（防抖后生效）+ 选中器材（保持「全部动作」视图，结果条可见）
    await tester.enterText(
      find.descendant(of: find.byType(FilterPanel), matching: find.byType(TextField)),
      '深蹲',
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(panelChip('哑铃'));
    await pumpFor(tester, const Duration(milliseconds: 100));

    final expected = exercises
        .where(
          (e) => e.equipment == 'dumbbell' && e.searchIndex.contains('深蹲'),
        )
        .length;
    expect(find.text('$expected / 1324 个动作'), findsOneWidget);

    await tester.tap(find.text('清除全部'));
    await pumpFor(tester, const Duration(milliseconds: 100));

    expect(find.text('共 1324 个动作'), findsOneWidget);
    // 输入框同步清空（对应原版 searchEl.value = ''）
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '');
  });

  testWidgets('卡片悬停：静图淡出、动图淡入，移开后还原', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const thumbAsset = 'assets/images/0001-2gPfomN.webp';
    const animAsset = 'assets/videos/0001-2gPfomN.webp';

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);
    expect(countImagesByAsset(tester, animAsset), 0);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text('四分之三仰卧起坐')));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(countImagesByAsset(tester, animAsset), 1);
    expect(countImagesByAsset(tester, thumbAsset), 0);

    // 移开鼠标（悬停侧栏空白处）
    await gesture.moveTo(const Offset(10, 60));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(countImagesByAsset(tester, animAsset), 0);
    expect(countImagesByAsset(tester, thumbAsset), 1);
  });

  testWidgets('长按卡片：动图预览，松开还原且不打开详情', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const thumbAsset = 'assets/images/0001-2gPfomN.webp';
    const animAsset = 'assets/videos/0001-2gPfomN.webp';

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);
    expect(countImagesByAsset(tester, animAsset), 0);

    // 按住不动：长按识别（500ms）后动图淡入；交叉淡入 200ms 需再泵一帧才算完成
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('四分之三仰卧起坐')),
    );
    await pumpFor(tester, const Duration(milliseconds: 800));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(countImagesByAsset(tester, animAsset), 1);
    expect(countImagesByAsset(tester, thumbAsset), 0);

    // 松开还原，且不触发详情弹窗
    await gesture.up();
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(countImagesByAsset(tester, animAsset), 0);
    expect(countImagesByAsset(tester, thumbAsset), 1);
    expect(find.text('部位'), findsNothing);
  });

  testWidgets('窄屏 ≤480px：网格固定两列、间距 8', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);

    // 网格限定在结果视图内（总览页的分类网格仍在被覆盖路由上）
    final grid = tester.widget<GridView>(
      find.descendant(of: find.byType(ResultsView), matching: find.byType(GridView)),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.crossAxisSpacing, 8);
    expect(delegate.mainAxisSpacing, 8);
  });

  testWidgets('卡片标签按内容自适应宽度，不撑满整行', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);

    // 找「器材」标签的绿色背景容器（第一条动作的器材是「徒手」）
    final containers = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == AppColors.tagEquipBg,
          ),
        )
        .toList();
    expect(containers, isNotEmpty);

    // 宽度应远小于卡片宽度（约 190px）：「徒手」标签只有 ~32px
    for (final container in containers) {
      final width =
          tester.renderObject<RenderBox>(find.byWidget(container)).size.width;
      expect(width, lessThan(100));
    }
  });
}

/// 统计树中引用指定 asset 的 Image 数量。
int countImagesByAsset(WidgetTester tester, String assetName) => tester
    .widgetList<Image>(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == assetName,
      ),
    )
    .length;
