import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exercises_app/data/models/exercise.dart';
import 'package:exercises_app/main.dart';

import 'helpers.dart';

/// 启动引导测试：加载态先出首帧、加载失败可重试
/// （对应 main.dart 的 ExerciseBootstrap）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('加载态先出首帧，数据到位后进入总览页', (tester) async {
    final exercises = await loadExercises(tester);
    final gate = Completer<List<Exercise>>();
    await tester.pumpWidget(
      ExerciseBootstrap(loader: () => gate.future),
    );

    // 数据未就绪：加载态，应用未渲染
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('全部动作'), findsNothing);

    gate.complete(exercises);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('全部动作'), findsOneWidget);
  });

  testWidgets('加载失败展示错误页，「重试」成功后进入应用', (tester) async {
    final exercises = await loadExercises(tester);
    var attempt = 0;
    await tester.pumpWidget(
      ExerciseBootstrap(loader: () async {
        attempt++;
        if (attempt == 1) throw Exception('模拟数据损坏');
        return exercises;
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('动作数据加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('全部动作'), findsOneWidget);
  });
}
