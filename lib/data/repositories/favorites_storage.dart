import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_folder.dart';

/// 收藏夹持久化：单个键 favoriteFolders，JSON 数组存 shared_preferences。
/// 读写失败记日志并退化为内存态（存储不可用如测试环境未注册插件时），
/// 不影响 UI 状态。
class FavoritesStorage {
  const FavoritesStorage();

  static const String _prefKey = 'favoriteFolders';

  Future<List<FavoriteFolder>> loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => FavoriteFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('FavoritesStorage.loadFolders failed: $e');
      return const [];
    }
  }

  Future<void> saveFolders(List<FavoriteFolder> folders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(folders.map((f) => f.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('FavoritesStorage.saveFolders failed: $e');
    }
  }
}
