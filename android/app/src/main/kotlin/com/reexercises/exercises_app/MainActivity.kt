package com.reexercises.exercises_app

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// 组间休息到点的本机提醒通道（见 lib/services/rest_alarm_service.dart）：
/// - defaultAlarmSoundUri：用户设置的默认闹铃声（系统设置「闹钟铃声」）；
/// - playDefaultAlarm / stopAlarm：app 存活时由 Dart 在倒计时走完的瞬间
///   直接响铃（Ringtone 走闹钟音量），不依赖通知权限；
/// - vibrate：波形震动；
/// - startCountdownService / stopCountdownService：后台倒计时交给原生前台
///   服务（RestCountdownService，chronometer 渲染 + AlarmManager 到点兜底）。
/// 响铃/震动方法返回 Boolean（是否真的触发），供 app 内「提醒自检」展示。
/// 通知点击通过 open_tab extra 唤起并转发 `openWorkoutTab`，Dart 侧切到训练 Tab。
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "rest_alarm"
        const val OPEN_TAB_EXTRA = "open_tab"
        const val OPEN_TAB_WORKOUT = "workout"

        /// 冷启动推送延迟：等 Dart main() 安装好通道回调
        private const val OPEN_TAB_PUSH_DELAY_MS = 1000L
    }

    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "defaultAlarmSoundUri" ->
                    result.success(AlarmRinger.defaultAlarmSound(this)?.toString())
                "playDefaultAlarm" -> result.success(AlarmRinger.play(this))
                "stopAlarm" -> {
                    AlarmRinger.stop()
                    result.success(null)
                }
                "vibrate" -> result.success(AlarmRinger.vibrate(this))
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
        // 冷启动时 Dart 的通道回调尚未安装（main() 需先跑完），延迟 1 秒推送；
        // 热启动（onNewIntent）则立即处理。
        Handler(Looper.getMainLooper()).postDelayed(
            { handleOpenTabIntent(intent) },
            OPEN_TAB_PUSH_DELAY_MS,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleOpenTabIntent(intent)
    }

    /// 通知点击携带 open_tab=workout 时，通知 Dart 切到训练 Tab
    /// （singleTop 启动：冷启动走 onCreate→configureFlutterEngine，热启动走 onNewIntent）。
    private fun handleOpenTabIntent(intent: Intent?) {
        if (intent?.getStringExtra(OPEN_TAB_EXTRA) == OPEN_TAB_WORKOUT) {
            channel?.invokeMethod("openWorkoutTab", null)
        }
    }

    override fun onDestroy() {
        AlarmRinger.stop()
        super.onDestroy()
    }
}
