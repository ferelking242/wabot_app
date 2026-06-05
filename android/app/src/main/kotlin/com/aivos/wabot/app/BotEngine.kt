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

        // Called from native (JNI) when Node.js sends a message
        @JvmStatic
        fun sendMessageToApplication(channelName: String, msg: String) {
            Log.d(TAG, "Node → Flutter [$channelName]: $msg")
            messageCallback?.invoke(channelName, msg)
        }

        var messageCallback: ((String, String) -> Unit)? = null
    }
}

object BotLauncher {
    @Volatile
    var started = false

    fun launch(scriptPath: String, dataDir: String) {
        if (started) return
        started = true
        Thread {
            try {
                val env = mapOf(
                    "PORT" to "3001",
                    "WABOT_DATA_DIR" to dataDir,
                    "WABOT_AUTH_KEY" to "wabot_embedded_v1",
                    "NODE_ENV" to "production"
                )
                env.forEach { (k, v) ->
                    try {
                        val pid = android.os.Process.myPid()
                        // set via process.env in Node.js, injected via --env-file or env vars
                        // We pass them via the NODE_PATH / env mechanism
                        System.setProperty("wabot.$k", v)
                    } catch (_: Exception) {}
                }
                // Set Android-specific env vars before starting
                android.system.Os.setenv("PORT", "3001", true)
                android.system.Os.setenv("WABOT_DATA_DIR", dataDir, true)
                android.system.Os.setenv("WABOT_AUTH_KEY", "wabot_embedded_v1", true)
                android.system.Os.setenv("NODE_ENV", "production", true)

                BotEngine.startNodeWithArguments(
                    arrayOf("node", scriptPath),
                    "",
                    true
                )
            } catch (e: Exception) {
                android.util.Log.e("BotLauncher", "Node.js crashed: ${e.message}", e)
            }
        }.also { it.name = "wabot-node-thread" }.start()
    }
}
