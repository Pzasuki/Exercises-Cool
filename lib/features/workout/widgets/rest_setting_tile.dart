import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../services/rest_alarm_service.dart';
import '../../../state/workout_controller.dart';
import 'steppers.dart';

/// 组间间歇设置（规划页底部）：分钟制（1 分钟起），0 = 关闭。
///
/// 开启时顺带申请通知权限：Android 13+ 未授予 POST_NOTIFICATIONS 时，系统会
/// **静默丢弃**所有通知——常驻倒计时、到点弹窗、铃声与震动一起失效且不报错
/// （实测「没声音、没震动、没弹窗」多由此引起）。授权框只能在 app 前台弹，
/// 所以把时机放在用户主动开启倒计时的这一刻；被拒则在下方给出提示入口。
class RestSettingTile extends StatefulWidget {
  const RestSettingTile({super.key});

  @override
  State<RestSettingTile> createState() => _RestSettingTileState();
}

class _RestSettingTileState extends State<RestSettingTile>
    with WidgetsBindingObserver {
  /// 通知被系统拒绝：常驻倒计时与到点提醒都不会出现，需要显式告知用户。
  bool _notificationsBlocked = false;

  /// 提醒自检是否正在执行。
  bool _selfTestRunning = false;

  /// 自检结果行（执行后填充）。
  List<String> _selfTestLines = const [
    '点「开始自检」逐层测试：响铃 → 震动 → 权限 → 前台服务',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户可能刚去系统设置里开了通知，切回前台时重新确认
    if (state == AppLifecycleState.resumed && _notificationsBlocked) {
      _refreshPermission();
    }
  }

  Future<void> _refreshPermission() async {
    await RestAlarmService.instance.refreshNotificationPermission();
    if (!mounted) return;
    setState(() =>
        _notificationsBlocked = RestAlarmService.instance.notificationsBlocked);
  }

  Future<void> _onToggle(bool enable) async {
    context.read<WorkoutController>().setRestSeconds(enable ? 60 : 0);
    if (!enable) return;
    // 用户此刻正在操作界面，是唯一能弹授权框的时机
    final ok = await RestAlarmService.instance.ensureNotificationPermission();
    if (!mounted) return;
    setState(() => _notificationsBlocked = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    final enabled = controller.restSeconds > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTile(context, controller, enabled),
        if (enabled) _buildSelfTest(),
        if (enabled && _notificationsBlocked) _buildPermissionWarning(),
      ],
    );
  }

  /// 提醒自检：逐层触发并报告链路状态（响铃/震动/通知权限/精确闹钟/前台服务）。
  Widget _buildSelfTest() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: AppColors.bgSurface,
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 8),
              title: const Text(
                '提醒自检',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              children: [
                if (_selfTestRunning)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  for (final line in _selfTestLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _runSelfTest,
                    child: const Text('重新自检'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runSelfTest() async {
    setState(() => _selfTestRunning = true);
    final result = await RestAlarmService.instance.runSelfTest();
    if (!mounted) return;
    setState(() {
      _selfTestRunning = false;
      _notificationsBlocked = !result.notificationsGranted;
      _selfTestLines = [
        '${result.channelConnected ? '✅' : '❌'} 原生通道连通',
        '${result.notificationsGranted ? '✅' : '❌'} 通知权限（❌ = 通知/到点视觉全部静默，点右上角去开启）',
        '${result.exactAlarmAllowed ? '✅' : '❌'} 精确闹钟权限（❌ = 兜底通知可能晚几秒）',
        '${result.backupAlertScheduled ? '✅ 已预约' : '❌'} 兜底闹钟功能（约 5 秒后应弹出「休息结束（自检）」通知）',
        '${result.ringerTriggered ? '✅ 已触发' : '❌'} 响铃（刚才是否听到铃声？）',
        '${result.vibrationTriggered ? '✅ 已触发' : '❌'} 震动（刚才是否感到震动？）',
        '${result.serviceStarted ? '✅' : '❌'} 前台服务（已启动 5 秒端到端演示）',
      ];
    });
  }

  /// 权限被拒时的提示条：说明现象并提供跳转系统设置的入口。
  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '通知权限未开启，倒计时与到点提醒不会显示',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await RestAlarmService.instance.openNotificationSettings();
            },
            child: const Text(
              '去开启',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WorkoutController controller,
    bool enabled,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '组间倒计时',
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          if (enabled) ...[
            MiniIconButton(
              icon: Icons.remove_circle_outline,
              onPressed: controller.restMinutes <= 1
                  ? null
                  : () => controller
                      .setRestMinutes(controller.restMinutes - 1),
            ),
            Text(
              '${controller.restMinutes} 分钟',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            MiniIconButton(
              icon: Icons.add_circle_outline,
              onPressed: controller.restMinutes >= 10
                  ? null
                  : () =>
                      controller.setRestMinutes(controller.restMinutes + 1),
            ),
            const SizedBox(width: 4),
          ] else ...[
            const Text(
              '关',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Switch(
            value: enabled,
            activeThumbColor: AppColors.accent,
            onChanged: _onToggle,
          ),
        ],
      ),
    );
  }
}
