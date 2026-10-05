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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 组间休息到点的本机提醒通道（见 lib/services/rest_alarm_service.dart）：
/// - defaultAlarmSoundUri：用户设置的默认闹铃声（系统设置「闹钟铃声」），
///   供休息提醒通知渠道使用；
/// - playDefaultAlarm / stopAlarm：app 存活时由 Dart 在倒计时走完的瞬间
///   直接响铃（Ringtone 走闹钟音量），不依赖闹钟权限；
/// - vibrate：波形震动；
/// - startCountdownService / stopCountdownService：后台倒计时交给原生前台
///   服务（RestCountdownService，chronometer 渲染 + AlarmManager 到点兜底）。
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "rest_alarm"
        val VIBE_PATTERN = longArrayOf(0, 450, 250, 450, 250, 450)
    }

    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "defaultAlarmSoundUri" -> result.success(defaultAlarmSound()?.toString())
                    "playDefaultAlarm" -> {
                        playDefaultAlarm()
                        result.success(null)
                    }
                    "stopAlarm" -> {
                        stopAlarm()
                        result.success(null)
                    }
                    "vibrate" -> {
                        vibrate()
                        result.success(null)
                    }
                    "startCountdownService" -> {
                        val seconds = call.argument<Int>("seconds") ?: -1
                        result.success(RestCountdownService.start(this, seconds))
                    }
                    "stopCountdownService" -> {
                        RestCountdownService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 默认闹铃声；未设置时依次回退通知声 / 铃声（RingtoneManager 官方回退链）。
    private fun defaultAlarmSound(): Uri? {
        var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        return uri
    }

    private fun playDefaultAlarm() {
        stopAlarm()
        val sound = defaultAlarmSound() ?: return
        val ringtone = RingtoneManager.getRingtone(applicationContext, sound) ?: return
        ringtone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        ringtone.play()
        this.ringtone = ringtone
    }

    private fun stopAlarm() {
        try {
            ringtone?.stop()
        } catch (_: Exception) {
            // 已停止或未在播放
        }
        ringtone = null
    }

    private fun vibrate() {
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(VIBE_PATTERN, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(VIBE_PATTERN, -1)
        }
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }
}
