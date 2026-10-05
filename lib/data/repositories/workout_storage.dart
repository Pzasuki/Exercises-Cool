import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout.dart';

/// 训练数据持久化：模板 / 历史 / 默认参数三个键，JSON 编码存
/// shared_preferences。只负责序列化与字节进出，业务状态由
/// WorkoutController 持有；读写失败记日志并退化为内存态 / 默认值
/// （存储不可用如测试环境未注册插件时），不影响 UI 状态。
class WorkoutStorage {
  const WorkoutStorage();

  static const String _templateKey = 'workoutTemplates';
  static const String _historyKey = 'workoutHistory';
  static const String _defaultsKey = 'workoutDefaults';

  Future<List<WorkoutTemplate>> loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_templateKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('WorkoutStorage.loadTemplates failed: $e');
      return const [];
    }
  }

  Future<void> saveTemplates(List<WorkoutTemplate> templates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _templateKey,
        jsonEncode(templates.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('WorkoutStorage.saveTemplates failed: $e');
    }
  }

  Future<List<WorkoutRecord>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => WorkoutRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('WorkoutStorage.loadHistory failed: $e');
      return const [];
    }
  }

  Future<void> saveHistory(List<WorkoutRecord> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        jsonEncode(history.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('WorkoutStorage.saveHistory failed: $e');
    }
  }

  Future<WorkoutDefaults> loadDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_defaultsKey);
      if (raw == null) return const WorkoutDefaults();
      return WorkoutDefaults.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('WorkoutStorage.loadDefaults failed: $e');
      return const WorkoutDefaults();
    }
  }

  Future<void> saveDefaults(WorkoutDefaults defaults) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultsKey, jsonEncode(defaults.toJson()));
    } catch (e) {
      debugPrint('WorkoutStorage.saveDefaults failed: $e');
    }
  }
}
