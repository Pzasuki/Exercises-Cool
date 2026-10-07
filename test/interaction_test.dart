import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/core/theme/app_colors.dart';
import 'package:exercises_app/features/library/widgets/filter_section.dart';
import 'package:exercises_app/features/library/widgets/results_view.dart';
import 'package:exercises_app/features/library/widgets/search_field.dart';

import 'helpers.dart';

/// 交互细节测试：结果条计数反馈 / 筛选弹层重置 / 卡片悬停动图 / 窄屏两列网格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('结果条：点芯片计数即时更新，再次点击恢复', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    final dumbbellCount =
        exercises.where((e) => e.equipment == 'dumbbell').length;

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);
    expect(find.text('共 1324 个动作'), findsOneWidget);

    // 选中器材芯片（分类芯片选中后会进入分类页形态）
    await tester.tap(panelChip('哑铃'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('$dumbbellCount / 1324 个动作'), findsOneWidget);

    // 再次点击取消选择，计数恢复
    await tester.tap(panelChip('哑铃'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('共 1324 个动作'), findsOneWidget);
  });

  testWidgets('筛选弹层重置：筛选与搜索框一起清空', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final exercises = await loadExercises(tester);
    await pumpApp(tester, exercises);
    await enterBrowse(tester);

    // 工具栏搜索（防抖后生效）+ 弹层内选中器材
    await tester.enterText(find.byType(SearchField).last, '深蹲');
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('筛选'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(
      find.descendant(
        of: find.byType(FilterSection),
        matching: find.textContaining('哑铃'),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 100));
    await tester.tap(find.text('完成'));
    await pumpFor(tester, const Duration(milliseconds: 400));

    final expected = exercises
        .where(
          (e) => e.equipment == 'dumbbell' && e.searchIndex.contains('深蹲'),
        )
        .length;
    expect(find.text('$expected / 1324 个动作'), findsOneWidget);

    // 重新打开弹层 → 重置 → 完成：筛选与搜索一并清空
    await tester.tap(find.text('筛选'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('重置'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    await tester.tap(find.text('完成'));
    await pumpFor(tester, const Duration(milliseconds: 400));

    // 「共 1324 个动作」即证明搜索与筛选都已清空（仅清筛选时
    // 搜索词「深蹲」仍会过滤出更少的结果）
    expect(find.text('共 1324 个动作'), findsOneWidget);
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

  testWidgets('搜索框：键盘收起后释放焦点，输入法不再被反复拉起', (tester) async {
    await pumpApp(tester, await loadExercises(tester));

    // 聚焦搜索框
    await tester.showKeyboard(find.byType(EditableText).first);
    final editable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);

    // 键盘可见（视图级 metrics 变更会触发 WidgetsBindingObserver）
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.reset);
    await tester.pump();

    // 系统返回收起键盘（焦点仍悬在输入框上）→ 应主动释放焦点，
    // 否则之后切 Tab / 开弹层 / 返回等任意操作都会把输入法拉起来
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();
    expect(editable.widget.focusNode.hasFocus, isFalse);
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
