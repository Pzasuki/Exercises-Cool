package com.reexercises.exercises_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * 组间休息倒计时的前台服务（配套 lib/services/rest_alarm_service.dart）：
 *
 * app 切后台后，部分 ROM 会对 Dart 线程做 CPU 节流甚至冻结，Dart 的到点
 * 提醒因此不可靠。本服务把进程提到前台优先级（前台服务不进 App Freezer），
 * 并自己负责到点提醒的整条链路：
 *
 * - 通知栏倒计时用系统 Chronometer 渲染，剩余时间由系统刷新，无需跑代码；
 * - 到点时刻由服务自身的 [endAction]（Handler）触发：弹出「休息结束」
 *   heads-up 通知（渠道自带默认闹铃声与震动）→ 停止服务。全程不依赖
 *   Dart 存活，Chronometer 也不会走过头变成负数；
 * - AlarmManager 预约的 [RestEndReceiver] 是进程被杀后的最后兜底
 *   （闹钟在进程死后仍会唤醒执行）。
 *
 * Dart 侧每秒 tick 只驱动 app 内界面与状态机。休息被跳过/提前结束时
 * Dart 调 [stop] 撤销到点动作、兜底闹钟与服务。
 */
class RestCountdownService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    /** 结束时刻的到点动作：提醒 + 自停（进程还活着时的主提醒路径）。 */
    private val endAction = Runnable {
        // 先撤掉尚未触发的兜底闹钟，避免 3 秒后双重提醒
        cancelEndAlarm(this)
        if (tryClaimAlert()) {
            postEndAlert(this)
        }
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val seconds = intent?.getIntExtra(EXTRA_SECONDS, -1) ?: -1
        if (seconds <= 0) {
            stopSelf()
            return START_NOT_STICKY
        }
        // +15s 重排等场景会重复进入：先清掉上一轮的到点动作
        handler.removeCallbacks(endAction)
        val endAtMillis = System.currentTimeMillis() + seconds * 1000L
        startForeground(NOTIFICATION_ID, buildNotification(endAtMillis))
        scheduleEndAlarm(seconds)
        handler.postDelayed(
            endAction, (endAtMillis - System.currentTimeMillis()).coerceAtLeast(0L)
        )
        return START_NOT_STICKY
    }

    /** 通知栏倒计时：Chronometer 由系统渲染（minSdk 24，API 无需分支）。 */
    private fun buildNotification(endAtMillis: Long): Notification {
        ensureChannels(this)
        return notificationBuilder(this, CHANNEL_ONGOING)
            .setContentTitle("组间休息")
            .setContentText("休息结束后继续下一组")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setUsesChronometer(true)
            .setWhen(endAtMillis)
            .setChronometerCountDown(true)
            .build()
    }

    /** 到点兜底闹钟：比到点晚 3 秒余量，正常到点时会被 endAction 先行撤销。 */
    private fun scheduleEndAlarm(seconds: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis =
            System.currentTimeMillis() + (seconds + GRACE_SECONDS) * 1000L
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        if (canExact) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, endAlarmPendingIntent(this)
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, endAlarmPendingIntent(this)
            )
        }
    }

    private fun cancelEndAlarm(context: Context) {
        try {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(endAlarmPendingIntent(context))
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        // 取消到点动作（Dart 提前 stop / 服务被回收时不再提醒）。
        // 兜底闹钟刻意不在这里撤：服务被系统直接杀死时 onDestroy 不保证
        // 执行，闹钟保留才能让 RestEndReceiver 完成最后的提醒。
        handler.removeCallbacks(endAction)
        super.onDestroy()
    }

    companion object {
        const val EXTRA_SECONDS = "remainingSeconds"
        const val NOTIFICATION_ID = 1
        const val ALERT_NOTIFICATION_ID = 2
        const val GRACE_SECONDS = 3

        // 渠道 id 与 Dart 侧 flutter_local_notifications 对齐
        const val CHANNEL_ONGOING = "rest_countdown"
        const val CHANNEL_ALERT = "rest_alert_v2"

        private const val ALERT_DEDUP_WINDOW_MS = 10_000L

        @Volatile
        private var lastAlertAtMillis = 0L

        /** 启动倒计时服务；返回 false（含异常）时 Dart 降级为自管通知。 */
        fun start(context: Context, seconds: Int): Boolean = try {
            ContextCompat.startForegroundService(
                context,
                Intent(context, RestCountdownService::class.java)
                    .putExtra(EXTRA_SECONDS, seconds),
            )
            true
        } catch (e: Exception) {
            false
        }

        /** 撤销到点动作与兜底闹钟并停止服务（幂等，未运行时是空操作）。 */
        fun stop(context: Context) {
            try {
                val alarmManager =
                    context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(endAlarmPendingIntent(context))
            } catch (_: Exception) {
            }
            try {
                context.stopService(Intent(context, RestCountdownService::class.java))
            } catch (_: Exception) {
            }
        }

        private fun endAlarmPendingIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, RestEndReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        /**
         * 渠道设置与 Dart 侧 flutter_local_notifications 完全对齐（同名渠道
         * 先建者生效，谁先创建都必须是同一套设置）：rest_countdown 低重要级
         * 常驻；rest_alert_v2 高重要级 + 用户默认闹铃声 + 波形震动。
         */
        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel(CHANNEL_ONGOING) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ONGOING, "组间倒计时", NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "休息期间的常驻倒计时通知"
                    }
                )
            }
            if (manager.getNotificationChannel(CHANNEL_ALERT) == null) {
                val sound: Uri? = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ALERT, "组间休息提醒", NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "休息到点的提醒（默认闹铃声与震动）"
                        if (sound != null) {
                            setSound(
                                sound,
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build()
                            )
                        }
                        enableVibration(true)
                        vibrationPattern = longArrayOf(0, 450, 250, 450, 250, 450)
                    }
                )
            }
        }

        fun notificationBuilder(context: Context, channelId: String): NotificationCompat.Builder =
            NotificationCompat.Builder(context, channelId)

        /**
         * 10 秒内只提醒一次：到点 Handler 与兜底闹钟可能先后触发
         * （CPU 节流时 Handler 迟到、闹钟先行），避免重复弹窗/响铃。
         */
        @Synchronized
        fun tryClaimAlert(): Boolean {
            val now = System.currentTimeMillis()
            if (now - lastAlertAtMillis < ALERT_DEDUP_WINDOW_MS) return false
            lastAlertAtMillis = now
            return true
        }

        /** 「休息结束」提醒：heads-up 弹窗 + 渠道默认闹铃声 + 波形震动。 */
        fun postEndAlert(context: Context) {
            ensureChannels(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                return // 未授予通知权限：静默退出（与 Dart 侧通知行为一致）
            }
            try {
                NotificationManagerCompat.from(context)
                    .notify(ALERT_NOTIFICATION_ID, endAlertNotification(context))
            } catch (_: SecurityException) {
            }
        }

        private fun endAlertNotification(context: Context): Notification =
            notificationBuilder(context, CHANNEL_ALERT)
                .setContentTitle("休息结束")
                .setContentText("下一组开始，继续加油！")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setAutoCancel(true)
                .setContentIntent(launchIntent(context))
                .build()

        /// 点提醒回到 app（用启动 intent，落在既有任务栈上）。
        private fun launchIntent(context: Context): PendingIntent? =
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                PendingIntent.getActivity(
                    context,
                    0,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
    }
}
