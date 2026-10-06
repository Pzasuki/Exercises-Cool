import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/formatters.dart';
import '../state/workout_controller.dart';

/// 组间休息到点的提醒，分前台服务与 Dart 降级两条路线：
///
/// **主路径（原生前台服务）**：休息开始时优先启动 [RestCountdownService]，
/// 通知栏倒计时由系统 Chronometer 渲染（进程冻结也照走，到点即停不出现
/// 负数），到点提醒由服务自身的到点动作负责（heads-up 弹窗 + 闹铃声 +
/// 震动，进程被杀后由 AlarmManager 触发的 RestEndReceiver 兜底）——
/// 整条链路不依赖 Dart 存活。Dart 侧每秒 tick 只负责 app 内界面。
///
/// **降级路径（服务不可用/测试环境）**：Dart 自管通知，三层保证可靠：
///
/// 1. **本机直接响铃（主路径）**：app 存活时倒计时由 Dart 驱动，走完的瞬间
///    通过 MethodChannel 直接播放系统默认闹铃声（RingtoneManager，走闹钟
///    音量）并波形震动——不依赖任何闹钟权限，前台后台都即时可靠。
/// 2. **后台弹出通知**：app 在后台时用户看不到界面，到点除响铃外再弹一条
///    「休息结束」heads-up 通知（渠道本身静音，声音仍由主路径负责，
///    避免双重铃声）。
/// 3. **系统通知（兜底路径）**：休息开始时预约一条到点通知（精确闹钟，
///    不行则退化为非精确），app 被杀/冻结后由 AlarmManager 触发；铃声同样
///    用用户设置的默认闹铃声。预约时间多加 3 秒余量：本机响铃总是先于它，
///    本机路径正常时会把它撤掉，避免双重提醒；仅当 Dart 进程无法运行时
///    它才触发。
///
/// 铃声 = 手机当前设置的默认闹铃音效（未设置则回退通知声/铃声）。
class RestAlarmService with WidgetsBindingObserver {
  RestAlarmService._() {
    // 跟踪前后台：决定到点时除响铃外是否弹「休息结束」通知
    WidgetsBinding.instance.addObserver(this);
  }

  static final RestAlarmService instance = RestAlarmService._();

  static const int _ongoingId = 1;
  static const int _alertId = 2;
  static const String _ongoingChannel = 'rest_countdown_v2';

  /// 通知点击「打开训练页」回调（HomeShell 注册；原生经
  /// rest_alarm 通道转发 openWorkoutTab 触发）。
  static void Function()? onOpenWorkoutRequested;

  /// 提醒渠道 v3：**静音**渠道——到点的声音与震动由原生 AlarmRinger 直接
  /// 播放（不依赖通知权限），渠道只承担视觉部分；v2 曾带铃声但创建后不可改。
  static const String _alertChannel = 'rest_alert_v3';

  /// 后台到点的弹出通知渠道：max 重要级触发 heads-up 横幅，但渠道本身
  /// 静音——声音由本机响铃主路径负责（渠道声音创建后不可改，单独开渠道）。
  static const String _popupChannel = 'rest_alert_popup_v1';

  static const MethodChannel _native = MethodChannel('rest_alarm');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 用户点按提醒通知时的回调（HomeShell 注册：切到「训练」Tab）。
  /// 与 [onOpenWorkoutRequested] 同义（两个入口并存，先后注册互不冲突）。
  static void Function()? onNotificationTap;

  /// 冷启动时（Dart 尚未注册回调前）收到的「打开训练页」请求缓存。
  bool _pendingOpenWorkout = false;

  /// 尽早安装原生回调：app 由通知点回（冷启动）时，原生侧会推送
  /// openWorkoutTab，必须在 main() 里最先调用本方法。
  void prewarm() {
    _native.setMethodCallHandler((call) async {
      if (call.method == 'openWorkoutTab') {
        _pendingOpenWorkout = true;
        onOpenWorkoutRequested?.call();
        onNotificationTap?.call();
      }
      return null;
    });
  }

  /// 取走缓存的「打开训练页」请求（HomeShell 初始化时消费）。
  bool consumePendingOpenWorkout() {
    final value = _pendingOpenWorkout;
    _pendingOpenWorkout = false;
    return value;
  }

  /// 原生前台服务是否已接管本次倒计时（通知栏 chronometer + 到点闹钟）。
  /// 服务不可用时为 false，走 Dart 自管通知的降级路径。
  bool _serviceActive = false;

