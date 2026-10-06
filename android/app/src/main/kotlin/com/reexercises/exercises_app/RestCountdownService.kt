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
import android.util.Log
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
        Log.d(TAG, "endAction fired (foreground handler path)")
        // 先撤掉尚未触发的兜底闹钟，避免 3 秒后双重提醒
        cancelEndAlarm(this)
        if (tryClaimAlert()) {
            // 声音与震动**不依赖通知权限**：直接本机响铃 + 波形震动；
            // 通知只承担视觉部分（未授权时静默跳过，不影响响铃）。
            AlarmRinger.play(this)
            AlarmRinger.vibrate(this)
            postEndAlert(this)
        }
        // 显式摘掉前台倒计时通知：不能只依赖 stopSelf() —— 倒计时走完后若
        // 该通知没被移除，系统 Chronometer 会继续读数并越过零点，通知栏就
        // 留在 -00:01 这样的负数上。STOP_FOREGROUND_REMOVE 只移除本前台通知，
        // 不影响上面刚发出的到点提醒（不同 id）。
        stopForeground(STOP_FOREGROUND_REMOVE)
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
        Log.d(TAG, "countdown started: ${seconds}s, endAt=$endAtMillis")
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
            // 点击通知回到 app 的训练页
            .setContentIntent(launchIntent(this))
            .build()
    }

    /** 到点兜底闹钟：setAlarmClock（系统时钟同款机制）——比 setExactAndAllowWhileIdle
     *  更能穿透 Doze 与厂商省电策略（无需精确闹钟权限，OEM 不拦截用户闹钟）。
     *  比到点晚 3 秒余量，正常到点时会被 endAction 先行撤销。 */
    private fun scheduleEndAlarm(seconds: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAtMillis =
            System.currentTimeMillis() + (seconds + GRACE_SECONDS) * 1000L
        val info = AlarmManager.AlarmClockInfo(
            triggerAtMillis,
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java)
                    .putExtra(MainActivity.OPEN_TAB_EXTRA, MainActivity.OPEN_TAB_WORKOUT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        Log.d(TAG, "scheduleEndAlarm in ${seconds + GRACE_SECONDS}s via setAlarmClock")
        alarmManager.setAlarmClock(info, endAlarmPendingIntent(this))
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
        // 兜底再摘一次前台通知（先跳过休息、进程被回收等路径不会走 endAction）。
        // 对已停止的前台服务调用是空操作，幂等安全 —— 关键是绝不能让
        // 倒计时通知在服务消失后继续存在于通知栏（Chronometer 会读成负数）。
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    companion object {
        const val TAG = "RestAlarm"
        const val EXTRA_SECONDS = "remainingSeconds"
        const val NOTIFICATION_ID = 1
        const val ALERT_NOTIFICATION_ID = 2
        const val GRACE_SECONDS = 3

        // 渠道 id 与 Dart 侧 flutter_local_notifications 对齐。
        // v2：旧渠道可能已被部分 ROM 按默认通知声创建（渠道设置不可改），
        // 显式静音必须换新 id 才能生效。
        const val CHANNEL_ONGOING = "rest_countdown_v2"

        /// 到点提醒的视觉渠道：**静音**（声音与震动由 AlarmRinger 负责，
        /// 不依赖通知权限）。v2 渠道带铃声且创建后不可改设置，故换 v3。
        const val CHANNEL_ALERT = "rest_alert_v3"

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
                        // 显式静音：部分 ROM 对未显式设置的渠道按默认通知声处理，
                        // 导致开始倒计时时弹窗带铃声与震动
                        setSound(null, null)
                        enableVibration(false)
                    }
                )
            }
            if (manager.getNotificationChannel(CHANNEL_ALERT) == null) {
                // 静音渠道：heads-up 只承担视觉部分；铃声与震动由 AlarmRinger
                // 直接播放（不依赖通知权限，未授权时依然响铃震动）。
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ALERT, "组间休息提醒", NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "休息到点的提醒（声音由 app 播放）"
                        setSound(null, null)
                        enableVibration(false)
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

        /// 点提醒回到 app 的训练页（启动 intent 携带 open_tab extra，
        /// MainActivity 收到后通知 Dart 切 Tab；落在既有任务栈上）。
        private fun launchIntent(context: Context): PendingIntent? =
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                it.putExtra(MainActivity.OPEN_TAB_EXTRA, MainActivity.OPEN_TAB_WORKOUT)
                PendingIntent.getActivity(
                    context,
                    0,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
    }
}
