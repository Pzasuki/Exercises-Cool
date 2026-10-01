import 'package:flutter/material.dart' show Size, Icons;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 详情弹窗交互测试：宽屏居中弹窗 / 窄屏底部弹层，真实数据驱动。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('宽屏：点卡片打开居中弹窗，Esc 与遮罩均可关闭', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);

    // 打开详情
    await tester.tap(find.text('四分之三仰卧起坐'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('部位'), findsOneWidget);
    // 「目标肌肉」出现 2 处：侧栏筛选区标题 + 弹窗 meta chip 标签
    expect(find.text('目标肌肉'), findsNWidgets(2));
    expect(find.text('动作步骤'), findsOneWidget);

    // Esc 关闭（对应 keydown Escape → closeModal）
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('部位'), findsNothing);
    // 弹窗关掉的是详情层，主界面网格应仍在
    expect(find.text('共 1324 个动作'), findsOneWidget);

    // 重新打开，点面板外遮罩关闭（对应 e.target === modalOverlay）
    await tester.tap(find.text('四分之三仰卧起坐'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('部位'), findsOneWidget);

    await tester.tapAt(const Offset(60, 400));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('部位'), findsNothing);
    expect(find.text('共 1324 个动作'), findsOneWidget);
  });

  testWidgets('窄屏：点卡片打开底部弹层，× 可关闭', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(tester, await loadExercises(tester));
    await enterBrowse(tester);

    await tester.tap(find.text('四分之三仰卧起坐'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('部位'), findsOneWidget);
    expect(find.text('动作步骤'), findsOneWidget);

    // × 关闭
    await tester.tap(find.byIcon(Icons.close));
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.text('部位'), findsNothing);
    expect(find.text('共 1324 个动作'), findsOneWidget);
  });
}
