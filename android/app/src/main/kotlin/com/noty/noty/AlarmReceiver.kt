package com.noty.noty

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/// Dispara la alarma nativa: suena y abre la pantalla de confirmación encima de otras apps.
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Recordatorio Noty"
        val body = intent.getStringExtra(EXTRA_BODY) ?: "Es hora de tu recordatorio"
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        wakeScreen(context)
        AlarmSoundHolder.play(context.applicationContext)
        launchAlarmOverlay(context, payload)
        showAlarmNotification(context, notificationId, title, body, payload)
    }

    private fun launchAlarmOverlay(context: Context, payload: String) {
        val serviceIntent = Intent(context, AlarmLaunchService::class.java).apply {
            putExtra(AlarmLaunchHelper.EXTRA_ALARM_PAYLOAD, payload)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            return
        } catch (_: Exception) {
            // Fallback si el servicio no puede arrancar.
        }

        val launchIntent = AlarmLaunchHelper.alarmActivityIntent(context, payload)
        val pendingLaunch = PendingIntent.getActivity(
            context,
            payload.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            pendingLaunch.send()
        } catch (_: PendingIntent.CanceledException) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
        }
    }

    private fun wakeScreen(context: Context) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        val wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
            "noty:alarm_wake",
        )
        wakeLock.acquire(60_000L)
    }

    private fun showAlarmNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        payload: String,
    ) {
        val channelId = "noty_alarms_native"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Alarmas Noty",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Recordatorios que requieren confirmación"
                setBypassDnd(true)
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), attrs)
            }
            manager.createNotificationChannel(channel)
        }

        val tapIntent = AlarmLaunchHelper.alarmActivityIntent(context, payload)
        val tapPending = PendingIntent.getActivity(
            context,
            notificationId,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(tapPending)
            .setDeleteIntent(AlarmNotificationHelper.deletePendingIntent(context, notificationId))
            .setVibrate(longArrayOf(0, 800, 400, 800))
            .setOngoing(true)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    companion object {
        const val EXTRA_PAYLOAD = "alarm_payload"
        const val EXTRA_TITLE = "alarm_title"
        const val EXTRA_BODY = "alarm_body"
        const val EXTRA_NOTIFICATION_ID = "alarm_notification_id"
    }
}

/// Ringtone compartido entre actividades y AlarmReceiver.
object AlarmSoundHolder {
    private var ringtone: Ringtone? = null
    private var autoStopRunnable: Runnable? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private const val MAX_RING_MS = 90_000L

    fun play(context: Context) {
        stop()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val tone = RingtoneManager.getRingtone(context.applicationContext, uri) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            tone.isLooping = true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            tone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        }
        ringtone = tone
        tone.play()

        val runnable = Runnable { stop() }
        autoStopRunnable = runnable
        handler.postDelayed(runnable, MAX_RING_MS)
    }

    fun stop() {
        autoStopRunnable?.let { handler.removeCallbacks(it) }
        autoStopRunnable = null
        ringtone?.stop()
        ringtone = null
    }
}
