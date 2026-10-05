import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 系统返回键行为（HomeShell PopScope，见 MIGRATION.md 阶段13）：
/// 压在根路由上的页面逐层正常 pop；训练/收藏 Tab 被拦截并切回主页；
/// 主页 Tab 不拦截（走系统默认退出应用）。
void main() {
  testWidgets('返回键：压栈页面逐层 pop，非主页 Tab 回主页，主页不拦截',
      (tester) async {
    await pumpApp(tester, await loadExercises(tester));

    // 浏览页（push 进来的上一页）返回不受影响：pop 后回到主页 Tab
    await tester.tap(find.text('全部动作'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('器材'), findsOneWidget); // 浏览页侧栏分区标题
    await tester.binding.handlePopRoute();
    await pumpFor(tester, const Duration(milliseconds: 800));
    expect(find.text('器材'), findsNothing);
    expect(find.text('全部动作'), findsOneWidget);

    // 训练 Tab：返回键切回主页（返回事件被消费）
    await tester.tap(find.text('训练'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('开始训练'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('开始训练'), findsNothing);
    expect(find.text('全部动作'), findsOneWidget);

    // 收藏 Tab：同理
    await tester.tap(find.text('收藏'));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('我的收藏'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(find.text('我的收藏'), findsNothing);
    expect(find.text('全部动作'), findsOneWidget);

    // 主页 Tab：不拦截返回（返回 false，由系统默认行为退出应用）
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
}
