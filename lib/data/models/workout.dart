import 'package:flutter/foundation.dart';

/// 训练计划里的一条动作：做几组、每组几次、可选重量（kg）。
@immutable
class PlanEntry {
  const PlanEntry({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.weight,
  });

  final String exerciseId;
  final int sets;
  final int reps;

  /// 训练重量（kg），可选——null 表示未设置。
  final double? weight;

  PlanEntry copyWith({int? sets, int? reps, double? weight}) => PlanEntry(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        weight: weight ?? this.weight,
      );

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        if (weight != null) 'weight': weight,
      };

  factory PlanEntry.fromJson(Map<String, dynamic> json) => PlanEntry(
        exerciseId: json['exerciseId'] as String? ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        reps: (json['reps'] as num?)?.toInt() ?? 10,
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

/// 训练模板：保存的动作清单（组数×次数），供下次训练复用。
@immutable
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.entries,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<PlanEntry> entries;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      WorkoutTemplate(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        entries: (json['entries'] as List<dynamic>? ?? const [])
            .map((e) => PlanEntry.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        createdAt: json['createdAt'] as String? ?? '',
      );
}

/// 历史训练记录里的单条动作完成情况。
@immutable
class WorkoutRecordEntry {
  const WorkoutRecordEntry({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.completedSets,
    this.weight,
  });

  final String exerciseId;
  final int sets;
  final int reps;
  final int completedSets;
  final double? weight;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        'reps': reps,
        'completedSets': completedSets,
        if (weight != null) 'weight': weight,
      };

  factory WorkoutRecordEntry.fromJson(Map<String, dynamic> json) =>
      WorkoutRecordEntry(
        exerciseId: json['exerciseId'] as String? ?? '',
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        completedSets: (json['completedSets'] as num?)?.toInt() ?? 0,
        weight: (json['weight'] as num?)?.toDouble(),
      );
}

/// 一次历史训练：时间、时长、动作完成情况、训练感受（强度自评）。
@immutable
class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.dateIso,
    required this.durationSeconds,
    required this.feeling,
    required this.entries,
  });

  final String id;

  /// 结束时间（ISO 8601）。
  final String dateIso;
  final int durationSeconds;

  /// 训练感受（轻松 / 刚好 / 有点累 / 很累）。
  final String feeling;
  final List<WorkoutRecordEntry> entries;

  int get totalSetsDone =>
      entries.fold(0, (sum, e) => sum + e.completedSets);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateIso': dateIso,
        'durationSeconds': durationSeconds,
        'feeling': feeling,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
        id: json['id'] as String? ?? '',
        dateIso: json['dateIso'] as String? ?? '',
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        feeling: json['feeling'] as String? ?? '刚好',
        entries: (json['entries'] as List<dynamic>? ?? const [])
            .map((e) => WorkoutRecordEntry.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
