import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/zh_terms.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/exercise.dart';
import '../../state/favorites_service.dart';
import '../../state/library_controller.dart';
import '../detail/exercise_detail_sheet.dart';

/// 收藏 Tab：收藏夹列表 → 夹内动作管理（新建/重命名/删除收藏夹，
/// 从夹内移除动作、查看动作详情）。收藏动作的入口在详情弹窗的收藏按钮。
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FavoritesService>();
    final folders = service.folders;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onCreate: () => _createFolderDialog(context)),
            Expanded(
              child: folders.isEmpty
                  // 服务异步加载完成前 folders 为空，默认夹加载后必然出现
                  ? const _EmptyHint(text: '加载中…')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final isDefault =
                            folder.id == FavoritesService.defaultFolderId;
                        return _FolderTile(
                          name: folder.name,
                          count: folder.exerciseIds.length,
                          onTap: () => _openFolder(context, folder.id),
                          onRename: isDefault
                              ? null
                              : () => _renameFolderDialog(
                                  context, folder.id, folder.name),
                          onDelete: isDefault
                              ? null
                              : () => _deleteFolderDialog(context, folder.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFolder(BuildContext context, String folderId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FolderDetailScreen(folderId: folderId),
      ),
    );
  }

  Future<void> _createFolderDialog(BuildContext context) async {
    final name = await _nameDialog(context, title: '新建收藏夹', hint: '如：腿部日');
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    context.read<FavoritesService>().createFolder(name.trim());
  }

  Future<void> _renameFolderDialog(
      BuildContext context, String folderId, String current) async {
    final name = await _nameDialog(
      context,
      title: '重命名收藏夹',
      hint: '名称',
      initial: current,
    );
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    context.read<FavoritesService>().renameFolder(folderId, name.trim());
  }

  Future<void> _deleteFolderDialog(BuildContext context, String folderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: const Text('夹内收藏的动作将一并移除，确定删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    context.read<FavoritesService>().deleteFolder(folderId);
  }
}

/// 收藏夹名称输入弹窗，返回 null 表示取消。
Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
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

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            '我的收藏',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onCreate,
            icon: const Icon(Icons.create_new_folder_outlined,
                size: 22, color: AppColors.textSecondary),
            tooltip: '新建收藏夹',
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.count,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  final String name;
  final int count;
  final VoidCallback onTap;

  /// 内置「默认收藏」不可重命名/删除，传 null 时隐藏管理菜单。
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.folder_outlined,
            size: 24, color: AppColors.accent),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$count 个动作',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: onRename == null && onDelete == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') onRename!();
                  if (v == 'delete') onDelete!();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
      ),
    );
  }
}

/// 收藏夹内动作列表。
class _FolderDetailScreen extends StatelessWidget {
  const _FolderDetailScreen({required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FavoritesService>();
    final library = context.watch<LibraryController>();
    final folder = service.folders.where((f) => f.id == folderId).firstOrNull;
    if (folder == null) {
      // 收藏夹已被删除（正常操作路径不会发生），下一帧返回列表
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final exercises = [
      for (final id in folder.exerciseIds) ?library.byId(id),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: Text(folder.name),
        backgroundColor: AppColors.bgSurface,
      ),
      body: exercises.isEmpty
          ? const _EmptyHint(text: '收藏夹还是空的\n在动作详情里把它加进来')
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: exercises.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ex = exercises[index];
                return _FolderExerciseTile(
                  exercise: ex,
                  onTap: () => showExerciseDetail(context, ex),
                  onRemove: () =>
                      context.read<FavoritesService>().removeFromFolder(
                            folderId,
                            ex.id,
                          ),
                );
              },
            ),
    );
  }
}

class _FolderExerciseTile extends StatelessWidget {
  const _FolderExerciseTile({
    required this.exercise,
    required this.onTap,
    required this.onRemove,
  });

  final Exercise exercise;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          child: Image.asset(
            ex.thumbnailAsset,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.bgElevated),
          ),
        ),
        title: Text(
          ex.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${zh(ex.target)} · ${zh(ex.equipment)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
          tooltip: '从收藏夹移除',
        ),
      ),
    );
  }
}
