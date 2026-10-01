import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/exercise.dart';

/// 动作数据仓库：当前从打包的 assets 读取；
/// 未来换数据库/远端接口时只需替换此实现（见 MIGRATION.md 阶段6）。
class ExerciseRepository {
  const ExerciseRepository();

  static const String _assetPath = 'assets/data/exercises.json';

  /// 读取并解析全部动作。JSON 约 1.8MB，解析放到后台 isolate
  /// （Web 平台 compute 会自动回退到主线程执行）。
  Future<List<Exercise>> loadAll() async {
    final String raw = await rootBundle.loadString(_assetPath);
    return compute(_parseExercises, raw);
  }

  static List<Exercise> _parseExercises(String raw) {
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
