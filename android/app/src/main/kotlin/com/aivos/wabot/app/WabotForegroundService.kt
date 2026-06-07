package com.aivos.wabot.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class WabotForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID   = "wabot_bot_service"
        private const val NOTIFICATION_ID = 1001
        private const val TAG = "WabotService"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Wabot actif", "Le bot WhatsApp tourne en arrière-plan"))
        Log.i(TAG, "ForegroundService démarré")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val status = intent?.getStringExtra("status") ?: "actif"
        val detail = intent?.getStringExtra("detail") ?: "Le bot WhatsApp tourne en arrière-plan"

        // Mettre à jour la notification
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification("Wabot $status", detail))

        // START_STICKY → le service redémarre automatiquement si Android le tue
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // L'utilisateur a swipé l'app — redémarrer le service
        Log.w(TAG, "App retirée des recents — redémarrage du service")
        val restart = Intent(applicationContext, WabotForegroundService::class.java)
        restart.setPackage(packageName)
        startForegroundService(restart)
        super.onTaskRemoved(rootIntent)
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Wabot Bot Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Maintient le bot WhatsApp en arrière-plan"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
}
