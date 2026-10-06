package com.reexercises.exercises_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log

/**
 * 组间休息到点的最后兜底（由 RestCountdownService 预约的 setAlarmClock 触发）：
 * 服务到点动作没执行（进程被厂商省电冻结/杀死）时才会走到这里——
 * setAlarmClock 是系统时钟同款机制，能唤醒被冻结的进程。
 *
 * 直接本机响铃 + 震动（不依赖通知权限），并发「休息结束」视觉通知、
 * 停掉残留的倒计时服务。用 goAsync + 唤醒锁保证响铃期间进程不被回收。
 */
class RestEndReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(RestCountdownService.TAG, "RestEndReceiver fired (backup alarm path)")
        val pending = goAsync()
        // 部分唤醒锁：铃声 ≈2 秒 + 余量；到点动作执行期间 CPU 不睡
        val wakeLock = context.getSystemService(PowerManager::class.java)
            ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RestAlarm:endReceiver")
        wakeLock?.acquire(8000L)

        fun finish() {
            try {
                wakeLock?.release()
            } catch (_: Exception) {
            }
            pending.finish()
        }

        try {
            // 停掉可能残留的倒计时服务（会摘掉走到负数的 chronometer 通知）
            try {
                context.stopService(Intent(context, RestCountdownService::class.java))
            } catch (_: Exception) {
            }
            // 与服务到点动作共用去重：两边先后触发时只提醒一次
            if (RestCountdownService.tryClaimAlert()) {
                AlarmRinger.play(context)
                AlarmRinger.vibrate(context)
                RestCountdownService.postEndAlert(context)
            }
            // onReceive 返回后进程优先级骤降，留 5 秒让铃声/通知落地
            Handler(Looper.getMainLooper()).postDelayed({ finish() }, 5000L)
        } catch (e: Exception) {
            Log.w(RestCountdownService.TAG, "RestEndReceiver failed", e)
            finish()
        }
    }
}
