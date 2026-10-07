import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/library_controller.dart';
import 'filter_section.dart';

/// 打开筛选弹层（窄屏「全部动作」/分类页共用）。
/// 选择即时生效（与原侧栏一致），弹层只是集中承载三个维度的芯片；
/// 底部提供「重置」与「完成」。
Future<void> showFilterSheet(BuildContext context) {
  // 打开前释放搜索框焦点，输入法不跟到弹层上
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => const FilterSheet(),
  );
}

/// 筛选弹层：拖拽条 + 三组维度芯片（滚动区）+ 重置/完成 底栏。
/// 三个维度固定全展示（含分类）——与旧侧栏「分类归总览页管」不同，
/// 弹层内允许直接切换分类，避免选择过程中分组忽隐忽现。
class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  FilterSection(title: '分类', filterKey: FilterKey.category),
                  SizedBox(height: 24),
                  FilterSection(
                    title: '器材',
                    filterKey: FilterKey.equipment,
                    initialLimit: 8,
                  ),
                  SizedBox(height: 24),
                  FilterSection(title: '目标肌肉', filterKey: FilterKey.target),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.read<LibraryController>().clearAllFilters(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('重置'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
