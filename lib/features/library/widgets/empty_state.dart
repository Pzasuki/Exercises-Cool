import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 空结果占位，对应 .empty-state（🔍 未找到相关动作）。
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🔍', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text(
            '未找到相关动作',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