  /// app 是否不在前台（paused/inactive/detached 都算）：到点时前台界面
  /// 可见、响铃即可；后台需要额外弹出「休息结束」通知告知用户。
  bool _isAppBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppBackground = state != AppLifecycleState.resumed;
  }

  /// 兜底通知是否已预约成功。
  bool _alertScheduled = false;

  /// 通知权限是否被拒（Android 13+ 未授予 POST_NOTIFICATIONS）。
  /// 被拒时系统会静默丢弃所有通知——常驻倒计时、到点弹窗、铃声与震动
  /// 全部失效且不给任何报错，因此需要在 UI 侧显式提示用户去开启。
  bool _notificationsBlocked = false;

  /// 通知被系统拒绝（未授予 POST_NOTIFICATIONS）时为 true。
  bool get notificationsBlocked => _notificationsBlocked;

  int _totalSeconds = 0;
  Timer? _soundStopTimer;

  /// Android 平台实现；插件未注册时返回 null（而非抛出）。
  ///
  /// `resolvePlatformSpecificImplementation` 内部读
  /// `FlutterLocalNotificationsPlatform._instance`，未注册平台实现时该 late
  /// 字段会抛 `LateInitializationError`。这个 getter 在插件初始化前后都会被
  /// 调用，必须自行兜住。
  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  /// 最近一次初始化是否失败（仅用于日志去重，窗口期内不重复刷屏）。
  bool _initFailedLogged = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_initFailedLogged) return; // 本窗口内已报过，避免每次 tick 刷日志
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          // 点按 Dart 侧通知（降级路径）：切到「训练」Tab
          if (response.payload == 'workout') onNotificationTap?.call();
        },
      );
      _initialized = true;
      _initFailedLogged = false;
      // 原生转发通知点击（open_tab=workout）→ 切到训练 Tab
      _native.setMethodCallHandler((call) async {
        if (call.method == 'openWorkoutTab') {
          onOpenWorkoutRequested?.call();
        }
        return null;
      });
      await refreshNotificationPermission();
    } catch (e, s) {
      // 刻意**不**永久锁定：初始化失败可能是暂时性的（测试环境未注册插件、
      // 引擎重建等）。旧实现在 try 之前就置 _initialized = true，一旦此处
      // 抛异常，后续所有调用直接早退——通知、铃声、震动永久静默失效。
      // 这里只记一次日志，下次调用仍会重试。
      _initFailedLogged = true;
      debugPrint('RestAlarmService init failed: $e\n$s');
    }
  }

  /// 查询通知是否可用，必要时弹出系统授权对话框。
  ///
  /// 必须在**前台**调用：Android 不允许后台弹权限框，若首次申请发生在
  /// 用户已切后台之后，请求会直接失败且系统不会二次询问，此后所有通知、
  /// 铃声与震动都会被静默丢弃。因此规划页一打开组间倒计时就调用本方法，
  /// 把授权时机前移到用户仍在操作界面的时刻。
  ///
  /// 返回 true 表示通知可用。
  Future<bool> ensureNotificationPermission({bool request = true}) async {
    try {
      await _ensureInit();
      final android = _android;
      if (android == null) return true; // 非 Android（含测试环境）
      if (await android.areNotificationsEnabled() ?? true) {
        _notificationsBlocked = false;
        return true;
      }
      if (!request) {
        _notificationsBlocked = true;
        return false;
      }
      await android.requestNotificationsPermission();
      // 对话框结束后重新查询：requestNotificationsPermission 的返回值
      // 语义在部分 ROM 上不可靠，以 areNotificationsEnabled 为准。
      _notificationsBlocked = !(await android.areNotificationsEnabled() ?? true);
      return !_notificationsBlocked;
    } catch (e) {
      debugPrint('RestAlarmService permission check failed: $e');
      return true; // 查询失败不阻断倒计时，交由到点路径各自兜底
    }
  }

  /// 重新读取通知权限状态（不弹框），用于切回前台后刷新提示。
  Future<void> refreshNotificationPermission() async {
    try {
      _notificationsBlocked =
          !(await _android?.areNotificationsEnabled() ?? true);
    } catch (e) {
      debugPrint('RestAlarmService refresh permission failed: $e');
    }
  }

  /// 跳到系统通知设置页（供用户手动开启通知权限）。
  Future<void> openNotificationSettings() async {
    try {
      await _ensureInit();
      await _android?.openAppNotificationSettings();
    } catch (e) {
      debugPrint('RestAlarmService open settings failed: $e');
    }
  }

  /// 提醒自检：逐层触发并报告可用性，真机上定位「不响/不震/无通知」。
  ///
  /// 触发顺序：本机响铃（4 秒后自动停）→ 波形震动 → 查询通知权限与
  /// 精确闹钟 → 启动前台服务跑一个 5 秒的端到端演示（chronometer 倒计时
  /// 通知 + 到点提醒，随后自动清理）。
  Future<RestAlarmSelfTestResult> runSelfTest() async {
    await _ensureInit();
    var channelConnected = false;
    var ringerTriggered = false;
    var vibrationTriggered = false;
    var serviceStarted = false;

    try {
      ringerTriggered =
          await _native.invokeMethod<bool>('playDefaultAlarm') ?? false;
      channelConnected = true;
    } catch (e) {
      debugPrint('selfTest ringer failed: $e');
    }
    Future.delayed(const Duration(seconds: 4), () {
      try {
        _native.invokeMethod('stopAlarm');
      } catch (_) {}
    });
    try {
      vibrationTriggered =
          await _native.invokeMethod<bool>('vibrate') ?? false;
      channelConnected = true;
    } catch (e) {
      debugPrint('selfTest vibrate failed: $e');
    }
    try {
      serviceStarted = await _native.invokeMethod<bool>(
            'startCountdownService',
            {'seconds': 5},
          ) ??
          false;
      channelConnected = true;
    } catch (e) {
      debugPrint('selfTest service failed: $e');
    }

    var notificationsGranted = true;
    var exactAlarmAllowed = false;
    var backupAlertScheduled = false;
    try {
      notificationsGranted =
          await _android?.areNotificationsEnabled() ?? true;
    } catch (e) {
      debugPrint('selfTest notification query failed: $e');
    }
    try {
      exactAlarmAllowed =
          await _android?.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('selfTest exact-alarm query failed: $e');
    }
    // 兜底闹钟**功能**测试：实际预约一条 5 秒后的静音测试通知
    // （「休息结束（自检）」），弹出来了 = 精确闹钟链路真的可用
    if (exactAlarmAllowed) {
      try {
        backupAlertScheduled = await _schedule(5, exact: true);
      } catch (e) {
        debugPrint('selfTest backup schedule failed: $e');
      }
    }

    return RestAlarmSelfTestResult(
      channelConnected: channelConnected,
      notificationsGranted: notificationsGranted,
      exactAlarmAllowed: exactAlarmAllowed,
      backupAlertScheduled: backupAlertScheduled,
      ringerTriggered: ringerTriggered,
      vibrationTriggered: vibrationTriggered,
      serviceStarted: serviceStarted,
    );
  }

  /// 休息开始：优先交给原生前台服务（chronometer 通知 + AlarmManager 到点
  /// 兜底，后台冻结也持续走动/提醒）；服务不可用（异常/测试环境）时降级
  /// 为 Dart 自管通知 + 插件兜底预约。
  Future<void> start(int seconds) async {
    await _ensureInit();
    _totalSeconds = seconds;
    // 清掉旧会话/旧版本遗留的到点预约（预约闹钟跨更新存活）：
    // 否则它会在本次倒计时的任意时刻误触发一次带提示的「休息结束」弹窗
    try {
      await _plugin.cancel(id: _alertId);
    } catch (_) {}
    if (await _startCountdownService(seconds)) return;
    try {
      await _showOngoing(seconds);
    } catch (e) {
      debugPrint('RestAlarmService ongoing failed: $e');
    }
    await _scheduleEndAlert(seconds + _backupGraceSeconds);
  }

  /// 尝试启动原生倒计时服务；成功返回 true 并接管通知栏与到点提醒。
  Future<bool> _startCountdownService(int seconds) async {
    try {
      _serviceActive = await _native
              .invokeMethod<bool>('startCountdownService', {'seconds': seconds}) ??
          false;
    } catch (e) {
      debugPrint('RestAlarmService countdown service unavailable: $e');
      _serviceActive = false;
    }
    return _serviceActive;
  }

  /// 停掉原生倒计时服务（幂等：未启动时跳过，撤销到点闹钟由原生 stop 负责）。
  Future<void> _stopCountdownService() async {
    if (!_serviceActive) return;
    _serviceActive = false;
    try {
      await _native.invokeMethod('stopCountdownService');
    } catch (e) {
      debugPrint('RestAlarmService stop countdown service failed: $e');
    }
  }

  /// 休息计时推进：服务模式下通知由系统 chronometer 自刷新，无需逐秒更新；
  /// 降级模式刷新常驻通知（文本 + 进度条）。
  Future<void> tick(int remaining) async {
    if (!_initialized) return;
    if (remaining > _totalSeconds) _totalSeconds = remaining; // +15s 后进度条基准跟随
    if (_serviceActive) return;
    try {
      await _showOngoing(remaining);
    } catch (e) {
      debugPrint('RestAlarmService tick failed: $e');
    }
  }

  /// 休息延长（+15s）：服务模式重置 chronometer 基准与到点闹钟；
  /// 降级模式重排已预约的兜底闹钟。
  Future<void> extend(int remainingSeconds) async {
    if (_serviceActive) {
      if (await _startCountdownService(remainingSeconds)) return;
      await _scheduleEndAlert(remainingSeconds + _backupGraceSeconds);
      return;
    }
    if (!_alertScheduled) return;
    await _scheduleEndAlert(remainingSeconds + _backupGraceSeconds);
  }

  /// 休息自然结束。
  ///
  /// 前台服务模式：到点提醒（heads-up 弹窗 + 闹铃声 + 震动 + 撤倒计时通知）
  /// 由服务自身的到点动作负责并自行停止，Dart 不响铃、也不撤服务——
  /// 提前撤服务会掐断原生提醒，重复响铃则会出现双重提醒。
  /// 降级模式：本机响铃 + 震动；app 在后台时额外弹出「休息结束」通知
  /// （用户看不到界面）。
  Future<void> announceEnd() async {
    if (_serviceActive) return;
    await cancelAll();
    if (_isAppBackground) {
      try {
        await _showEndPopup();
      } catch (e) {
        debugPrint('RestAlarmService end popup failed: $e');
      }
    }
    try {
      await _native.invokeMethod('playDefaultAlarm');
    } catch (e) {
      debugPrint('RestAlarmService play failed: $e');
    }
    try {
      await _native.invokeMethod('vibrate');
    } catch (_) {}
    // 默认闹铃音可能长达数十秒，响 4 秒后主动停（波形震动自身约 1.8s）
    _soundStopTimer?.cancel();
    _soundStopTimer = Timer(const Duration(seconds: 4), () {
      try {
        _native.invokeMethod('stopAlarm');
      } catch (_) {}
    });
  }

  /// 后台到点的「休息结束」弹窗通知：max 重要级触发 heads-up 横幅，
  /// 渠道静音（铃声由 [announceEnd] 的主路径负责，避免双重铃声）。
  /// 复用兜底通知的 id：预约的兜底已在 cancelAll 撤销，槽位腾空。
  Future<void> _showEndPopup() async {
    await _plugin.show(
      id: _alertId,
      title: '休息结束',
      body: '下一组开始，继续加油！',
      payload: 'workout',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _popupChannel,
          '休息结束提醒',
          channelDescription: '休息到点时的弹出提醒（声音由 app 播放）',
          importance: Importance.max,
          priority: Priority.max,
          autoCancel: true,
        ),
      ),
    );
  }

  /// 手动跳过休息 / 训练结束：撤销常驻通知与到点提醒（不出声）。
  Future<void> cancelAll() async {
    _alertScheduled = false;
    await _stopCountdownService();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _ongoingId);
      await _plugin.cancel(id: _alertId);
    } catch (e) {
      debugPrint('RestAlarmService cancelAll failed: $e');
    }
  }

  /// 休息在后台（进程被冻结）期间到点、恢复后才判定结束：此时兜底提醒
  /// 应已发出，只撤掉常驻倒计时通知，保留到点提醒由用户确认（不响铃）。
  Future<void> endAfterBackup() async {
    _alertScheduled = false;
    await _stopCountdownService();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _ongoingId);
    } catch (e) {
      debugPrint('RestAlarmService endAfterBackup failed: $e');
    }
  }

  /// 兜底通知相对本机响铃的延迟余量：正常时 Dart 计时先到点并撤销它，
  /// 只有 app 被杀（Dart 不再运行）时它才会晚 3 秒触发。
  static const int _backupGraceSeconds = 3;

  Future<void> _showOngoing(int remaining) async {
    await _plugin.show(
      id: _ongoingId,
      title: '组间休息 ${formatClock(remaining)}',
      body: '休息结束后继续下一组',
      payload: 'workout',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _ongoingChannel,
          '组间倒计时',
          channelDescription: '休息期间的常驻倒计时通知',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: _totalSeconds,
          progress: (_totalSeconds - remaining).clamp(0, _totalSeconds),
        ),
      ),
    );
  }

  /// 预约到点兜底通知（app 被杀后由系统闹钟唤醒）。
  ///
  /// 精确模式在 Android 14+ 需要 SCHEDULE_EXACT_ALARM（该权限默认**不授予**，
  /// 且用户可随时撤销），请求被拒会直接抛异常——旧实现把它整个吞进 catch，
  /// 结果是到点通知永远排不上、且没有任何报错，即「到点不响」的主要根因。
  /// 这里改为：精确失败立刻降级为非精确重试一次，宁可晚几秒也一定要排上。
  Future<void> _scheduleEndAlert(int secondsFromNow) async {
    _alertScheduled = false;
    if (!_initialized) return;
    if (await _schedule(secondsFromNow, exact: true)) {
      _alertScheduled = true;
      return;
    }
    if (await _schedule(secondsFromNow, exact: false)) {
      _alertScheduled = true;
    }
  }

  /// 单次预约；成功返回 true。失败只记日志，由调用方决定是否降级重试。
  Future<bool> _schedule(int secondsFromNow, {required bool exact}) async {
    try {
      // 清掉上一轮可能残留的到点通知/弹窗（同 id 复用）
      await _plugin.cancel(id: _alertId);
      await _plugin.zonedSchedule(
        id: _alertId,
        title: '休息结束',
        body: '下一组开始，继续加油！',
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().add(Duration(seconds: secondsFromNow)),
          tz.UTC,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannel,
            '组间休息提醒',
            channelDescription: '休息到点的提醒（声音由 app 播放）',
            importance: Importance.max,
            priority: Priority.max,
            // 静音渠道：铃声与震动由本机 AlarmRinger 负责（不依赖通知权限），
            // 通知只做视觉；未授权时无声但响铃照常。
            enableVibration: false,
            autoCancel: true,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint(
          'RestAlarmService schedule failed (exact=$exact, in ${secondsFromNow}s): $e');
      return false;
    }
  }
}

