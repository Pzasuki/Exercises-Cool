package com.reexercises.exercises_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 组间休息到点的最后兜底（由 RestCountdownService 预约的 AlarmManager 触发）：
 * 仅当服务自身没能到点提醒（进程被用户划掉/系统杀死）时才会执行——闹钟在
 * 进程死后仍会唤醒本 receiver。发「休息结束」通知（rest_alert_v2 渠道自带
 * 默认闹铃声与震动），并停掉残留的倒计时服务。
 */
class RestEndReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        // 停掉可能残留的倒计时服务（服务本体多半已随进程消亡）
        try {
            context.stopService(Intent(context, RestCountdownService::class.java))
        } catch (_: Exception) {
        }
        // 与服务到点动作共用去重：两边先后触发时只提醒一次
        if (RestCountdownService.tryClaimAlert()) {
            RestCountdownService.postEndAlert(context)
        }
    }
}
