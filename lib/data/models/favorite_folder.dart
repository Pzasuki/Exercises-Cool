import 'package:flutter/foundation.dart';

/// 收藏夹：命名 + 收藏的动作 id 列表，持久化到 shared_preferences。
@immutable
class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.exerciseIds,
  });

  final String id;
  final String name;

  /// 收藏的动作 id（exercises.json 的 id 字段），按收藏先后排序。
  final List<String> exerciseIds;

  FavoriteFolder copyWith({String? name, List<String>? exerciseIds}) =>
      FavoriteFolder(
        id: id,
        name: name ?? this.name,
        exerciseIds: exerciseIds ?? this.exerciseIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exerciseIds': exerciseIds,
      };

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) =>
      FavoriteFolder(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        exerciseIds: (json['exerciseIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );
}
