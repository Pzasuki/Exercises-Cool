import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 全局字号阶梯：所有界面统一从这套取值（原来散落的 10/10.5/12.5/13.5
/// 等半号字归并到最近一档），新样式请勿自创字号。
abstract final class AppText {
  // ── 字号阶梯 ──
  static const double fsMicro = 11; // 标签、徽章、小计数
  static const double fsCaption = 12; // 辅助说明、芯片、统计标签
  static const double fsBodySm = 13; // 次要正文、卡片副标题
  static const double fsBody = 14; // 正文、列表标题、按钮
  static const double fsHeading = 16; // 区块标题、主 CTA 文案
  static const double fsTitle = 18; // 页面标题、弹窗标题
  static const double fsTitleLg = 22; // 大标题（训练中动作名）
  static const double fsTimer = 52; // 组间倒计时专用

  /// 数字用等宽数字（倒计时、计步值），刷新时不左右跳动。
  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  // ── 高频组合样式 ──

  /// 页面标题（自绘顶栏的标题）。
  static const TextStyle pageTitle = TextStyle(
    fontSize: fsTitle,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// 区块标题（列表分区、明细区）。
  static const TextStyle sectionTitle = TextStyle(
    fontSize: fsBody,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// 小节标签（筛选分区、详情分区的 overline）。
  static const TextStyle overline = TextStyle(
    fontSize: fsMicro,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textTertiary,
  );
}
