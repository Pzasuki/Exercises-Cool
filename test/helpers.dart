import 'dart:convert';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exercises_app/app.dart';
import 'package:exercises_app/data/models/exercise.dart';
import 'package:exercises_app/features/library/widgets/filter_panel.dart';
import 'package:exercises_app/state/library_controller.dart';

/// 测试共用工具：真实数据加载、App 泵入、进入浏览页。

/// 从打包 assets 加载全部动作（runAsync 避免阻塞测试事件循环）。
Future<List<Exercise>> loadExercises(WidgetTester tester) async {
  final raw = (await tester.runAsync(
    () => rootBundle.loadString('assets/data/exercises.json'),
  ))!;
  return (jsonDecode(raw) as List<dynamic>)
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// 泵入完整 App（首页为总览页）。
/// 不用 pumpAndSettle：网格尾部的加载指示器会一直转动。
Future<void> pumpApp(WidgetTester tester, List<Exercise> exercises) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LibraryController(exercises),
      child: const ExercisesApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// 从总览页点「全部动作」进入浏览页，并推进路由动画。
Future<void> enterBrowse(WidgetTester tester) async {
  await tester.tap(find.text('全部动作'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 浏览页的返回键（宽屏在侧栏顶部，窄屏在标题栏）。
Finder backButton() => find.byIcon(Icons.arrow_back_rounded);

/// 推进一帧构建 + 一帧到 [duration] 后（用于防抖/动画等延时生效）。
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  await tester.pump();
  await tester.pump(duration);
}

/// 侧栏面板内的芯片（芯片文本带 facet 计数，用 textContaining 匹配标签）。
Finder panelChip(String label) => find.descendant(
      of: find.byType(FilterPanel),
      matching: find.textContaining(label),
    );
