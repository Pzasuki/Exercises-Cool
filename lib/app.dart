import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_service.dart';
import 'features/home/home_shell.dart';

/// 应用根：主题 + 主框架（底部 4 Tab）。应用名「动作库」对应 index.html `<title>`。
/// 监听 [ThemeService]：切换主题色时整树重建，静态 token 取到新值。
class ExercisesApp extends StatelessWidget {
  const ExercisesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return MaterialApp(
      title: '动作库',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeService.accentColor),
      home: const HomeShell(),
    );
  }
}
