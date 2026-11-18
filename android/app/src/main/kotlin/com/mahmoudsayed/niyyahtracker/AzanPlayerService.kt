package com.mahmoudsayed.niyyahtracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

class AzanPlayerService : Service() {
    companion object {
        const val CHANNEL_ID = "azan_playback_channel"
        const val NOTIFICATION_ID = 4006
        const val NOTIFICATION_ID_FLUTTER = 4000
        const val ACTION_STOP = "com.mahmoudsayed.niyyahtracker.STOP_AZAN"
        const val ACTION_ADHAN_STOPPED = "com.mahmoudsayed.niyyahtracker.ADHAN_STOPPED"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeHandler: Handler? = null
    private var volumeCheckRunnable: Runnable? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var userPresentReceiver: BroadcastReceiver? = null
    private var initialAlarmVolume: Int = -1
    private var initialMusicVolume: Int = -1
    private var isStopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        AzanAlarmReceiver.writeLog(this, "AzanPlayerService.onCreate")
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: ACTION_STOP received")
            stopPlayback()
            return START_NOT_STICKY
        }

        val filePath = intent?.getStringExtra(AzanAlarmReceiver.EXTRA_FILE_PATH)
        val prayerName = intent?.getStringExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME) ?: "الصلاة"

        AzanAlarmReceiver.writeLog(this, "AzanPlayerService.onStartCommand prayer=$prayerName filePath=$filePath")

        if (filePath == null) {
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: filePath null — stopping self")
            stopSelf()
            return START_NOT_STICKY
        }

        val file = File(filePath)
        AzanAlarmReceiver.writeLog(this, "AzanPlayerService: fileExists=${file.exists()} size=${if (file.exists()) file.length() else -1}")

        // Start foreground immediately to avoid ANR
        startForeground(NOTIFICATION_ID, createNotification(prayerName))
        AzanAlarmReceiver.writeLog(this, "AzanPlayerService: startForeground called")

        // Also launch full-screen AdhanLockScreenActivity so it shows over the lock screen (like Prayer Now)
        try {
            val lockIntent = Intent(this, AdhanLockScreenActivity::class.java).apply {
                putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(lockIntent)
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: startActivity(AdhanLockScreenActivity) called OK")
        } catch (e: Exception) {
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: startActivity(AdhanLockScreenActivity) failed: $e")
        }

        // User decides when to close - no auto-close on unlock
        // Volume down button (once) will stop Adhan (handled in startVolumeMonitoring)
        // registerUserPresentReceiver() // REMOVED: User wants manual control

        // Play audio
        playAzan(filePath)

        return START_NOT_STICKY
    }

    private fun playAzan(filePath: String) {
        try {
            // Stop any existing playback
            mediaPlayer?.apply {
                try {
                    if (isPlaying) stop()
                    release()
                } catch (_: Exception) {}
            }

            AzanAlarmReceiver.writeLog(this, "AzanPlayerService.playAzan: creating MediaPlayer for $filePath")

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
                    AzanAlarmReceiver.writeLog(this@AzanPlayerService, "AzanPlayerService: playback completed normally")
                    stopPlayback()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e("AzanPlayerService", "MediaPlayer error what=$what extra=$extra")
                    AzanAlarmReceiver.writeLog(this@AzanPlayerService, "AzanPlayerService: MediaPlayer ERROR what=$what extra=$extra")
                    stopPlayback()
                    true
                }
                start()
            }
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: MediaPlayer.start() called OK")
            startVolumeMonitoring()
        } catch (e: Exception) {
            Log.e("AzanPlayerService", "playAzan exception: $e")
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: playAzan EXCEPTION: $e")
            stopPlayback()
        }
    }

    private fun stopPlayback() {
        if (isStopping) return
        isStopping = true
        AzanAlarmReceiver.writeLog(this, "AzanPlayerService.stopPlayback called")
        stopVolumeMonitoring()
        // unregisterUserPresentReceiver() // REMOVED: Not needed anymore

        // Notify AdhanLockScreenActivity to close
        try {
            sendBroadcast(Intent(ACTION_ADHAN_STOPPED).setPackage(packageName))
        } catch (_: Exception) {}

        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (_: Exception) {}
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

    private fun registerUserPresentReceiver() {
        if (userPresentReceiver != null) return
        try {
            val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
            userPresentReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == Intent.ACTION_USER_PRESENT) {
                        AzanAlarmReceiver.writeLog(
                            this@AzanPlayerService,
                            "AzanPlayerService: Device unlocked (ACTION_USER_PRESENT) -> stopping Adhan"
                        )
                        stopPlayback()
                    }
                }
            }
            registerReceiver(userPresentReceiver, filter)
        } catch (e: Exception) {
            AzanAlarmReceiver.writeLog(this, "AzanPlayerService: registerUserPresentReceiver failed: $e")
        }
    }

    private fun unregisterUserPresentReceiver() {
        try {
            userPresentReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        userPresentReceiver = null
    }

    private fun isMuteOnVolumeDownEnabled(): Boolean {
        return try {
            val sp = getSharedPreferences("azan_prefs", Context.MODE_PRIVATE)
            sp.getBoolean("mute_on_volume_down", true)
        } catch (_: Exception) {
            true
        }
    }

    /// Periodically check system volume and listen to volume key broadcasts.
    /// If volume decreases by even 1 step (volume down pressed once while locked),
    /// mute/stop the azan immediately if the setting is enabled.
    private fun startVolumeMonitoring() {
        stopVolumeMonitoring()
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            initialAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            initialMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            AzanAlarmReceiver.writeLog(
                this,
                "AzanPlayerService: initial alarm vol=$initialAlarmVolume music vol=$initialMusicVolume"
            )

            // 1. Dynamic BroadcastReceiver for immediate VOLUME_CHANGED_ACTION (fired when volume buttons pressed)
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            volumeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (isStopping || mediaPlayer == null) return
                    if (!isMuteOnVolumeDownEnabled()) return

                    val prevVol = intent?.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1) ?: -1
                    val currentVol = intent?.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1) ?: -1

                    // Single click on volume down decreases volume (currentVol < prevVol)
                    if (prevVol != -1 && currentVol < prevVol) {
                        AzanAlarmReceiver.writeLog(
                            this@AzanPlayerService,
                            "AzanPlayerService: volume down pressed once ($currentVol < $prevVol) → muting azan"
                        )
                        stopPlayback()
                        return
                    }
                }
            }
            registerReceiver(volumeReceiver, filter)

            // 2. High-frequency polling (every 100ms) for reliable detection across all device lock states
            volumeHandler = Handler(Looper.getMainLooper())
            volumeCheckRunnable = object : Runnable {
                override fun run() {
                    if (isStopping || mediaPlayer == null) return
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val alarmVol = am.getStreamVolume(AudioManager.STREAM_ALARM)
                    val musicVol = am.getStreamVolume(AudioManager.STREAM_MUSIC)

                    if (isMuteOnVolumeDownEnabled()) {
                        // Volume down pressed once -> volume dropped by 1+ step from initial
                        if ((initialAlarmVolume > 0 && alarmVol < initialAlarmVolume) ||
                            (initialMusicVolume > 0 && musicVol < initialMusicVolume)) {
                            AzanAlarmReceiver.writeLog(
                                this@AzanPlayerService,
                                "AzanPlayerService: volume down pressed ($alarmVol < $initialAlarmVolume) → muting azan"
                            )
                            stopPlayback()
                            return
                        }
                    }

                    // Fallback: If volume dropped to 0
                    if ((initialAlarmVolume > 0 && alarmVol == 0) ||
                        (initialMusicVolume > 0 && musicVol == 0)) {
                        AzanAlarmReceiver.writeLog(
                            this@AzanPlayerService,
                            "AzanPlayerService: volume=0 → stopping azan"
                        )
                        stopPlayback()
                        return
                    }

                    volumeHandler?.postDelayed(this, 100)
                }
            }
            volumeHandler?.post(volumeCheckRunnable!!)
        } catch (_: Exception) {}
    }

    private fun stopVolumeMonitoring() {
        try {
            volumeReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        volumeReceiver = null
        try {
            volumeCheckRunnable?.let { volumeHandler?.removeCallbacks(it) }
        } catch (_: Exception) {}
        volumeCheckRunnable = null
        volumeHandler = null
        initialAlarmVolume = -1
        initialMusicVolume = -1
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
                setShowBadge(false)
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

        // Intent to open the full-screen Adhan lockscreen activity
        val lockScreenIntent = Intent(this, AdhanLockScreenActivity::class.java).apply {
            putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val lockScreenPendingIntent = PendingIntent.getActivity(
            this, 1, lockScreenIntent,
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
            .setContentIntent(lockScreenPendingIntent)
            .setFullScreenIntent(lockScreenPendingIntent, true)
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
        } catch (_: Exception) {}
        wakeLock = null
    }

    override fun onDestroy() {
        AzanAlarmReceiver.writeLog(this, "AzanPlayerService.onDestroy")
        stopPlayback()
        super.onDestroy()
    }
}
