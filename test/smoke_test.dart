import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 冒烟测试：用真实打包数据驱动 数据 → 状态 → UI 全管线
/// （总览首页 → 全部动作浏览页）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('加载 exercises.json 并渲染总览首页', (tester) async {
    final exercises = await loadExercises(tester);
    expect(exercises, hasLength(1324));

    await pumpApp(tester, exercises);

    // 总览页：全部动作入口 + 部位卡片（名称 + 数量）
    expect(find.text('全部动作'), findsOneWidget);
    expect(find.text('1324 个动作'), findsOneWidget);
    expect(find.text('上臂'), findsOneWidget);
    expect(find.text('292 个动作'), findsOneWidget);
    // 浏览页的结果条此时不应出现
    expect(find.text('共 1324 个动作'), findsNothing);
  });

  testWidgets('进入浏览页后渲染结果条、卡片与侧栏筛选区', (tester) async {
    final exercises = await loadExercises(tester);

    await pumpApp(tester, exercises);
    await enterBrowse(tester);

    // 结果条计数
    expect(find.text('共 1324 个动作'), findsOneWidget);
    // 第一条动作的卡片名称
    expect(find.text('四分之三仰卧起坐'), findsOneWidget);
    // 侧栏三组筛选区已渲染（logo 为 Text.rich 富文本，不能用 find.text 匹配）
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('器材'), findsOneWidget);
    expect(find.text('目标肌肉'), findsOneWidget);
  });
}
