import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 「动作库」logo（对应 .sidebar-logo，其中「库」为主题色）。
/// 总览页顶栏与侧栏共用。
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '动作',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
        children: [
          TextSpan(text: '库', style: TextStyle(color: AppColors.accent)),
        ],
      ),
    );
  }
}
