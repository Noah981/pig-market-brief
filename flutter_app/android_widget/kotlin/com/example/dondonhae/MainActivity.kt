package com.example.dondonhae

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "dondonhae/widgets"
    private var initialWidgetRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        initialWidgetRoute = intent?.data?.toString()
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent); setIntent(intent); initialWidgetRoute = intent.data?.toString()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> { WidgetRenderer.updateAll(this); result.success(true) }
                "getInitialRoute" -> { val route = initialWidgetRoute; initialWidgetRoute = null; result.success(route) }
                else -> result.notImplemented()
            }
        }
    }
}
