import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../data/models/workout.dart';
import '../data/repositories/workout_storage.dart';

/// 训练页状态机：idle（模板 + 开始入口）→ planning（挑动作/设组次）→
/// running（逐动作做组打点，组间可选倒计时）→ finished（总结/存模板）。
/// 业务状态全部私有（只读 getter 开放给 UI，写入只能走方法，防止绕过
/// 状态机）；持久化委托给 [WorkoutStorage]（shared_preferences）。
class WorkoutController extends ChangeNotifier {
  WorkoutController({WorkoutStorage? storage})
      : _storage = storage ?? const WorkoutStorage() {
    _loadTemplates();
    _loadHistory();
    _loadDefaults();
  }

  final WorkoutStorage _storage;

  /// id 生成：时间戳 + 自增序号，避免同一微秒内保存的模板撞 id。
  static int _idCounter = 0;
  static String get _nextId =>
      't${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  WorkoutStatus _status = WorkoutStatus.idle;

  /// 状态机当前阶段（训练页据此分流四种视图）。
  WorkoutStatus get status => _status;

  List<WorkoutTemplate> _templates = [];

  /// 训练模板列表。
  List<WorkoutTemplate> get templates => List.unmodifiable(_templates);

  List<WorkoutRecord> _history = [];

  /// 历史训练记录（新的在前）。
  List<WorkoutRecord> get history => List.unmodifiable(_history);

  String _feeling = '刚好';

  /// 总结页的训练感受选择（存入历史记录）。
  String get feeling => _feeling;

  DateTime? _sessionStartedAt;

