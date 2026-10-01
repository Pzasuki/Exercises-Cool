import 'package:flutter/material.dart';

/// 颜色 tokens，一一对应 www/index.html `<style>` 里 `:root` 的 CSS 变量。
abstract final class AppColors {
  // ── 背景 ──
  static const Color bgBase = Color(0xFFF4F4F5); // --bg-base
  static const Color bgSurface = Color(0xFFFFFFFF); // --bg-surface
  static const Color bgElevated = Color(0xFFF0F0F1); // --bg-elevated
  static const Color bgInput = Color(0xFFF4F4F5); // --bg-input

  // ── 边框 ──
  static const Color border = Color(0xFFE4E4E7); // --border
  static const Color borderHover = Color(0xFFC4C4C7); // --border-hover

  // ── 主题色 ──
  static const Color accent = Color(0xFFFF4F00); // --accent
  static const Color accentMuted = Color(0x14FF4F00); // --accent-muted: rgba(255,79,0,0.08)

  // ── 文字 ──
  static const Color textPrimary = Color(0xFF111111); // --text-primary
  static const Color textSecondary = Color(0xFF71717A); // --text-secondary
  static const Color textTertiary = Color(0xFFA1A1AA); // --text-tertiary

  // ── 卡片标签（.tag-cat / .tag-equip）──
  static const Color tagCatBg = Color(0x1F3B82F6); // rgba(59,130,246,0.12)
  static const Color tagCatText = Color(0xFF60A5FA);
  static const Color tagEquipBg = Color(0x1A22C55E); // rgba(34,197,94,0.10)
  static const Color tagEquipText = Color(0xFF4ADE80);
}
