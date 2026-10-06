package com.reexercises.exercises_app

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * 闹铃提醒（响铃 + 震动），供三处共用：
 * - MainActivity（Dart 侧主动触发/自检）
 * - RestCountdownService 到点动作
 * - RestEndReceiver 进程被杀后的兜底
 *
 * 刻意**不依赖通知权限**：到点的声音与震动直接走 RingtoneManager（用户
 * 设置的默认闹铃声，闹钟音量）+ Vibrator——Android 13+ 未授予
 * POST_NOTIFICATIONS 时通知会被静默丢弃，但响铃与震动必须照常工作。
 */
object AlarmRinger {
    private const val TAG = "RestAlarm"

    val VIBE_PATTERN = longArrayOf(0, 450, 250, 450, 250, 450)

    private var ringtone: Ringtone? = null

    /** 用户设置的默认闹铃声；未设置时依次回退通知声 / 铃声。 */
    fun defaultAlarmSound(context: Context): Uri? {
        var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        return uri
    }

    /** 播放默认闹铃声（闹钟音量）；返回是否真的开始播放。 */
    fun play(context: Context): Boolean = try {
        stop()
        val sound = defaultAlarmSound(context) ?: return false
        val ringtone = RingtoneManager.getRingtone(context, sound) ?: return false
        ringtone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        ringtone.play()
        this.ringtone = ringtone
        true
    } catch (e: Exception) {
        Log.w(TAG, "AlarmRinger.play failed", e)
        false
    }

    fun stop() {
        try {
            ringtone?.stop()
        } catch (_: Exception) {
            // 已停止或未在播放
        }
        ringtone = null
    }

    /** 波形震动；返回设备有马达并已触发（系统震动总开关关闭时系统侧静默）。 */
    fun vibrate(context: Context): Boolean = try {
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) {
            false
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(VIBE_PATTERN, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VIBE_PATTERN, -1)
            }
            true
        }
    } catch (e: Exception) {
        Log.w(TAG, "AlarmRinger.vibrate failed", e)
        false
    }
}
