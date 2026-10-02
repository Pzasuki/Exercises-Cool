import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

/// 应用根：主题 + 主框架（底部 3 Tab）。应用名「动作库」对应 index.html `<title>`。
class ExercisesApp extends StatelessWidget {
  const ExercisesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '动作库',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const HomeShell(),
    );
  }
}