  /// 训练时长（秒），未开始为 0。
  int get sessionDurationSeconds {
    final start = _sessionStartedAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  WorkoutDefaults _defaults = const WorkoutDefaults();

  /// 用户默认训练参数（首次添加动作时引导设置，之后添加的动作自动套用）。
  int get defaultSets => _defaults.sets;
  int get defaultReps => _defaults.reps;
  double? get defaultWeight => _defaults.weight;
  bool get defaultsConfigured => _defaults.configured;

  /// 规划中/执行中的动作清单（同一个列表，进入 running 后加 completedSets）。
  List<SessionEntry> _session = [];
  List<SessionEntry> get session => List.unmodifiable(_session);
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  int _restSeconds = 0;

  /// 组间间歇秒数，0 = 关闭倒计时。
  int get restSeconds => _restSeconds;
  bool _resting = false;
  bool get resting => _resting;
  int _restRemaining = 0;
  int get restRemaining => _restRemaining;

  /// 休息的墙钟结束时刻。每秒 tick 据此重算剩余，而不是逐次减一：
  /// app 切后台约十几秒后进程会被系统冻结（App Freezer / 厂商省电），
  /// Timer 停摆——恢复后的第一笔补偿 tick 按墙钟对齐，倒计时不残留
  /// 冻结时刻的旧值，到点判定也不会被冻结时长拖后。
  DateTime? _restEndsAt;

  /// 与 RestAlarmService._backupGraceSeconds 同值：兜底通知比本机响铃
  /// 晚 3 秒，晚于它才判定「兜底已提醒过」。
  static const int _backupGraceMs = 3000;

  /// 最近一次休息结束的原因：自然走完（completed，到点响铃提醒）或
  /// 被用户跳过/训练结束（skipped，静默撤销通知不出声）。
  RestEndReason _restEndReason = RestEndReason.completed;
  RestEndReason get restEndReason => _restEndReason;
  Timer? _restTimer;

  SessionEntry get currentEntry =>
      _session.isEmpty ? throw StateError('no session') : _session[_currentIndex];

  /// 当前动作是否为清单最后一个。
  bool get isLastEntry => _currentIndex == _session.length - 1;

  int get totalSetsDone =>
      _session.fold(0, (sum, e) => sum + e.completedSets);

  /// 组间倒计时分钟数（1 分钟起，规划页步进器用）。
  int get restMinutes => _restSeconds <= 0 ? 0 : (_restSeconds / 60).ceil();

  // ── 规划 ──

  void startPlanning() {
    _status = WorkoutStatus.planning;
    _session = [];
    _currentIndex = 0;
    _resting = false;
    _restRemaining = 0;
    _restEndsAt = null;
    _stopRestTimer();
    notifyListeners();
  }

  void cancelPlanning() {
    _status = WorkoutStatus.idle;
    _session = [];
    notifyListeners();
  }

  void addExercise(String exerciseId) {
    _session = [
      ..._session,
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
    _defaults = WorkoutDefaults(
      sets: sets,
      reps: reps,
      weight: weight,
      configured: true,
    );
    _session = [
      for (final e in _session)
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
    _defaults = _defaults.copyWith(configured: true);
    _saveDefaults();
    notifyListeners();
  }

  void removeEntry(int index) {
    _session = List.of(_session)..removeAt(index);
    if (_currentIndex >= _session.length) _currentIndex = _session.length - 1;
    if (_session.isEmpty) _currentIndex = 0;
    notifyListeners();
  }

  void moveEntry(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _session.length) return;
    _session = List.of(_session);
    final entry = _session.removeAt(index);
    _session.insert(target, entry);
    notifyListeners();
  }

  void updateEntry(
    int index, {
    int? sets,
    int? reps,
    double? weight,
    bool clearWeight = false,
  }) {
    _session = [
      for (var i = 0; i < _session.length; i++)
        if (i == index)
          _session[i].copyWith(
            sets: sets,
            reps: reps,
            weight: weight,
            clearWeight: clearWeight,
          )
        else
          _session[i],
    ];
    notifyListeners();
  }

  void setRestSeconds(int seconds) {
    _restSeconds = seconds < 0 ? 0 : seconds;
    notifyListeners();
  }

  void setRestMinutes(int minutes) {
    if (minutes < 1) minutes = 1;
    if (minutes > 10) minutes = 10;
    _restSeconds = minutes * 60;
    notifyListeners();
  }

  /// 总结页切换训练感受。
  void setFeeling(String value) {
    _feeling = value;
    notifyListeners();
  }

  // ── 执行 ──

  void startSession() {
    if (_session.isEmpty) return;
    _status = WorkoutStatus.running;
    _sessionStartedAt = DateTime.now();
    _feeling = '刚好';
    _currentIndex = 0;
    for (var i = 0; i < _session.length; i++) {
      _session[i] = _session[i].copyWith(clearProgress: true);
    }
    notifyListeners();
  }

  /// 完成当前动作的一组：进度 +1；未做完 → 视设置进入间歇倒计时；
  /// 做完 → 自动切到下一个动作（或结束）。
  void completeSet() {
    if (_status != WorkoutStatus.running || _resting) return;
    final entry = _session[_currentIndex];
    if (entry.completedSets >= entry.sets) return;
    _session[_currentIndex] =
        entry.copyWith(completedSets: entry.completedSets + 1);
    final updated = _session[_currentIndex];
    if (updated.completedSets >= updated.sets) {
      _advance();
    } else if (_restSeconds > 0) {
      _startRest();
    }
    notifyListeners();
  }

  /// 跳过当前动作剩余组数，进入下一个动作。
  void skipExercise() {
    if (_status != WorkoutStatus.running) return;
    _session[_currentIndex] = _session[_currentIndex]
        .copyWith(completedSets: _session[_currentIndex].sets);
    _restEndReason = RestEndReason.skipped;
    _advance();
    notifyListeners();
  }

  /// 执行中提前结束 → 总结页（已完成的组数保留，可存模板）。
  void abandonSession() {
    _stopRestTimer();
    _resting = false;
    _restRemaining = 0;
    _restEndsAt = null;
    _restEndReason = RestEndReason.skipped;
    _status = WorkoutStatus.finished;
    notifyListeners();
  }

  void _advance() {
    _stopRestTimer();
    _resting = false;
    _restRemaining = 0;
    _restEndsAt = null;
    if (isLastEntry) {
      _status = WorkoutStatus.finished;
    } else {
      _currentIndex++;
    }
  }

  // ── 间歇倒计时 ──

  /// tick 频率。刻意高于 1 秒：`Timer.periodic` 只会**晚于**预定时刻触发
  /// （事件循环调度开销），误差单调累积；若按 1 秒 tick，取整后的读数每积累
  /// 满 1 秒才跳一次，界面表现为「卡住数秒再跳 1 秒」。tick 越小，读数越紧贴
  /// 墙钟（显示滞后 < 一个 tick），且只在整数秒变化时 notify，开销仍为每秒一次。
  static const Duration _restTickInterval = Duration(milliseconds: 200);

  void _startRest() {
    _resting = true;
    _restRemaining = _restSeconds;
    _restEndsAt = clock.now().add(Duration(seconds: _restSeconds));
    _restEndReason = RestEndReason.completed;
    _stopRestTimer();
    _restTimer = Timer.periodic(_restTickInterval, (_) => _tickRest());
  }

  /// 按墙钟结束时刻重算剩余并刷新；已到点则结束本次休息。
  ///
  /// 到点晚于 [_backupGraceMs]（进程冻结期间错过、恢复后才跑到的补偿
  /// tick）→ 兜底通知应已提醒过，置 expiredInBackground 静默收尾；
  /// 否则视为前台正常到点，保持 completed 由桥接本机响铃（主路径）。
  void _tickRest() {
    final end = _restEndsAt;
    if (end == null || !_resting) return;
    final remainingMs = end.difference(clock.now()).inMilliseconds;
    if (remainingMs <= 0) {
      _stopRestTimer();
      _resting = false;
      _restRemaining = 0;
      _restEndReason = remainingMs <= -_backupGraceMs
          ? RestEndReason.expiredInBackground
          : RestEndReason.completed;
      notifyListeners();
      return;
    }
    // 向上取整：起始整分钟显示 1:00 而不是 0:59
    final remaining = (remainingMs / 1000).ceil();
    if (remaining != _restRemaining) {
      _restRemaining = remaining;
      notifyListeners();
    }
  }

  void skipRest() {
    _stopRestTimer();
    _resting = false;
    _restRemaining = 0;
    _restEndsAt = null;
    _restEndReason = RestEndReason.skipped;
    notifyListeners();
  }

  void addRestTime(int seconds) {
    if (!_resting) return;
    _restRemaining += seconds;
    _restEndsAt = _restEndsAt?.add(Duration(seconds: seconds));
    notifyListeners();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  // ── 模板 ──

  /// 把当前清单存为模板（执行结束后的总结页或规划页调用）。
  void saveTemplate(String name) {
    if (_session.isEmpty) return;
    final template = WorkoutTemplate(
      id: _nextId,
      name: name,
      entries: [
        for (final e in _session)
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
    _planFromEntries(template.entries);
  }

  /// 用一次历史训练的内容重新开始规划（组数/次数/重量按当时的计划值，
  /// 完成进度清零），可再调整后开始训练。
  void repeatRecord(String id) {
    final record = _history.where((r) => r.id == id).firstOrNull;
    if (record == null) return;
    _planFromEntries(record.entries);
  }

  /// 用一份既定计划（模板或历史记录的条目）开始规划：组/次/重量按计划值，
  /// 完成进度清零，可再调整后开始训练。
  void _planFromEntries(List<WorkoutPlanEntry> entries) {
    _status = WorkoutStatus.planning;
    _session = [for (final e in entries) SessionEntry.fromPlan(e)];
    _currentIndex = 0;
    notifyListeners();
  }

  /// 总结页确认「完成」：把本次训练写入历史（按当前 [feeling]），
  /// 有实际完成组数的动作才会记录；随后回到 idle。
  void finishAndSave() {
    if (_status != WorkoutStatus.finished) return;
    final done = [
      for (final e in _session)
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
          feeling: _feeling,
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
    _status = WorkoutStatus.idle;
    _session = [];
    _currentIndex = 0;
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
    _templates = await _storage.loadTemplates();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    _history = await _storage.loadHistory();
    notifyListeners();
  }

  Future<void> _loadDefaults() async {
    _defaults = await _storage.loadDefaults();
    notifyListeners();
  }

  void _saveTemplates() {
    _storage.saveTemplates(_templates);
  }

  void _saveHistory() {
    _storage.saveHistory(_history);
  }

  void _saveDefaults() {
    _storage.saveDefaults(_defaults);
  }

  @override
  void dispose() {
    _stopRestTimer();
    super.dispose();
  }
}

enum WorkoutStatus { idle, planning, running, finished }

/// 一次休息的结束方式：
/// completed 自然走完（桥接本机响铃主路径，并撤销未触发的兜底）；
/// skipped 被用户跳过/随训练结束（静默撤销不出声）；
/// expiredInBackground 在后台冻结期间到点、恢复后才判定（兜底通知应已
/// 提醒过，仅撤常驻倒计时通知，保留到点提醒，不重复响铃）。
enum RestEndReason { completed, skipped, expiredInBackground }

/// 一次训练中的一条动作（含执行进度）。
class SessionEntry {
  SessionEntry({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    this.completedSets = 0,
    this.weight,
  });

  /// 从既定计划条目（模板或历史记录）创建，完成进度清零。
  factory SessionEntry.fromPlan(WorkoutPlanEntry entry) => SessionEntry(
        exerciseId: entry.exerciseId,
        sets: entry.sets,
        reps: entry.reps,
        weight: entry.weight,
      );

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
