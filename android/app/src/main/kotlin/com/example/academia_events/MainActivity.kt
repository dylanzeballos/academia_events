package com.example.academia_events

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Canal usado por los push de FCM (android.notification.channel_id).
     * Con IMPORTANCE_HIGH los avisos aparecen como banner en pantalla.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Avisos y novedades",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Recordatorios de eventos, clases y membresías"
            enableLights(true)
            enableVibration(true)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "academia_notifications"
    }
}
