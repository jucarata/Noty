package com.noty.noty

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class NotyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
        warmUpFlutterEngine()
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                currentActivity = activity
            }

            override fun onActivityPaused(activity: Activity) {
                if (currentActivity == activity) {
                    currentActivity = null
                }
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    private fun warmUpFlutterEngine() {
        if (FlutterEngineCache.getInstance().contains(NotyApplication.MAIN_ENGINE_ID)) {
            return
        }
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(MAIN_ENGINE_ID, engine)
    }

    companion object {
        const val MAIN_ENGINE_ID = "noty_engine"
        lateinit var instance: Application
            private set
        var currentActivity: Activity? = null
            private set
    }
}