/// 把 [WorkoutController] 的休息状态桥接到提醒：
/// 进入休息 → 启动（常驻通知 + 兜底闹钟）；每秒推进 → 刷新；
/// 剩余时间变长（+15s）→ 重排兜底闹钟；
/// 自然结束 → 本机响铃震动（主路径）；后台冻结期间到点 → 只撤倒计时
/// 通知（兜底已提醒）；手动跳过/训练结束 → 静默撤销。
class RestAlarmBridge {
  RestAlarmBridge(WorkoutController controller) {
    controller.addListener(() => _sync(controller));
  }

  bool _resting = false;
  int _lastRemaining = -1;

  void _sync(WorkoutController c) {
    final service = RestAlarmService.instance;
    if (!c.resting) {
      if (_resting) {
        _resting = false;
        switch (c.restEndReason) {
          case RestEndReason.completed:
            service.announceEnd();
          case RestEndReason.expiredInBackground:
            service.endAfterBackup();
          case RestEndReason.skipped:
            service.cancelAll();
        }
        _lastRemaining = -1;
      }
      return;
    }
    if (!_resting) {
      _resting = true;
      _lastRemaining = c.restRemaining;
      service.start(c.restRemaining);
      return;
    }
    if (c.restRemaining != _lastRemaining) {
      final extended = c.restRemaining > _lastRemaining;
      _lastRemaining = c.restRemaining;
      service.tick(c.restRemaining);
      if (extended) service.extend(c.restRemaining);
    }
  }
}

/// 提醒自检结果：逐层报告提醒链路的可用性，真机上定位「不响/不震/无通知」。
class RestAlarmSelfTestResult {
  const RestAlarmSelfTestResult({
    required this.channelConnected,
    required this.notificationsGranted,
    required this.exactAlarmAllowed,
    required this.backupAlertScheduled,
    required this.ringerTriggered,
    required this.vibrationTriggered,
    required this.serviceStarted,
  });

  /// MethodChannel 是否连通（原生侧有任何一次成功返回即视为连通）。
  final bool channelConnected;

  /// 通知权限（Android 13+ POST_NOTIFICATIONS）是否已授予。
  final bool notificationsGranted;

  /// 精确闹钟是否可用（决定兜底通知准不准）。
  final bool exactAlarmAllowed;

  /// 兜底闹钟测试通知是否预约成功（5 秒后应弹出「休息结束（自检）」）。
  final bool backupAlertScheduled;

  /// 已触发本机响铃（是否听到以实际为准）。
  final bool ringerTriggered;

  /// 已触发波形震动（是否感到以实际为准）。
  final bool vibrationTriggered;

  /// 原生前台服务是否成功启动（它会跑一个 5 秒的端到端演示）。
  final bool serviceStarted;
}
