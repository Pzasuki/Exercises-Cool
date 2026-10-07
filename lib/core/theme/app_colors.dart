import 'package:flutter/material.dart';

import 'theme_service.dart';

/// 颜色 tokens，一一对应 www/index.html `<style>` 里 `:root` 的 CSS 变量。
/// 主题色（accent/accentMuted）为运行时值（设置页可切换），由
/// [ThemeService] 提供；切换时 ExercisesApp 整树重建，静态 token 取到新值。
abstract final class AppColors {
  // ── 背景 ──
  static const Color bgBase = Color(0xFFF4F4F5); // --bg-base
  static const Color bgSurface = Color(0xFFFFFFFF); // --bg-surface
  static const Color bgElevated = Color(0xFFF0F0F1); // --bg-elevated
  static const Color bgInput = Color(0xFFF4F4F5); // --bg-input

  // ── 边框 ──
  static const Color border = Color(0xFFE4E4E7); // --border
  static const Color borderHover = Color(0xFFC4C4C7); // --border-hover

  // ── 主题色（运行时可切换，非 const）──
  static Color get accent => ThemeService.instance.accentColor;
  static Color get accentMuted =>
      ThemeService.instance.accentColor.withValues(alpha: 0.08);

  // ── 文字 ──
  static const Color textPrimary = Color(0xFF111111); // --text-primary
  static const Color textSecondary = Color(0xFF71717A); // --text-secondary
  static const Color textTertiary = Color(0xFFA1A1AA); // --text-tertiary

  // ── 卡片标签（.tag-cat / .tag-equip）──
  // 文字取 600/700 深色阶：400 系浅色（#60A5FA/#4ADE80）在浅底上
  // 对比度只有 2~2.5:1，10px 小字不可读；深色阶达到 4.5:1 以上。
  static const Color tagCatBg = Color(0x1F3B82F6); // rgba(59,130,246,0.12)
  static const Color tagCatText = Color(0xFF2563EB); // blue-600
  static const Color tagEquipBg = Color(0x1A22C55E); // rgba(34,197,94,0.10)
  static const Color tagEquipText = Color(0xFF15803D); // green-700
}
