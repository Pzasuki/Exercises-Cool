import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart'
    show AlertDialog, GridView, Icons, InkWell, Key, Size, Switch, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exercises_app/services/rest_alarm_service.dart';
import 'package:exercises_app/state/workout_controller.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WorkoutController', () {
    test('规划：添加/调整/移除动作', () {
      final controller = WorkoutController();
      controller.startPlanning();
      expect(controller.status, WorkoutStatus.planning);

      controller.addExercise('e1');
      controller.addExercise('e2');
      expect(controller.session, hasLength(2));
      expect(controller.session[0].sets, 3);
      expect(controller.session[0].reps, 10);

      controller.updateEntry(0, sets: 4, reps: 12);
      expect(controller.session[0].sets, 4);
      expect(controller.session[0].reps, 12);

      controller.moveEntry(1, -1);
      expect(controller.session[0].exerciseId, 'e2');

      controller.removeEntry(0);
      expect(controller.session.single.exerciseId, 'e1');
    });

    test('执行：逐组打点、自动切动作、训练完成', () {
      final controller = WorkoutController();
      controller.startPlanning();
      controller.addExercise('e1');
      controller.addExercise('e2');
      controller.setRestSeconds(0); // 关闭倒计时
      controller.startSession();
      expect(controller.status, WorkoutStatus.running);

      // e1 共 3 组：前两组完成后切不了动作
      controller.completeSet();
      controller.completeSet();
      expect(controller.currentEntry.exerciseId, 'e1');
      expect(controller.currentEntry.completedSets, 2);

      // 第三组完成 → 自动切到 e2
      controller.completeSet();
      expect(controller.currentEntry.exerciseId, 'e2');
      expect(controller.totalSetsDone, 3);

      // e2 的 3 组完成后 → 总结
      controller.completeSet();
      controller.completeSet();
      controller.completeSet();
      expect(controller.status, WorkoutStatus.finished);
      expect(controller.totalSetsDone, 6);
    });

    test('执行：组间倒计时（计时自动结束），休息中打点无效', () {
      fakeAsync((async) {
        final controller = WorkoutController();
        controller.startPlanning();
        controller.addExercise('e1');
        controller.setRestSeconds(60);
        controller.startSession();

        controller.completeSet();
        expect(controller.resting, isTrue);
        expect(controller.restRemaining, 60);

        // 休息中打点无效
        controller.completeSet();
        expect(controller.currentEntry.completedSets, 1);

        async.elapse(const Duration(seconds: 59));
        expect(controller.resting, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(controller.resting, isFalse);
        expect(controller.restRemaining, 0);
        // 自然走完 → 桥接据此到点响铃提醒
        expect(controller.restEndReason, RestEndReason.completed);

        // 休息结束后可继续打点
        controller.completeSet();
        expect(controller.currentEntry.completedSets, 2);
      });
    });

    test('执行：跳过休息 +15s、跳过动作、提前结束', () {
      fakeAsync((async) {
        final controller = WorkoutController();
        controller.startPlanning();
        controller.addExercise('e1');
        controller.addExercise('e2');
        controller.setRestSeconds(60);
        controller.startSession();

        controller.completeSet();
        expect(controller.resting, isTrue);
        controller.addRestTime(15);
        expect(controller.restRemaining, 75);
        controller.skipRest();
        expect(controller.resting, isFalse);
        // 手动跳过 → 静默撤销提醒，不出声
        expect(controller.restEndReason, RestEndReason.skipped);

        // 跳过该动作 → 直接切下一个
        controller.skipExercise();
        expect(controller.currentEntry.exerciseId, 'e2');

        // 提前结束 → 总结页，已完成组数保留
        // （跳过动作按剩余组数全部记完成：e1 的 3 组 + e2 的 1 组 = 4）
        controller.completeSet();
        controller.abandonSession();
        expect(controller.status, WorkoutStatus.finished);
        expect(controller.totalSetsDone, 4);
      });
    });

    test('间歇分钟制：1 分钟起、上限 10 分钟', () {
      final controller = WorkoutController();
      controller.setRestSeconds(0);
      expect(controller.restMinutes, 0);

      controller.setRestMinutes(2);
      expect(controller.restSeconds, 120);
      expect(controller.restMinutes, 2);

      controller.setRestMinutes(0); // 下限钳到 1
      expect(controller.restSeconds, 60);
      controller.setRestMinutes(99); // 上限钳到 10
      expect(controller.restSeconds, 600);
    });

    test('重量：设置与清空（clearWeight）', () {
      final controller = WorkoutController();
      controller.startPlanning();
      controller.addExercise('e1');
      controller.updateEntry(0, weight: 20);
      expect(controller.session.single.weight, 20);
      controller.updateEntry(0, clearWeight: true);
      expect(controller.session.single.weight, isNull);
    });

    test('完成训练写入历史（感受/重量），删除生效', () {
      final controller = WorkoutController();
      controller.startPlanning();
      controller.addExercise('e1');
      controller.addExercise('e2');
      controller.updateEntry(0, weight: 12.5);
      controller.setRestSeconds(0);
      controller.startSession();

      // e1 做满，e2 跳过（按剩余组数记完成）
      controller.completeSet();
      controller.completeSet();
      controller.completeSet();
      controller.skipExercise();

      expect(controller.status, WorkoutStatus.finished);
      controller.setFeeling('有点累');
      controller.finishAndSave();

      expect(controller.status, WorkoutStatus.idle);
      final record = controller.history.single;
      expect(record.feeling, '有点累');
      expect(record.totalSetsDone, 6);
      expect(record.entries.first.weight, 12.5);

      controller.deleteRecord(record.id);
      expect(controller.history, isEmpty);
    });

    test('历史重新训练：按记录进入规划（计划值还原、进度清零），可反复点击', () {
      final controller = WorkoutController();
      controller.startPlanning();
      controller.addExercise('e1');
      controller.addExercise('e2');
      controller.updateEntry(0, sets: 5, reps: 8, weight: 20);
      controller.setRestSeconds(0);
      controller.startSession();

      // e1 做满（5 组）、e2 跳过 → 两个动作都进历史
      controller.completeSet();
      controller.completeSet();
      controller.completeSet();
      controller.completeSet();
      controller.completeSet();
      controller.skipExercise();
      controller.finishAndSave();
      final record = controller.history.single;
      expect(record.entries, hasLength(2));

      controller.repeatRecord(record.id);
      expect(controller.status, WorkoutStatus.planning);
      expect(controller.session, hasLength(2));
      expect(controller.session[0].sets, 5);
      expect(controller.session[0].reps, 8);
      expect(controller.session[0].weight, 20);
      expect(controller.session[0].completedSets, 0);
      expect(controller.session[1].sets, 3);
      expect(controller.session[1].weight, isNull);

      // 反复点击重新训练：每次都是干净的规划态
      controller.repeatRecord(record.id);
      expect(controller.status, WorkoutStatus.planning);
      expect(controller.session.first.completedSets, 0);

      // 不存在的 id 不改变当前状态
      controller.repeatRecord('missing');
      expect(controller.status, WorkoutStatus.planning);
      expect(controller.session, hasLength(2));
    });

    test('默认训练参数：保存后套用到新动作与当前清单，持久化', () async {
      final controller = WorkoutController();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.defaultsConfigured, isFalse);

      controller.startPlanning();
      controller.addExercise('e1'); // 默认 3 × 10
      controller.saveDefaults(sets: 4, reps: 12, weight: 20);

      expect(controller.defaultsConfigured, isTrue);
      // 当前清单同步套用
      expect(controller.session.single.sets, 4);
      expect(controller.session.single.reps, 12);
      expect(controller.session.single.weight, 20);

      // 之后添加的动作自动套用
      controller.addExercise('e2');
      expect(controller.session[1].sets, 4);
      expect(controller.session[1].reps, 12);
      expect(controller.session[1].weight, 20);

      // 重建后还原
      final reloaded = WorkoutController();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloaded.defaultsConfigured, isTrue);
      expect(reloaded.defaultSets, 4);
      expect(reloaded.defaultReps, 12);
      expect(reloaded.defaultWeight, 20);
    });

    test('模板：保存/加载/删除，且持久化', () async {
      final controller = WorkoutController();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.startPlanning();
      controller.addExercise('e1');
      controller.updateEntry(0, sets: 5, reps: 8);
      controller.saveTemplate('下肢日');
      expect(controller.templates.single.name, '下肢日');
      expect(controller.templates.single.entries.single.sets, 5);

      // 重建后还原
      final reloaded = WorkoutController();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloaded.templates.single.name, '下肢日');

      // 加载模板 → 规划态带原清单（进度清零）
      reloaded.loadTemplate(reloaded.templates.single.id);
      expect(reloaded.status, WorkoutStatus.planning);
      expect(reloaded.session.single.exerciseId, 'e1');
      expect(reloaded.session.single.sets, 5);

      reloaded.deleteTemplate(reloaded.templates.single.id);
      expect(reloaded.templates, isEmpty);
    });
  });

  group('训练 Tab 组件', () {
    /// 通过挑动作弹层添加一个动作（搜索 + 选卡 + 批量带回 + 跳过首次引导）。
    Future<void> addViaPicker(
      WidgetTester tester,
      String query,
    ) async {
      await tester.tap(find.text('添加动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('搜索动作库'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.byKey(const Key('exercisePickerSearch')),
        query,
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.textContaining(query),
        ).first,
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('添加 1 个动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      // 首次添加引导：跳过（保持 3 组 × 10 次）；等弹窗淡出出树
      await tester.tap(find.text('跳过'));
      await pumpFor(tester, const Duration(milliseconds: 300));
    }

    testWidgets('点系统通知回调：切到训练 Tab', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      expect(find.text('全部动作'), findsOneWidget); // 动作库 Tab

      // 原生侧收到通知点击后经 RestAlarmService.onOpenWorkoutRequested 转发
      RestAlarmService.onOpenWorkoutRequested?.call();
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('开始训练'), findsOneWidget); // 训练 Tab
    });

    testWidgets('挑动作：器材总览 → 器材内部位分组 → 多选批量加',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      await tester.tap(find.text('训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('开始训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('添加动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('搜索动作库'));
      await pumpFor(tester, const Duration(milliseconds: 200));

      // 一级：器材卡片总览 + 部位筛选 chips（全部 = 全库 1324）
      expect(find.text('全部 1324'), findsOneWidget);
      expect(find.text('徒手'), findsOneWidget);
      expect(find.text('325 个动作'), findsOneWidget);

      // 部位筛选：选「胸部」→ 器材卡片只显示有胸部动作的，数量为胸部范围内
      await tester.tap(find.text('胸部 163'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('36 个动作'), findsOneWidget); // 徒手 ∧ 胸部
      expect(find.text('325 个动作'), findsNothing);
      expect(find.text('颈部'), findsNothing); // 颈部无胸部动作，卡片隐藏

      // 进入「徒手」→ 只显示胸部分组
      await tester.tap(find.text('徒手'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('徒手 · 36 个动作'), findsOneWidget);
      // 「胸部 36」= 筛选芯片 + 部位分组标题各一处（芯片计数在二级也是范围内数量）
      expect(find.text('胸部 36'), findsNWidgets(2));

      // 返回总览（筛选保留），点「全部」恢复全量
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('36 个动作'), findsOneWidget);
      await tester.tap(find.text('全部 1324'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('325 个动作'), findsOneWidget);

      // 搜索仍可用：总览级搜全库
      await tester.enterText(
        find.byKey(const Key('exercisePickerSearch')),
        '深蹲',
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      final searchCard = find.descendant(
        of: find.byType(GridView),
        matching: find.textContaining('深蹲'),
      ).first;
      await tester.tap(searchCard);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('添加 1 个动作'), findsOneWidget);

      // 取消该选择（选择跨层级/搜索保留，这是批量添加的预期行为）
      await tester.tap(searchCard);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('选择要添加的动作'), findsOneWidget);

      // 清空搜索回到器材总览，进「徒手」（325 个动作，内部按部位分组）
      await tester.enterText(
        find.byKey(const Key('exercisePickerSearch')),
        '',
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('徒手'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(find.text('徒手 · 325 个动作'), findsOneWidget);
      // 「胸部 36」= 部位筛选芯片 + 部位分组标题（芯片计数在二级按器材范围）
      expect(find.text('胸部 36'), findsNWidgets(2));

      // 多选两张卡 → 批量带回（首次引导保存默认值）
      final inkWells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWells.first);
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(inkWells.at(1));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('添加 2 个动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('保存'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text('次/组'), findsNWidgets(2));
    });

    testWidgets('规划（搜索挑动作）→ 做组打点 → 总结 → 存模板', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      await tester.tap(find.text('训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('开始训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      await addViaPicker(tester, '深蹲');

      // 清单里出现该动作（步进器标签）；间歇默认关闭；开始训练
      expect(find.text('次/组'), findsOneWidget);
      expect(find.text('关'), findsOneWidget);
      await tester.tap(find.text('开始'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      // 做组：3 组完成后自动进入总结
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      expect(find.text('第 2 / 3 组 · 每组 10 次'), findsOneWidget);
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(find.textContaining('完成 1 个动作 · 共 3 组'), findsOneWidget);

      // 存为模板 → 完成 → 回到起始页，模板可见
      await tester.tap(find.text('存为模板'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '下肢日',
      );
      await tester.tap(find.text('保存'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.tap(find.text('完成'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      expect(find.text('下肢日'), findsOneWidget);
      expect(find.text('1 个动作 · 共 3 组'), findsOneWidget);
    });

    testWidgets('组间倒计时：完成一组后出现倒计时，可跳过', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      await tester.tap(find.text('训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('开始训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      await addViaPicker(tester, '深蹲');

      // 打开组间倒计时（默认关，开启后 1 分钟）
      expect(find.text('关'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('1 分钟'), findsOneWidget);
      await tester.tap(find.text('开始'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('休息中…'), findsOneWidget);

      // +15s / 跳过休息（先等休息卡展开动画结束，按钮才在可点击区域内）
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('+15s'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      expect(find.text('1:15'), findsOneWidget);
      await tester.tap(find.text('跳过休息'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      expect(find.text('休息中…'), findsNothing);
    });

    testWidgets('首次添加引导：保存默认重量/组数后，后续动作自动套用', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      await tester.tap(find.text('训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('开始训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      // 第一次添加：引导弹窗 → 组 +1（4 组）→ 重量 +（10kg）→ 保存
      await tester.tap(find.text('添加动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('搜索动作库'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.byKey(const Key('exercisePickerSearch')),
        '深蹲',
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.textContaining('深蹲'),
        ).first,
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('添加 1 个动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text('设置默认训练参数'), findsOneWidget);
      final dialogAdds = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.add_circle_outline),
      );
      await tester.tap(dialogAdds.first); // 组：3 → 4
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(dialogAdds.last); // 重量：未设置 → 10kg
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('保存'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      // 当前动作套用默认值
      expect(find.text('4'), findsOneWidget);
      expect(find.text('10kg'), findsOneWidget);

      // 第二次添加：不再弹引导，自动套用默认值
      await tester.tap(find.text('添加动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('搜索动作库'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.tap(find.text('徒手'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(InkWell),
        ).first,
      );
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('添加 1 个动作'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('次/组'), findsNWidgets(2));
      expect(find.text('4'), findsNWidgets(2));
      expect(find.text('10kg'), findsNWidgets(2));
    });

    testWidgets('重量步进 → 执行页展示 → 感受选择 → 历史记录与删除', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));
      await tester.tap(find.text('训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('开始训练'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      await addViaPicker(tester, '深蹲');

      // 重量未设置 → 点 + 从 10kg 起（卡片里最后一个 + 号是重量步进）
      expect(find.text('未设置'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('10kg'), findsOneWidget);

      await tester.tap(find.text('开始'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('· 10kg'), findsOneWidget);

      // 执行页为精简形态：仅动图与动作步骤（元信息/肌群在做组间隙
      // 没有阅读价值，已省略）
      expect(find.text('部位'), findsNothing);
      expect(find.text('主要肌群'), findsNothing);
      expect(find.text('动作步骤'), findsOneWidget);

      // 3 组做完 → 总结；选「很累」→ 完成写入历史
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('完成一组'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      await tester.tap(find.text('很累'));
      await pumpFor(tester, const Duration(milliseconds: 50));
      await tester.tap(find.text('完成'));
      await pumpFor(tester, const Duration(milliseconds: 100));

      // 起始页出现历史卡片（含感受与重量明细），可展开、可删除
      expect(find.textContaining('感受：很累'), findsOneWidget);
      await tester.tap(find.textContaining('个动作 · 共 3 组'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(find.textContaining('3/3 组 · 每组 10 次 · 10kg'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('感受：很累'), findsNothing);
    });
  });
}
