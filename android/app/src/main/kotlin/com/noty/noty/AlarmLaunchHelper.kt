package com.noty.noty

import android.app.Activity
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object AlarmLaunchHelper {
    const val CHANNEL = "com.noty.noty/alarm_sound"
    const val EXTRA_ALARM_PAYLOAD = "alarm_payload"

    private var pendingAlarmPayload: String? = null
    private var lastDeliveredPayload: String? = null
    private var alarmChannel: MethodChannel? = null

    fun storePayload(payload: String) {
        if (payload.isNotEmpty()) {
            pendingAlarmPayload = payload
        }
    }

    fun registerAlarmHandlers(
        channel: MethodChannel,
        scheduleNativeAlarm: (Map<String, Any?>) -> Unit,
        cancelNativeAlarm: (Int) -> Unit,
    ) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarm" -> {
                    AlarmSoundHolder.play(NotyApplication.instance.applicationContext)
                    result.success(null)
                }
                "stopAlarm" -> {
                    AlarmSoundHolder.stop()
                    result.success(null)
                }
                "stopAlarmAndDismiss" -> {
                    AlarmSoundHolder.stop()
                    clearDeliveryState()
                    val notificationId = call.argument<Int>("notificationId")
                    if (notificationId != null) {
                        AlarmNotificationHelper.cancel(
                            NotyApplication.instance.applicationContext,
                            notificationId,
                        )
                    }
                    result.success(null)
                }
                "getPendingAlarmPayload" -> {
                    result.success(consumePayload())
                }
                "finishAlarmOverlay" -> {
                    AlarmSoundHolder.stop()
                    result.success(null)
                }
                "scheduleNativeAlarm" -> {
                    scheduleNativeAlarm(call.arguments as Map<String, Any?>)
                    result.success(null)
                }
                "cancelNativeAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId")
                    if (notificationId == null) {
                        result.error("invalid_args", "Missing notificationId", null)
                    } else {
                        cancelNativeAlarm(notificationId)
                        result.success(null)
                    }
                }
                "cancelAllNativeAlarms" -> {
                    val rawIds = call.argument<List<Any?>>("notificationIds").orEmpty()
                    val ids = rawIds.mapNotNull { item ->
                        (item as? Number)?.toInt()
                    }
                    NativeAlarmScheduler.cancelAll(
                        NotyApplication.instance.applicationContext,
                        ids,
                    )
                    clearDeliveryState()
                    result.success(null)
                }
                "canUseFullScreenIntent" -> {
                    val manager =
                        NotyApplication.instance.getSystemService(NotificationManager::class.java)
                    val allowed =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            manager.canUseFullScreenIntent()
                        } else {
                            true
                        }
                    result.success(allowed)
                }
                "openFullScreenIntentSettings" -> {
                    val activity = NotyApplication.currentActivity
                    if (activity == null) {
                        result.error("no_activity", "No activity", null)
                        return@setMethodCallHandler
                    }
                    openFullScreenIntentSettings(activity)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        alarmChannel = channel
    }

    fun capturePayload(intent: Intent?) {
        val payload = intent?.getStringExtra(EXTRA_ALARM_PAYLOAD)
        if (!payload.isNullOrEmpty()) {
            pendingAlarmPayload = payload
        }
    }

    fun deliverPayloadToFlutter() {
        val payload = pendingAlarmPayload ?: return
        if (payload == lastDeliveredPayload) {
            return
        }
        val channel = alarmChannel ?: return
        lastDeliveredPayload = payload
        channel.invokeMethod("alarmLaunched", payload)
    }

    fun consumePayload(): String? {
        val payload = pendingAlarmPayload
        pendingAlarmPayload = null
        lastDeliveredPayload = null
        return payload
    }

    fun clearDeliveryState() {
        pendingAlarmPayload = null
        lastDeliveredPayload = null
    }

    fun bindAlarmChannel(context: android.content.Context, flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        registerAlarmHandlers(
            channel = channel,
            scheduleNativeAlarm = { args ->
                val triggerAtMillis = (args["triggerAtMillis"] as Number).toLong()
                val notificationId = args["notificationId"] as Int
                val payload = args["payload"] as String
                val title = args["title"] as? String ?: "Recordatorio Noty"
                val body = args["body"] as? String ?: "Es hora de tu recordatorio"
                NativeAlarmScheduler.schedule(
                    context = context.applicationContext,
                    triggerAtMillis = triggerAtMillis,
                    notificationId = notificationId,
                    payload = payload,
                    title = title,
                    body = body,
                )
            },
            cancelNativeAlarm = { notificationId ->
                NativeAlarmScheduler.cancel(context.applicationContext, notificationId)
            },
        )
    }

    fun prepareOverlayWindow(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
            val keyguard = activity.getSystemService(KeyguardManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                keyguard?.requestDismissKeyguard(activity, null)
            }
        }
        activity.window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return
        }
        @Suppress("DEPRECATION")
        activity.window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
        )
    }

    fun alarmActivityIntent(context: android.content.Context, payload: String): Intent {
        storePayload(payload)
        return Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra(EXTRA_ALARM_PAYLOAD, payload)
        }
    }

    fun openFullScreenIntentSettings(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivity(intent)
        }
    }
}
