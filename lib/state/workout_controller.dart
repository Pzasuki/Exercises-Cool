import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/workout.dart';

/// 训练页状态机：idle（模板 + 开始入口）→ planning（挑动作/设组次）→
/// running（逐动作做组打点，组间可选倒计时）→ finished（总结/存模板）。
/// 模板持久化到 shared_preferences（键 workoutTemplates）。
class WorkoutController extends ChangeNotifier {
  WorkoutController() {
    _loadTemplates();
    _loadHistory();
    _loadDefaults();
  }

  static const String _prefKey = 'workoutTemplates';
  static const String _historyKey = 'workoutHistory';
  static const String _defaultsKey = 'workoutDefaults';

  /// id 生成：时间戳 + 自增序号，避免同一微秒内保存的模板撞 id。
  static int _idCounter = 0;
  static String get _nextId =>
      't${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  List<WorkoutTemplate> _templates = [];
  List<WorkoutTemplate> get templates => List.unmodifiable(_templates);

  /// 历史训练记录（新的在前）。
  List<WorkoutRecord> _history = [];
  List<WorkoutRecord> get history => List.unmodifiable(_history);

  /// 总结页的训练感受选择（存入历史记录）。
  String feeling = '刚好';

  DateTime? _sessionStartedAt;

  /// 用户默认训练参数（首次添加动作时引导设置，之后添加的动作自动套用）。
  int defaultSets = 3;
  int defaultReps = 10;
  double? defaultWeight;
  bool defaultsConfigured = false;

