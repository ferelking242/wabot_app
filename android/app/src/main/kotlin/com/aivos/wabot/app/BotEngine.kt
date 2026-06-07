package com.aivos.wabot.app

import android.util.Log

class BotEngine {
    companion object {
        private const val TAG = "WabotBotEngine"

        init {
            System.loadLibrary("nodejs-mobile-native-lib")
            System.loadLibrary("node")
        }

        @JvmStatic
        external fun registerNodeDataDirPath(dataDir: String)

        @JvmStatic
        external fun getCurrentABIName(): String

        @JvmStatic
        external fun startNodeWithArguments(
            arguments: Array<String>,
            modulesPath: String,
            option_redirectOutputToLogcat: Boolean
        ): Int

        @JvmStatic
        external fun sendMessageToNodeChannel(channelName: String, msg: String)

        @JvmStatic
        fun sendMessageToApplication(channelName: String, msg: String) {
            Log.d(TAG, "Node → Flutter [$channelName]: $msg")
            messageCallback?.invoke(channelName, msg)
        }

        var messageCallback: ((String, String) -> Unit)? = null
    }
}

object BotLauncher {
    @Volatile var started  = false
    @Volatile var running  = false   // true uniquement quand Node tourne réellement

    private var scriptPath = ""
    private var dataDir    = ""

    fun launch(script: String, data: String) {
        scriptPath = script
        dataDir    = data
        if (started) return
        _startThread()
    }

    private fun _startThread() {
        started = true
        running = false

        Thread {
            var attempts = 0
            while (true) {
                attempts++
                android.util.Log.i("BotLauncher", "Démarrage Node.js (tentative #$attempts)")
                try {
                    android.system.Os.setenv("PORT",            "3001",               true)
                    android.system.Os.setenv("WABOT_DATA_DIR",  dataDir,              true)
                    android.system.Os.setenv("WABOT_AUTH_KEY",  "wabot_embedded_v1",  true)
                    android.system.Os.setenv("NODE_ENV",        "production",         true)

                    running = true
                    // Appel BLOQUANT — revient quand Node.js se termine
                    val exitCode = BotEngine.startNodeWithArguments(
                        arrayOf("node", scriptPath),
                        "",
                        true
                    )
                    running = false
                    android.util.Log.w("BotLauncher", "Node.js terminé avec code $exitCode")
                } catch (e: Exception) {
                    running = false
                    android.util.Log.e("BotLauncher", "Node.js exception: ${e.message}", e)
                }

                // Attendre avant de redémarrer (backoff simple)
                val delay = when {
                    attempts < 3 -> 3_000L
                    attempts < 6 -> 6_000L
                    else         -> 15_000L
                }
                android.util.Log.i("BotLauncher", "Redémarrage dans ${delay / 1000}s...")
                Thread.sleep(delay)
            }
        }.also {
            it.name       = "wabot-node-thread"
            it.isDaemon   = true  // thread daemon → ne bloque pas la fermeture de l'app
        }.start()
    }
}
