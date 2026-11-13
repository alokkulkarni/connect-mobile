package com.connectbanking.call

// A foreground service of type microphone while a call is going, so it carries on when the customer switches apps
// (CONTRACT.md V10). It shows the system's ongoing-call notification; tapping it returns to the app.

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class CallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Calls", NotificationManager.IMPORTANCE_LOW))
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("On a call with us")
            .setContentText("Tap to go back to the app.")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setContentIntent(open)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL = "calls"
        private const val NOTIFICATION_ID = 4711
    }
}
