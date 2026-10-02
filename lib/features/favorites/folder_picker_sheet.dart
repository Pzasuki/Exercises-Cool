import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../state/favorites_service.dart';

/// 详情弹窗的「收藏到收藏夹」弹层：勾选/取消多个收藏夹（即时生效），
/// 底部可当场新建收藏夹并勾上。
Future<void> showFavoriteFolderPicker(
    BuildContext context, String exerciseId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
    ),
    builder: (context) => _FolderPickerSheet(exerciseId: exerciseId),
  );
}

class _FolderPickerSheet extends StatelessWidget {
  const _FolderPickerSheet({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FavoritesService>();
    final selected = service.folderIdsOf(exerciseId);
    final folders = service.folders;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              '收藏到收藏夹',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (folders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Text(
                '还没有收藏夹，新建一个吧',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              children: [
                for (final folder in folders)
                  ListTile(
                    leading: Icon(
                      selected.contains(folder.id)
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      size: 20,
                      color: selected.contains(folder.id)
                          ? AppColors.accent
                          : AppColors.textTertiary,
                    ),
                    title: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: selected.contains(folder.id)
                        ? const Icon(Icons.check, size: 18, color: AppColors.accent)
                        : null,
                    onTap: () => context
                        .read<FavoritesService>()
                        .toggleInFolder(folder.id, exerciseId),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, size: 20, color: AppColors.accent),
            title: const Text(
              '新建收藏夹',
              style: TextStyle(fontSize: 14, color: AppColors.accent),
            ),
            onTap: () async {
              final name = await _newFolderDialog(context);
              if (name == null || name.trim().isEmpty) return;
              if (!context.mounted) return;
              context
                  .read<FavoritesService>()
                  .createFolder(name.trim());
              // 新建的夹是最后一个，直接把动作收进去
              final folders = context.read<FavoritesService>().folders;
              if (folders.isNotEmpty) {
                context
                    .read<FavoritesService>()
                    .addToFolder(folders.last.id, exerciseId);
              }
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

Future<String?> _newFolderDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建收藏夹'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '如：腿部日'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
