package com.aivos.wabot.app

  import android.app.ActivityManager
  import android.content.Context
  import android.content.Intent
  import android.os.Build
  import android.util.Log
  import io.flutter.embedding.android.FlutterActivity
  import io.flutter.embedding.engine.FlutterEngine
  import io.flutter.plugin.common.EventChannel
  import io.flutter.plugin.common.MethodChannel
  import java.io.File
  import java.io.FileOutputStream

  class MainActivity : FlutterActivity() {

      companion object {
          private const val TAG                  = "WabotMain"
          private const val BOT_CHANNEL          = "com.aivos.wabot/bot_engine"
          private const val BOT_EVENTS           = "com.aivos.wabot/bot_events"
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
                      "stopBot"  -> result.success(true)
                      "isRunning" -> result.success(BotLauncher.running)

                      // Démarrer le service foreground (maintient le bot en vie)
                      "startForegroundService" -> {
                          try {
                              val intent = Intent(this, WabotForegroundService::class.java)
                              startForegroundService(intent)
                              result.success(true)
                          } catch (e: Exception) {
                              Log.e(TAG, "startForegroundService failed: ${e.message}")
                              result.success(false)
                          }
                      }

                      // Arrêter le service foreground
                      "stopForegroundService" -> {
                          try {
                              stopService(Intent(this, WabotForegroundService::class.java))
                              result.success(true)
                          } catch (e: Exception) {
                              result.success(false)
                          }
                      }

                      // Retourner le SDK Android (pour les permissions runtime)
                      "getSdkInt" -> result.success(Build.VERSION.SDK_INT.toString())

                      else -> result.notImplemented()
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

      override fun onResume() {
          super.onResume()
          // S'assurer que le service foreground tourne quand l'app est au premier plan
          if (BotLauncher.started) {
              try {
                  startForegroundService(Intent(this, WabotForegroundService::class.java))
              } catch (_: Exception) {}
          }
      }

      private fun getTotalRamMb(): Long {
          return try {
              val mi = ActivityManager.MemoryInfo()
              (getSystemService(ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mi)
              mi.totalMem / (1024L * 1024L)
          } catch (_: Exception) { 0L }
      }

      private fun startEmbeddedBot(dataDir: String, result: MethodChannel.Result) {
          if (BotLauncher.started) { result.success(true); return }
          try {
              File(dataDir).mkdirs()
              val nodeDir = File(filesDir, "nodejs-project")
              val mainJs  = File(nodeDir, "main.js")

              if (!mainJs.exists() || shouldUpdateNodeProject()) {
                  Log.d(TAG, "Extraction nodejs-project...")
                  extractNodeProject(nodeDir)
                  if (!mainJs.exists()) {
                      result.error("EXTRACT_FAILED", "main.js manquant après extraction", null)
                      return
                  }
                  markNodeProjectUpdated()
              }

              // Passer les infos du device Android à Node.js via les variables d'environnement
              try {
                  android.system.Os.setenv("DEVICE_TOTAL_RAM_MB",      getTotalRamMb().toString(),                   true)
                  android.system.Os.setenv("DEVICE_CPU_CORES",         Runtime.getRuntime().availableProcessors().toString(), true)
                  android.system.Os.setenv("DEVICE_MODEL",             Build.MODEL,                                  true)
                  android.system.Os.setenv("DEVICE_BRAND",             Build.BRAND,                                  true)
                  android.system.Os.setenv("DEVICE_MANUFACTURER",      Build.MANUFACTURER,                           true)
                  android.system.Os.setenv("DEVICE_ANDROID_VERSION",   Build.VERSION.RELEASE,                        true)
                  android.system.Os.setenv("DEVICE_SDK_INT",           Build.VERSION.SDK_INT.toString(),             true)
                  android.system.Os.setenv("DEVICE_HARDWARE",          Build.HARDWARE,                               true)
                  Log.d(TAG, "Device info: RAM=${getTotalRamMb()}MB CPU=${Runtime.getRuntime().availableProcessors()} model=${Build.MODEL}")
              } catch (e: Exception) {
                  Log.w(TAG, "setenv device info: ${e.message}")
              }

              BotEngine.registerNodeDataDirPath(dataDir)
              BotLauncher.launch(mainJs.absolutePath, dataDir)

              // Démarrer le ForegroundService immédiatement
              try {
                  startForegroundService(Intent(this, WabotForegroundService::class.java))
              } catch (e: Exception) {
                  Log.w(TAG, "ForegroundService non démarré: ${e.message}")
              }

              result.success(true)
          } catch (e: Exception) {
              Log.e(TAG, "startEmbeddedBot failed: ${e.message}", e)
              result.error("START_FAILED", e.message, null)
          }
      }

      private fun extractNodeProject(destDir: File) {
          destDir.mkdirs()
          val list = try {
              assets.list(FLUTTER_ASSETS_PREFIX)
          } catch (e: Exception) {
              Log.e(TAG, "assets.list failed: ${e.message}")
              null
          }

          if (list.isNullOrEmpty()) {
              Log.e(TAG, "Aucun fichier dans $FLUTTER_ASSETS_PREFIX")
              return
          }

          for (filename in list) {
              val src = "$FLUTTER_ASSETS_PREFIX/$filename"
              val dst = File(destDir, filename)
              try {
                  assets.open(src).use { input ->
                      FileOutputStream(dst).use { out -> input.copyTo(out) }
                  }
                  Log.d(TAG, "Extrait: $filename (${dst.length()} bytes)")
              } catch (e: Exception) {
                  Log.e(TAG, "Extraction échouée pour $filename: ${e.message}")
              }
          }
      }

      private fun shouldUpdateNodeProject(): Boolean {
          val prefs = getSharedPreferences("wabot_prefs", Context.MODE_PRIVATE)
          val stored = prefs.getString("node_project_version", null)
          val current = try {
              packageManager.getPackageInfo(packageName, 0).longVersionCode.toString()
          } catch (_: Exception) { "0" }
          return stored != current
      }

      private fun markNodeProjectUpdated() {
          val current = try {
              packageManager.getPackageInfo(packageName, 0).longVersionCode.toString()
          } catch (_: Exception) { "0" }
          getSharedPreferences("wabot_prefs", Context.MODE_PRIVATE)
              .edit().putString("node_project_version", current).apply()
      }
  }
  