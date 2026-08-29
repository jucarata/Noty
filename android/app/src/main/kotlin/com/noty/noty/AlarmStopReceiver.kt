package com.noty.noty

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Detiene el sonido cuando el usuario descarta la notificación de alarma.
class AlarmStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmSoundHolder.stop()
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId >= 0) {
            AlarmNotificationHelper.cancel(context, notificationId)
        }
    }

    companion object {
        const val EXTRA_NOTIFICATION_ID = "alarm_notification_id"
    }
}
