package com.mahmoudsayed.niyyahtracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AzanPlayerService : Service() {
    companion object {
        const val TAG = "AzanPlayerService"
        const val CHANNEL_ID = "azan_playback_channel"
        const val NOTIFICATION_ID = 4000
        const val ACTION_STOP = "com.mahmoudsayed.niyyahtracker.STOP_AZAN"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "Stop action received")
            stopPlayback()
            return START_NOT_STICKY
        }

        val filePath = intent?.getStringExtra(AzanAlarmReceiver.EXTRA_FILE_PATH)
        val prayerName = intent?.getStringExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME) ?: "الصلاة"

        if (filePath == null) {
            Log.e(TAG, "No file path provided")
            stopSelf()
            return START_NOT_STICKY
        }

        // Start foreground immediately to avoid ANR
        startForeground(NOTIFICATION_ID, createNotification(prayerName))

        // Play audio
        playAzan(filePath, prayerName)

        return START_NOT_STICKY
    }

    private fun playAzan(filePath: String, prayerName: String) {
        try {
            // Stop any existing playback
            mediaPlayer?.apply {
                try {
                    if (isPlaying) stop()
                    release()
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping old player", e)
                }
            }

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(filePath)
                prepare()
                setOnCompletionListener {
                    Log.d(TAG, "Azan playback completed for $prayerName")
                    stopPlayback()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    stopPlayback()
                    true
                }
                start()
            }

            Log.d(TAG, "Playing azan for $prayerName from $filePath")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing azan", e)
            stopPlayback()
        }
    }

    private fun stopPlayback() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping playback", e)
        }
        mediaPlayer = null
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "الأذان",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "تشغيل الأذان عند دخول وقت الصلاة"
                setSound(null, null) // Sound is played via MediaPlayer
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(prayerName: String): Notification {
        val stopIntent = Intent(this, AzanPlayerService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent to open the app when notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 1, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🕌 حان وقت صلاة $prayerName")
            .setContentText("الله أكبر الله أكبر - حان الآن موعد أذان $prayerName")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openAppPendingIntent)
            .addAction(0, "إيقاف الأذان ⏹", stopPendingIntent)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "NiyyahTracker::AzanWakeLock"
        ).apply {
            acquire(10 * 60 * 1000L) // 10 minutes max
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock", e)
        }
        wakeLock = null
    }

    override fun onDestroy() {
        stopPlayback()
        super.onDestroy()
    }
}
