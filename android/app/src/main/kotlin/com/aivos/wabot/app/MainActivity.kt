package com.aivos.wabot.app

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG         = "WabotMain"
        private const val BOT_CHANNEL = "com.aivos.wabot/bot_engine"
        private const val BOT_EVENTS  = "com.aivos.wabot/bot_events"
        // Flutter bundles assets under flutter_assets/ inside the APK's Android assets
        private const val FLUTTER_ASSETS_PREFIX = "flutter_assets/assets/nodejs-project"
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
            val mainJs  = File(nodeDir, "main.js")

            // Re-extract if main.js is missing OR if the app was updated
            if (!mainJs.exists() || shouldUpdateNodeProject()) {
                Log.d(TAG, "Extracting nodejs-project (mainJs.exists=${mainJs.exists()}, shouldUpdate=${shouldUpdateNodeProject()})")
                extractNodeProject(nodeDir)

                // Verify extraction succeeded before proceeding
                if (!mainJs.exists()) {
                    Log.e(TAG, "Extraction failed — main.js still missing at ${mainJs.absolutePath}")
                    result.error("EXTRACT_FAILED", "Failed to extract nodejs-project/main.js from APK assets", null)
                    return
                }
                markNodeProjectUpdated()
                Log.d(TAG, "Extraction complete: ${mainJs.absolutePath} (${mainJs.length()} bytes)")
            } else {
                Log.d(TAG, "nodejs-project up to date, skipping extraction")
            }

            BotEngine.registerNodeDataDirPath(dataDir)
            BotLauncher.launch(mainJs.absolutePath, dataDir)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "startEmbeddedBot failed: ${e.message}", e)
            result.error("START_FAILED", e.message, null)
        }
    }

    /**
     * Extracts files from Flutter's assets (stored under flutter_assets/ in the APK)
     * into the app's internal files directory.
     *
     * Flutter bundles declared assets at:  flutter_assets/<pubspec-declared-path>
     * e.g. assets/nodejs-project/main.js → flutter_assets/assets/nodejs-project/main.js
     */
    private fun extractNodeProject(destDir: File) {
        destDir.mkdirs()
        val list = try {
            assets.list(FLUTTER_ASSETS_PREFIX)
        } catch (e: Exception) {
            Log.e(TAG, "assets.list($FLUTTER_ASSETS_PREFIX) failed: ${e.message}")
            null
        }

        if (list.isNullOrEmpty()) {
            Log.e(TAG, "No files found under $FLUTTER_ASSETS_PREFIX — APK assets may not contain nodejs-project")
            return
        }

        Log.d(TAG, "Found ${list.size} file(s) in $FLUTTER_ASSETS_PREFIX: ${list.joinToString()}")
        for (filename in list) {
            val src = "$FLUTTER_ASSETS_PREFIX/$filename"
            val dst = File(destDir, filename)
            try {
                assets.open(src).use { input ->
                    FileOutputStream(dst).use { out -> input.copyTo(out) }
                }
                Log.d(TAG, "Extracted: $filename (${dst.length()} bytes)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to extract $filename: ${e.message}")
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
