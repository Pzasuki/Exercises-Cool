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
  static const String _ongoingChannel = 'rest_countdown';

  /// 提醒渠道 v2：渠道设置创建后不可更改，改用新 id 才能让默认闹铃声/震动生效。
  static const String _alertChannel = 'rest_alert_v2';

  /// 后台到点的弹出通知渠道：max 重要级触发 heads-up 横幅，但渠道本身
  /// 静音——声音由本机响铃主路径负责（渠道声音创建后不可改，单独开渠道）。
  static const String _popupChannel = 'rest_alert_popup_v1';

  static const MethodChannel _native = MethodChannel('rest_alarm');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

  /// 精确闹钟是否可用（Android 12+ 需「闹钟和提醒」权限，未授予时预约退化为
  /// 非精确模式；本机响铃为主路径，不为此打断用户去开系统设置）。
  bool? _canScheduleExact;

  /// 默认闹铃声 URI（原生侧一次解析后缓存；解析失败用渠道默认音）。
  String? _alarmSoundUri;
  bool _alarmSoundResolved = false;

  /// 兜底通知是否已预约成功。
  bool _alertScheduled = false;

  int _totalSeconds = 0;
  Timer? _soundStopTimer;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    // 失败不再重试（如插件不可用的环境），避免每次 tick 都走异常路径
    _initialized = true;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ 运行时通知权限
      await android?.requestNotificationsPermission();
      _canScheduleExact = await android?.canScheduleExactNotifications();
    } catch (e) {
      debugPrint('RestAlarmService init failed: $e');
    }
  }

  Future<String?> _resolveAlarmSoundUri() async {
    if (_alarmSoundResolved) return _alarmSoundUri;
    _alarmSoundResolved = true;
    try {
      _alarmSoundUri = await _native.invokeMethod<String>('defaultAlarmSoundUri');
    } catch (_) {
      // 原生通道不可用（如测试环境）→ 通知渠道用系统默认音
    }
    return _alarmSoundUri;
  }


  /// 休息开始：优先交给原生前台服务（chronometer 通知 + AlarmManager 到点
  /// 兜底，后台冻结也持续走动/提醒）；服务不可用（异常/测试环境）时降级
  /// 为 Dart 自管通知 + 插件兜底预约。
  Future<void> start(int seconds) async {
    await _ensureInit();
    _totalSeconds = seconds;
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

  Future<void> _scheduleEndAlert(int secondsFromNow) async {
    _alertScheduled = false;
    if (!_initialized) return;
    try {
      final soundUri = await _resolveAlarmSoundUri();
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
            channelDescription: '休息到点的提醒（默认闹铃声与震动）',
            importance: Importance.max,
            priority: Priority.max,
            // 用户设置的默认闹铃声（渠道不可改设置，用 v2 渠道承载）
            sound: soundUri == null
                ? null
                : UriAndroidNotificationSound(soundUri),
            enableVibration: true,
            vibrationPattern: Int64List.fromList(const [0, 450, 250, 450, 250, 450]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            autoCancel: true,
          ),
        ),
        androidScheduleMode: (_canScheduleExact ?? false)
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _alertScheduled = true;
    } catch (e) {
      debugPrint('RestAlarmService schedule failed: $e');
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
