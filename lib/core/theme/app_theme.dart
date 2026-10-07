import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text.dart';

/// 浅色主题：由 index.html 的 CSS 设计 tokens 映射而来。
/// 主题色为参数（设置页可切换），传入当前 [ThemeService] 的 accentColor。
/// 原版固定浅色（无深色模式）；深色模式可作为后续增强（见 MIGRATION.md 阶段6）。
ThemeData buildAppTheme(Color accent) => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
        primary: accent,
        secondary: accent,
        surface: AppColors.bgSurface,
      ),
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.splashFactory,

      // 搜索框（.search-box）：浅灰底 + 圆角 + 聚焦时主题色描边
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(
            color: AppColors.textTertiary, fontSize: AppText.fsBodySm),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(accent),
      ),

      // 弹窗：底色/圆角与底部弹层一致（M3 默认 28 圆角偏大），标题收紧
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: AppText.fsHeading,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: AppText.fsBodySm,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),

      // 历史训练等 ExpansionTile 的展开箭头默认跟着 colorScheme 走，
      // 统一为中性灰，避免抢占主题色的视觉层级
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textTertiary,
      ),
    );

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: color),
    );
