package com.example.connectbanking.connect_banking

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

// A call keeps going while the app is in the background (docs/CONTRACT.md V10): a foreground service of type
// microphone, with an ongoing notification, for as long as the call lasts.
class CallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Calls", NotificationManager.IMPORTANCE_LOW))
        }
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_money)
            .setContentTitle("Call with Nationwide")
            .setContentText("You're on a call with our assistant.")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(ID, notification)
        }
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL = "calls"
        private const val ID = 4201

        fun start(context: Context) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, CallService::class.java))
            } catch (error: Exception) {
                // Not allowed just now (for example started from the background): the call still works in the foreground.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallService::class.java))
        }
    }
}
