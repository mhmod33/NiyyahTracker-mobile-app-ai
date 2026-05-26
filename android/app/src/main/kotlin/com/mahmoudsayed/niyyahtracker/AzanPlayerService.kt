package com.mahmoudsayed.niyyahtracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

class AzanPlayerService : Service() {
    companion object {
        const val TAG = "AzanPlayerService"
        const val CHANNEL_ID = "azan_playback_channel"
        const val NOTIFICATION_ID = 4006
        const val NOTIFICATION_ID_FLUTTER = 4000
        const val ACTION_STOP = "com.mahmoudsayed.niyyahtracker.STOP_AZAN"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeObserver: ContentObserver? = null
    private var lastAlarmVolume: Int = -1
    private var lastMusicVolume: Int = -1
    private var isStopping = false

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
            registerVolumeDownObserver()

            Log.d(TAG, "Playing azan for $prayerName from $filePath")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing azan", e)
            stopPlayback()
        }
    }

    private fun stopPlayback() {
        if (isStopping) return
        isStopping = true
        unregisterVolumeDownObserver()
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
        // Cancel Flutter's notification 4000 so its stop monitor triggers
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(NOTIFICATION_ID_FLUTTER)
            nm.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun registerVolumeDownObserver() {
        unregisterVolumeDownObserver()
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            lastAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            lastMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)
                    stopIfVolumeWasLowered()
                }
            }
            contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI,
                true,
                volumeObserver!!
            )
            Log.d(TAG, "Volume-down observer registered, alarm=$lastAlarmVolume, music=$lastMusicVolume")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering volume observer", e)
        }
    }

    private fun unregisterVolumeDownObserver() {
        try {
            volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering volume observer", e)
        }
        volumeObserver = null
        lastAlarmVolume = -1
        lastMusicVolume = -1
    }

    private fun stopIfVolumeWasLowered() {
        try {
            if (isStopping || mediaPlayer == null) return
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val currentAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            val currentMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val alarmLowered = lastAlarmVolume >= 0 && currentAlarmVolume < lastAlarmVolume
            val musicLowered = lastMusicVolume >= 0 && currentMusicVolume < lastMusicVolume
            if (alarmLowered || musicLowered) {
                Log.d(
                    TAG,
                    "Volume lowered, stopping azan. alarm=$lastAlarmVolume->$currentAlarmVolume music=$lastMusicVolume->$currentMusicVolume"
                )
                stopPlayback()
                return
            }
            lastAlarmVolume = currentAlarmVolume
            lastMusicVolume = currentMusicVolume
        } catch (e: Exception) {
            Log.e(TAG, "Error checking alarm volume", e)
        }
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
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(openAppPendingIntent)
            .setDeleteIntent(stopPendingIntent)
            .addAction(0, "إيقاف الأذان ⏹", stopPendingIntent)
            .build()
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Basair::AzanWakeLock"
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
