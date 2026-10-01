import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// 浅色主题：由 index.html 的 CSS 设计 tokens 映射而来。
/// 原版固定浅色（无深色模式）；深色模式可作为后续增强（见 MIGRATION.md 阶段6）。
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bgBase,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.bgSurface,
  ),
  dividerColor: AppColors.border,
  splashFactory: InkSparkle.splashFactory,

  // 搜索框（.search-box）：浅灰底 + 圆角 + 聚焦时主题色描边
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.bgInput,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
    border: _inputBorder(AppColors.border),
    enabledBorder: _inputBorder(AppColors.border),
    focusedBorder: _inputBorder(AppColors.accent),
  ),
);

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: color),
    );
