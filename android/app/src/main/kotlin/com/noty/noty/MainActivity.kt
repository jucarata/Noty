package com.noty.noty

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun getCachedEngineId(): String = NotyApplication.MAIN_ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        AlarmLaunchHelper.capturePayload(intent)
        if (intent?.getStringExtra(AlarmLaunchHelper.EXTRA_ALARM_PAYLOAD) != null) {
            AlarmLaunchHelper.prepareOverlayWindow(this)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        AlarmLaunchHelper.capturePayload(intent)
        if (intent.getStringExtra(AlarmLaunchHelper.EXTRA_ALARM_PAYLOAD) != null) {
            AlarmLaunchHelper.prepareOverlayWindow(this)
        }
        AlarmLaunchHelper.deliverPayloadToFlutter()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmLaunchHelper.bindAlarmChannel(this, flutterEngine)
        AlarmLaunchHelper.deliverPayloadToFlutter()
    }

    override fun onDestroy() {
        if (isFinishing) {
            AlarmSoundHolder.stop()
        }
        super.onDestroy()
    }
}
