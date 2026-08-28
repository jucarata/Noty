package com.noty.noty

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.noty.noty/alarm_sound"
    private var pendingAlarmPayload: String? = null
    private var alarmChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        captureAlarmPayload(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAlarmPayload(intent)
        deliverPayloadToFlutter(pendingAlarmPayload)
    }

    private fun captureAlarmPayload(intent: Intent?) {
        val payload = intent?.getStringExtra(EXTRA_ALARM_PAYLOAD)
        if (!payload.isNullOrEmpty()) {
            pendingAlarmPayload = payload
        }
    }

    private fun deliverPayloadToFlutter(payload: String?) {
        if (payload.isNullOrEmpty()) {
            return
        }
        pendingAlarmPayload = null
        alarmChannel?.invokeMethod("alarmLaunched", payload)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        alarmChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "playAlarm" -> {
                        AlarmSoundHolder.play(applicationContext)
                        result.success(null)
                    }
                    "stopAlarm" -> {
                        AlarmSoundHolder.stop()
                        result.success(null)
                    }
                    "getPendingAlarmPayload" -> {
                        val payload = pendingAlarmPayload
                        pendingAlarmPayload = null
                        result.success(payload)
                    }
                    "scheduleNativeAlarm" -> {
                        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
                        val notificationId = call.argument<Int>("notificationId")
                        val payload = call.argument<String>("payload")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        if (
                            triggerAtMillis == null ||
                            notificationId == null ||
                            payload.isNullOrEmpty()
                        ) {
                            result.error("invalid_args", "Missing alarm args", null)
                            return@setMethodCallHandler
                        }
                        scheduleNativeAlarm(
                            triggerAtMillis = triggerAtMillis,
                            notificationId = notificationId,
                            payload = payload,
                            title = title ?: "Recordatorio Noty",
                            body = body ?: "Es hora de tu recordatorio",
                        )
                        result.success(null)
                    }
                    "cancelNativeAlarm" -> {
                        val notificationId = call.argument<Int>("notificationId")
                        if (notificationId == null) {
                            result.error("invalid_args", "Missing notificationId", null)
                            return@setMethodCallHandler
                        }
                        cancelNativeAlarm(notificationId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        deliverPayloadToFlutter(pendingAlarmPayload)
    }

    private fun scheduleNativeAlarm(
        triggerAtMillis: Long,
        notificationId: Int,
        payload: String,
        title: String,
        body: String,
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_PAYLOAD, payload)
            putExtra(AlarmReceiver.EXTRA_TITLE, title)
            putExtra(AlarmReceiver.EXTRA_BODY, body)
            putExtra(AlarmReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val pending = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val showIntent = PendingIntent.getActivity(
            this,
            notificationId + 1,
            Intent(this, MainActivity::class.java).apply {
                putExtra(EXTRA_ALARM_PAYLOAD, payload)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pending,
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent),
                pending,
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pending,
            )
        }
    }

    private fun cancelNativeAlarm(notificationId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pending)
    }

    override fun onDestroy() {
        AlarmSoundHolder.stop()
        super.onDestroy()
    }

    companion object {
        const val EXTRA_ALARM_PAYLOAD = "alarm_payload"
    }
}
