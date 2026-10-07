import 'package:flutter/foundation.dart';

import '../data/models/favorite_folder.dart';
import '../data/repositories/favorites_storage.dart';

/// 收藏夹服务：收藏夹 CRUD 与动作的多夹收藏，持久化委托给
/// [FavoritesStorage]（shared_preferences 键 favoriteFolders）。
/// 存储不可用（如测试环境未注册插件）时退化为内存态。
class FavoritesService extends ChangeNotifier {
  FavoritesService({FavoritesStorage? storage})
      : _storage = storage ?? const FavoritesStorage() {
    _load();
  }

  final FavoritesStorage _storage;

  /// 内置默认收藏夹（用户点收藏直接进这里，无需组织收藏夹）。
  static const String defaultFolderId = 'default';
  static const String defaultFolderName = '默认收藏';

  /// id 生成：时间戳 + 自增序号，避免同一微秒内创建的夹子撞 id。
  static int _idCounter = 0;
  static String get _nextId =>
      '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  List<FavoriteFolder> _folders = [];

  /// 收藏夹列表（新建的排在最后）。
  List<FavoriteFolder> get folders => List.unmodifiable(_folders);

  bool get isEmpty => _folders.isEmpty ||
      _folders.every((f) => f.exerciseIds.isEmpty);

  /// 动作是否已被收藏（在任意收藏夹中）。
  bool isFavorite(String exerciseId) =>
      _folders.any((f) => f.exerciseIds.contains(exerciseId));

  /// 动作所在的收藏夹 id 集合。
  Set<String> folderIdsOf(String exerciseId) => {
        for (final f in _folders)
          if (f.exerciseIds.contains(exerciseId)) f.id,
      };

  /// 新建收藏夹，返回新夹 id。
  String createFolder(String name) {
    final folder = FavoriteFolder(
      id: _nextId,
      name: name,
      exerciseIds: const [],
    );
    _folders = [..._folders, folder];
    _save();
    notifyListeners();
    return folder.id;
  }

  void renameFolder(String folderId, String name) {
    if (folderId == defaultFolderId) return;
    _folders = [
      for (final f in _folders)
        if (f.id == folderId) f.copyWith(name: name) else f,
    ];
    _save();
    notifyListeners();
  }

  /// 删除收藏夹（夹内收藏随删除消失，动作数据本身不受影响）。
  void deleteFolder(String folderId) {
    if (folderId == defaultFolderId) return;
    _folders = _folders.where((f) => f.id != folderId).toList();
    _save();
    notifyListeners();
  }

  /// 把动作加入收藏夹（已在夹内则无变化）。
  void addToFolder(String folderId, String exerciseId) {
    _updateFolder(folderId, (ids) =>
        ids.contains(exerciseId) ? ids : [...ids, exerciseId]);
  }

  /// 从收藏夹移除动作。
  void removeFromFolder(String folderId, String exerciseId) {
    _updateFolder(
        folderId, (ids) => ids.where((id) => id != exerciseId).toList());
  }

  /// 点收藏的默认行为：收进/移出内置「默认收藏」。
  void toggleDefault(String exerciseId) {
    _ensureDefaultFolder();
    toggleInFolder(defaultFolderId, exerciseId);
  }

  void _ensureDefaultFolder() {
    if (_folders.any((f) => f.id == defaultFolderId)) return;
    _folders = [
      const FavoriteFolder(
        id: defaultFolderId,
        name: defaultFolderName,
        exerciseIds: [],
      ),
      ..._folders,
    ];
  }

  /// 切换动作在某收藏夹中的收藏状态。
  void toggleInFolder(String folderId, String exerciseId) {
    _updateFolder(folderId, (ids) => ids.contains(exerciseId)
        ? ids.where((id) => id != exerciseId).toList()
        : [...ids, exerciseId]);
  }

  /// 把动作从 [fromId] 收藏夹移动到 [toId]（源夹移除 + 目标夹加入，
  /// 目标夹已含该动作时只做移除）。
  void moveExercise(String fromId, String toId, String exerciseId) {
    if (fromId == toId) return;
    _folders = [
      for (final f in _folders)
        if (f.id == fromId)
          f.copyWith(
            exerciseIds:
                f.exerciseIds.where((id) => id != exerciseId).toList(),
          )
        else if (f.id == toId)
          f.copyWith(
            exerciseIds: f.exerciseIds.contains(exerciseId)
                ? f.exerciseIds
                : [...f.exerciseIds, exerciseId],
          )
        else
          f,
    ];
    _save();
    notifyListeners();
  }

  void _updateFolder(
      String folderId, List<String> Function(List<String>) update) {
    _folders = [
      for (final f in _folders)
        if (f.id == folderId)
          f.copyWith(exerciseIds: update(f.exerciseIds))
        else
          f,
    ];
    _save();
    notifyListeners();
  }

  Future<void> _load() async {
    _folders = await _storage.loadFolders();
    // 无论是否有存储数据，内置默认收藏夹都要保证存在
    _ensureDefaultFolder();
    notifyListeners();
  }

  /// 持久化当前收藏夹（fire-and-forget，失败由 storage 记日志，不影响内存态）。
  void _save() {
    _storage.saveFolders(_folders);
  }
}
