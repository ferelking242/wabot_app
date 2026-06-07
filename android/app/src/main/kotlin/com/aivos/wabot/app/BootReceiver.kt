package com.aivos.wabot.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {

            Log.i("WabotBoot", "Boot détecté — démarrage Wabot")

            // Démarrer le ForegroundService d'abord (ne nécessite pas l'UI)
            try {
                val svc = Intent(context, WabotForegroundService::class.java)
                context.startForegroundService(svc)
            } catch (e: Exception) {
                Log.e("WabotBoot", "Impossible de démarrer le service: ${e.message}")
            }

            // Ouvrir MainActivity (reactivate UI)
            try {
                val main = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("from_boot", true)
                }
                context.startActivity(main)
            } catch (e: Exception) {
                Log.e("WabotBoot", "Impossible d'ouvrir MainActivity: ${e.message}")
            }
        }
    }
}
