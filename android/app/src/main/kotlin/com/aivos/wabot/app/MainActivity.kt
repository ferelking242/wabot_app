package com.aivos.wabot.app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val BOT_CHANNEL = "com.aivos.wabot/bot_engine"
        private const val BOT_EVENTS  = "com.aivos.wabot/bot_events"
    }

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BOT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBot" -> {
                        val dataDir = call.argument<String>("dataDir")
                            ?: "${filesDir.absolutePath}/wabot"
                        startEmbeddedBot(dataDir, result)
                    }
                    "stopBot"   -> result.success(true)
                    "isRunning" -> result.success(BotLauncher.started)
                    else        -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BOT_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) { eventSink = null }
            })

        BotEngine.messageCallback = { channel, msg ->
            runOnUiThread { eventSink?.success(mapOf("channel" to channel, "msg" to msg)) }
        }
    }

    private fun startEmbeddedBot(dataDir: String, result: MethodChannel.Result) {
        if (BotLauncher.started) { result.success(true); return }
        try {
            File(dataDir).mkdirs()
            val nodeDir = File(filesDir, "nodejs-project")
            if (!nodeDir.exists() || shouldUpdateNodeProject()) {
                extractNodeProject(nodeDir)
                markNodeProjectUpdated()
            }
            val scriptPath = File(nodeDir, "main.js").absolutePath
            BotEngine.registerNodeDataDirPath(dataDir)
            BotLauncher.launch(scriptPath, dataDir)
            result.success(true)
        } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun extractNodeProject(destDir: File) {
        destDir.mkdirs()
        val list = assets.list("nodejs-project") ?: return
        for (filename in list) {
            assets.open("nodejs-project/$filename").use { input ->
                FileOutputStream(File(destDir, filename)).use { out -> input.copyTo(out) }
            }
        }
    }

    private fun shouldUpdateNodeProject(): Boolean {
        val prefs = getSharedPreferences("wabot_prefs", Context.MODE_PRIVATE)
        return prefs.getString("node_project_version", "") != appVersion()
    }

    private fun markNodeProjectUpdated() {
        getSharedPreferences("wabot_prefs", Context.MODE_PRIVATE).edit()
            .putString("node_project_version", appVersion()).apply()
    }

    private fun appVersion(): String = try {
        packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0"
    } catch (_: Exception) { "1.0" }
}
