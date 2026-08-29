package com.noty.noty

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/// Servicio breve en primer plano para abrir la pantalla de alarma encima de otras apps.
class AlarmLaunchService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = intent?.getStringExtra(AlarmLaunchHelper.EXTRA_ALARM_PAYLOAD)
        if (payload.isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        val channelId = "noty_alarm_launch"
        ensureChannel(channelId)

        val dismissAfter = NotyApplication.currentActivity == null
        val launchIntent = AlarmLaunchHelper.alarmActivityIntent(
            this,
            payload,
            dismissAfter = dismissAfter,
        )
        val pendingLaunch = PendingIntent.getActivity(
            this,
            payload.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Recordatorio Noty")
            .setContentText("Confirma tu recordatorio")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingLaunch)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this,
                payload.hashCode() and 0x7fffffff,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(payload.hashCode() and 0x7fffffff, notification)
        }

        try {
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
            startActivity(launchIntent)
        } catch (error: Exception) {
            try {
                pendingLaunch.send()
            } catch (_: PendingIntent.CanceledException) {
                // La notificación con fullScreenIntent sigue como respaldo.
            }
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        return START_NOT_STICKY
    }

    private fun ensureChannel(channelId: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(channelId) != null) {
            return
        }
        val channel = NotificationChannel(
            channelId,
            "Lanzar recordatorio",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Abre la pantalla de confirmación"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        manager.createNotificationChannel(channel)
    }
}
