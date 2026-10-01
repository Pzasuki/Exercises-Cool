import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/overview/overview_screen.dart';

/// 应用根：主题 + 首页（分类总览）。应用名「动作库」对应 index.html `<title>`。
class ExercisesApp extends StatelessWidget {
  const ExercisesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '动作库',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const OverviewScreen(),
    );
  }
}
