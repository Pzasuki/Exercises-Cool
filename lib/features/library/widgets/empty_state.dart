import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// 空结果占位（对应 .empty-state）：矢量图标 + 主文案 + 可选副文案。
/// 替代原版 emoji（🔍）——图标走统一的灰阶圆形底，与整体卡片语言一致。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.search_off_rounded,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppText.fsBody,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppText.fsBodySm,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