  /// 训练时长（秒），未开始为 0。
  int get sessionDurationSeconds {
    final start = _sessionStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  WorkoutStatus status = WorkoutStatus.idle;

  /// 规划中/执行中的动作清单（同一个列表，进入 running 后加 completedSets）。
  List<SessionEntry> session = [];
  int currentIndex = 0;

  /// 组间间歇秒数，0 = 关闭倒计时。
  int restSeconds = 0;
  bool resting = false;
  int restRemaining = 0;
  Timer? _restTimer;

  SessionEntry get currentEntry =>
      session.isEmpty ? throw StateError('no session') : session[currentIndex];

  /// 当前动作是否为清单最后一个。
  bool get isLastEntry => currentIndex == session.length - 1;

  int get totalSetsDone =>
      session.fold(0, (sum, e) => sum + e.completedSets);

  // ── 规划 ──

  void startPlanning() {
    status = WorkoutStatus.planning;
    session = [];
    currentIndex = 0;
    resting = false;
    restRemaining = 0;
    _stopRestTimer();
    notifyListeners();
  }

  void cancelPlanning() {
    status = WorkoutStatus.idle;
    session = [];
    notifyListeners();
  }

  void addExercise(String exerciseId) {
    session = [
      ...session,
      SessionEntry(
        exerciseId: exerciseId,
        sets: defaultSets,
        reps: defaultReps,
        weight: defaultWeight,
      ),
    ];
    notifyListeners();
  }

  /// 首次引导：保存默认参数并套用到当前清单里未手动改过的动作。
  void saveDefaults({
    required int sets,
    required int reps,
    double? weight,
  }) {
    defaultSets = sets;
    defaultReps = reps;
    defaultWeight = weight;
    defaultsConfigured = true;
    session = [
      for (final e in session)
        e.copyWith(
          sets: sets,
          reps: reps,
          weight: weight,
          clearWeight: weight == null,
        ),
    ];
    _saveDefaults();
    notifyListeners();
  }

  /// 首次引导点「跳过」：保留 3 组 × 10 次，之后不再提示。
  void skipDefaultsSetup() {
    defaultsConfigured = true;
    _saveDefaults();
    notifyListeners();
  }

  Future<void> _loadDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_defaultsKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      defaultSets = (json['sets'] as num?)?.toInt() ?? 3;
      defaultReps = (json['reps'] as num?)?.toInt() ?? 10;
      defaultWeight = (json['weight'] as num?)?.toDouble();
      defaultsConfigured = json['configured'] as bool? ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultsKey, jsonEncode({
        'sets': defaultSets,
        'reps': defaultReps,
        if (defaultWeight != null) 'weight': defaultWeight,
        'configured': defaultsConfigured,
      }));
    } catch (_) {}
  }

  void removeEntry(int index) {
    session = List.of(session)..removeAt(index);
    if (currentIndex >= session.length) currentIndex = session.length - 1;
    if (session.isEmpty) currentIndex = 0;
    notifyListeners();
  }

  void moveEntry(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= session.length) return;
    session = List.of(session);
    final entry = session.removeAt(index);
    session.insert(target, entry);
    notifyListeners();
  }

  void updateEntry(
    int index, {
    int? sets,
    int? reps,
    double? weight,
    bool clearWeight = false,
  }) {
    session = [
      for (var i = 0; i < session.length; i++)
        if (i == index)
          session[i].copyWith(
            sets: sets,
            reps: reps,
            weight: weight,
            clearWeight: clearWeight,
          )
        else
          session[i],
    ];
    notifyListeners();
  }

  void setRestSeconds(int seconds) {
    restSeconds = seconds < 0 ? 0 : seconds;
    notifyListeners();
  }

  /// 组间倒计时分钟数（1 分钟起，规划页步进器用）。
  int get restMinutes => restSeconds <= 0 ? 0 : (restSeconds / 60).ceil();

  void setRestMinutes(int minutes) {
    if (minutes < 1) minutes = 1;
    if (minutes > 10) minutes = 10;
    restSeconds = minutes * 60;
    notifyListeners();
  }

  /// 总结页切换训练感受。
  void setFeeling(String value) {
    feeling = value;
    notifyListeners();
  }

  // ── 执行 ──

  void startSession() {
    if (session.isEmpty) return;
    status = WorkoutStatus.running;
    _sessionStartedAt = DateTime.now();
    feeling = '刚好';
    currentIndex = 0;
    for (var i = 0; i < session.length; i++) {
      session[i] = session[i].copyWith(clearProgress: true);
    }
    notifyListeners();
  }

  /// 完成当前动作的一组：进度 +1；未做完 → 视设置进入间歇倒计时；
  /// 做完 → 自动切到下一个动作（或结束）。
  void completeSet() {
    if (status != WorkoutStatus.running || resting) return;
    final entry = session[currentIndex];
    if (entry.completedSets >= entry.sets) return;
    session[currentIndex] = entry.copyWith(completedSets: entry.completedSets + 1);
    final updated = session[currentIndex];
    if (updated.completedSets >= updated.sets) {
      _advance();
    } else if (restSeconds > 0) {
      _startRest();
    }
    notifyListeners();
  }

  /// 跳过当前动作剩余组数，进入下一个动作。
  void skipExercise() {
    if (status != WorkoutStatus.running) return;
    session[currentIndex] =
        session[currentIndex].copyWith(completedSets: session[currentIndex].sets);
    _advance();
    notifyListeners();
  }

  /// 执行中提前结束 → 总结页（已完成的组数保留，可存模板）。
  void abandonSession() {
    _stopRestTimer();
    resting = false;
    restRemaining = 0;
    status = WorkoutStatus.finished;
    notifyListeners();
  }

  void _advance() {
    _stopRestTimer();
    resting = false;
    restRemaining = 0;
    if (isLastEntry) {
      status = WorkoutStatus.finished;
    } else {
      currentIndex++;
    }
  }

  // ── 间歇倒计时 ──

  void _startRest() {
    resting = true;
    restRemaining = restSeconds;
    _stopRestTimer();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (restRemaining <= 1) {
        _stopRestTimer();
        resting = false;
        restRemaining = 0;
      } else {
        restRemaining--;
      }
      notifyListeners();
    });
  }

  void skipRest() {
    _stopRestTimer();
    resting = false;
    restRemaining = 0;
    notifyListeners();
  }

  void addRestTime(int seconds) {
    if (!resting) return;
    restRemaining += seconds;
    notifyListeners();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  // ── 模板 ──

  /// 把当前清单存为模板（执行结束后的总结页或规划页调用）。
  void saveTemplate(String name) {
    if (session.isEmpty) return;
    final template = WorkoutTemplate(
      id: _nextId,
      name: name,
      entries: [
        for (final e in session)
          PlanEntry(
            exerciseId: e.exerciseId,
            sets: e.sets,
            reps: e.reps,
            weight: e.weight,
          ),
      ],
      createdAt: DateTime.now().toIso8601String(),
    );
    _templates = [..._templates, template];
    _saveTemplates();
    notifyListeners();
  }

  void deleteTemplate(String id) {
    _templates = _templates.where((t) => t.id != id).toList();
    _saveTemplates();
    notifyListeners();
  }

  /// 用模板内容开始规划（可再调整后开始训练）。
  void loadTemplate(String id) {
    final template = _templates.where((t) => t.id == id).firstOrNull;
    if (template == null) return;
    status = WorkoutStatus.planning;
    session = [
      for (final e in template.entries)
        SessionEntry(
          exerciseId: e.exerciseId,
          sets: e.sets,
          reps: e.reps,
          weight: e.weight,
        ),
    ];
    currentIndex = 0;
    notifyListeners();
  }

  /// 总结页确认「完成」：把本次训练写入历史（按当前 [feeling]），
  /// 有实际完成组数的动作才会记录；随后回到 idle。
  void finishAndSave() {
    if (status != WorkoutStatus.finished) return;
    final done = [
      for (final e in session)
        if (e.completedSets > 0)
          WorkoutRecordEntry(
            exerciseId: e.exerciseId,
            sets: e.sets,
            reps: e.reps,
            completedSets: e.completedSets,
            weight: e.weight,
          ),
    ];
    if (done.isNotEmpty) {
      _history = [
        WorkoutRecord(
          id: _nextId,
          dateIso: DateTime.now().toIso8601String(),
          durationSeconds: sessionDurationSeconds,
          feeling: feeling,
          entries: done,
        ),
        ..._history,
      ];
      _saveHistory();
    }
    backToIdle();
  }

  /// 总结页「不保存」直接退出（不写入历史）。
  void backToIdle() {
    status = WorkoutStatus.idle;
    session = [];
    currentIndex = 0;
    _sessionStartedAt = null;
    notifyListeners();
  }

  /// 删除一条历史训练。
  void deleteRecord(String id) {
    _history = _history.where((r) => r.id != id).toList();
    _saveHistory();
    notifyListeners();
  }

  Future<void> _loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      _templates = (jsonDecode(raw) as List<dynamic>)
          .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(_templates.map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;
      _history = (jsonDecode(raw) as List<dynamic>)
          .map((e) => WorkoutRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        jsonEncode(_history.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopRestTimer();
    super.dispose();
  }
}

enum WorkoutStatus { idle, planning, running, finished }

/// 一次训练中的一条动作（含执行进度）。
class SessionEntry {
  SessionEntry({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.completedSets = 0,
    this.weight,
  });

  final String exerciseId;
  int sets;
  int reps;

  /// 训练重量（kg），可选。
  double? weight;
  int completedSets;

  SessionEntry copyWith({
    int? sets,
    int? reps,
    int? completedSets,
    double? weight,
    bool clearProgress = false,
    bool clearWeight = false,
  }) =>
      SessionEntry(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        weight: clearWeight ? null : (weight ?? this.weight),
        completedSets: clearProgress ? 0 : (completedSets ?? this.completedSets),
      );
}
