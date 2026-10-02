import 'package:flutter/foundation.dart';

/// 单条健身动作记录，字段对应 www/data/exercises.json
/// （schema 定义见 docs/exercises.schema.json）。
@immutable
class Exercise {
  // 非 const：searchIndex 需要惰性拼串缓存（见下），const 构造函数
  // 不允许非常量字段初始化器；现有构造路径均经由 fromJson。
  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.bodyPart,
    required this.equipment,
    required this.instructions,
    required this.instructionSteps,
    required this.muscleGroup,
    required this.secondaryMuscles,
    required this.target,
    required this.image,
    required this.gifUrl,
    required this.mediaId,
    required this.createdAt,
    required this.attribution,
  });

  final String id;

  /// 动作名（数据里已是中文）。
  final String name;

  /// 部位分类，与 [bodyPart] 同值（如 "waist"、"chest"）。
  final String category;
  final String bodyPart;
  final String equipment;

  /// 整段说明文字，键为 ISO 639-1 语言码（当前数据仅有 zh）。
  final Map<String, String> instructions;

  /// 分步说明，键为语言码，值为有序步骤数组。
  final Map<String, List<String>> instructionSteps;

  /// 协同肌群。
  final String muscleGroup;
  final List<String> secondaryMuscles;

  /// 主要目标肌肉（如 "abs"、"pectorals"）。
  final String target;

  /// 静态缩略图相对路径，如 `images/0001-2gPfomN.webp`。
  final String image;

  /// 动图相对路径，如 `videos/0001-2gPfomN.webp`（Animated WebP）。
  final String gifUrl;
  final String mediaId;
  final String createdAt;
  final String attribution;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        bodyPart: json['body_part'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        instructions: _stringMap(json['instructions']),
        instructionSteps: _stepsMap(json['instruction_steps']),
        muscleGroup: json['muscle_group'] as String? ?? '',
        secondaryMuscles: _stringList(json['secondary_muscles']),
        target: json['target'] as String? ?? '',
        image: json['image'] as String? ?? '',
        gifUrl: json['gif_url'] as String? ?? '',
        mediaId: json['media_id'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        attribution: json['attribution'] as String? ?? '',
      );

  /// 打包进 assets/ 后的资源键：JSON 里的相对路径统一加 `assets/` 前缀。
  String get thumbnailAsset => 'assets/$image';
  String get animationAsset => 'assets/$gifUrl';

  /// 次要肌群（剔除与主要目标重复的项），对应原版 openModal 里的过滤逻辑。
  List<String> get secondaryMusclesOnly =>
      secondaryMuscles.where((m) => m != target).toList(growable: false);

  /// 搜索索引，对应 JS `_idx = name category target equipment muscle_group`。
  /// 每次筛选变化会对全库做多遍 contains 匹配，缓存为实例字段避免重复拼串
  /// （字段构造后不变，缓存安全）。
  late final String searchIndex =
      '$name $category $target $equipment $muscleGroup'.toLowerCase();
  /// 步骤文案的展示语言（当前数据只有中文；多语言支持见 MIGRATION.md 阶段4）。
  static const String displayLang = 'zh';

  List<String> get displaySteps =>
      instructionSteps[displayLang] ?? const [];

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Map<String, List<String>> _stepsMap(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), _stringList(v)));
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }
}
