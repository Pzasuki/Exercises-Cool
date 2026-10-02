import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../state/workout_controller.dart';

/// 系统级组间休息提醒：
/// - 休息期间：状态栏/锁屏常驻倒计时通知（实时刷新 + 进度条，无声）；
/// - 到点：闹钟级通知（系统闹钟铃声 + 震动，走闹钟音量，精确闹钟保证准点，
///   app 被杀也会触发）。
/// 灵动岛是 iOS 硬件能力（本应用为 Android 专属），用常驻通知达到同等体验。
class RestAlarmService {
  RestAlarmService._();

  static final RestAlarmService instance = RestAlarmService._();

  static const int _ongoingId = 1;
  static const int _alertId = 2;
  static const String _ongoingChannel = 'rest_countdown';
  static const String _alertChannel = 'rest_alert';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _totalSeconds = 0;

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
      // Android 13+ 运行时通知权限
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('RestAlarmService init failed: $e');
    }
  }

  static String _format(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 休息开始：常驻倒计时通知 + 到点闹钟提醒。
  Future<void> start(int seconds) async {
    await _ensureInit();
    _totalSeconds = seconds;
    try {
      await _showOngoing(seconds);
      await _scheduleEndAlert(seconds);
    } catch (e) {
      debugPrint('RestAlarmService start failed: $e');
    }
  }

  /// 休息计时推进：刷新常驻通知（文本 + 进度条）。
  Future<void> tick(int remaining) async {
    if (!_initialized) return;
    try {
      await _showOngoing(remaining);
    } catch (e) {
      debugPrint('RestAlarmService tick failed: $e');
    }
  }

  /// 休息自然结束：撤掉常驻通知即可，到点提醒由预定通知准点触发。
  Future<void> endNaturally() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _ongoingId);
    } catch (e) {
      debugPrint('RestAlarmService endNaturally failed: $e');
    }
  }

  /// 手动跳过休息 / 训练结束：撤销常驻通知与到点提醒。
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _ongoingId);
      await _plugin.cancel(id: _alertId);
    } catch (e) {
      debugPrint('RestAlarmService cancelAll failed: $e');
    }
  }

  Future<void> _showOngoing(int remaining) async {
    await _plugin.show(
      id: _ongoingId,
      title: '组间休息 ${_format(remaining)}',
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
          progress: _totalSeconds - remaining,
        ),
      ),
    );
  }

  Future<void> _scheduleEndAlert(int seconds) async {
    await _plugin.zonedSchedule(
      id: _alertId,
      title: '休息结束',
      body: '下一组开始，继续加油！',
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(Duration(seconds: seconds)),
        tz.UTC,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannel,
          '组间休息提醒',
          channelDescription: '休息到点的提醒（闹钟铃声与震动）',
          importance: Importance.max,
          priority: Priority.max,
          // 系统闹钟铃声 + 走闹钟音频属性：跟随用户闹钟音量，震动按渠道开启
          sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert'),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          autoCancel: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

/// 把 [WorkoutController] 的休息状态桥接到系统通知：
/// 进入休息 → 启动；每秒推进 → 刷新；自然结束 → 只撤常驻通知；
/// 手动跳过/训练结束 → 连到点提醒一起撤销。
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
        if (_lastRemaining > 0) {
          // 休息未走完就退出：手动跳过或训练结束 → 连提醒一起撤销
          service.cancelAll();
        } else {
          service.endNaturally();
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
      _lastRemaining = c.restRemaining;
      service.tick(c.restRemaining);
    }
  }
}
