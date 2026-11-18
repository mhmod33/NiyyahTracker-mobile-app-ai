package com.mahmoudsayed.niyyahtracker

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.View
import android.view.WindowManager
import android.view.animation.Animation
import android.view.animation.ScaleAnimation
import android.widget.Button
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-screen lock-screen Activity displaying the Call to Prayer (Adhan),
 * similar to the Prayer Now app.
 *
 * Features:
 * - Wakes the screen when locked (turnScreenOn + wakeLock).
 * - Shows directly above the lock screen (showWhenLocked).
 * - Displays prayer name, takbeer, mosque visual, and current time.
 * - Stops the Adhan and closes when the user clicks "إيقاف الأذان".
 * - Stops the Adhan when volume down button is pressed once (handled in AzanPlayerService).
 * - User decides when to close (no auto-close on unlock).
 * - Automatically closes when audio playback ends.
 */
class AdhanLockScreenActivity : Activity() {

    companion object {
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME = "prayer_time"
        private const val WAKE_LOCK_TAG = "Basair::AdhanLockScreenWakeLock"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var unlockReceiver: BroadcastReceiver? = null
    private var adhanStoppedReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AzanAlarmReceiver.writeLog(this, "AdhanLockScreenActivity.onCreate")

        // 1. Setup window flags to display above lock screen & turn screen on
        setupLockScreenWindow()

        // 2. Set content layout
        setContentView(R.layout.activity_adhan_lockscreen)

        // 3. Populate data (prayer name, time)
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        var prayerTime = intent.getStringExtra(EXTRA_PRAYER_TIME)
        if (prayerTime.isNullOrEmpty()) {
            val sdf = SimpleDateFormat("hh:mm a", Locale("ar"))
            prayerTime = sdf.format(Date())
        }

        val tvPrayerName = findViewById<TextView>(R.id.tv_prayer_name)
        val tvPrayerTime = findViewById<TextView>(R.id.tv_prayer_time)
        val btnStopAdhan = findViewById<Button>(R.id.btn_stop_adhan)
        val iconContainer = findViewById<View>(R.id.icon_container)

        tvPrayerName?.text = "صلاة $prayerName"
        tvPrayerTime?.text = prayerTime

        // 4. Subtle pulsing animation on mosque icon
        val pulse = ScaleAnimation(
            1.0f, 1.08f, 1.0f, 1.08f,
            Animation.RELATIVE_TO_SELF, 0.5f,
            Animation.RELATIVE_TO_SELF, 0.5f
        ).apply {
            duration = 1000
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        iconContainer?.startAnimation(pulse)

        // 5. Button "إيقاف الأذان" click listener
        btnStopAdhan?.setOnClickListener {
            AzanAlarmReceiver.writeLog(this, "AdhanLockScreenActivity: Stop button clicked")
            stopAdhanAndFinish()
        }

        // 6. User decides when to close - no auto-close on unlock
        // Volume down button (once) will stop Adhan (handled in AzanPlayerService)
        // registerUnlockReceiver() // REMOVED: User wants manual control

        // 7. Listen for Adhan completion or stop from elsewhere
        registerAdhanStoppedReceiver()
    }

    private fun setupLockScreenWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        // Acquire a bright wake lock to wake the device screen
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                WAKE_LOCK_TAG
            ).apply {
                acquire(3 * 60 * 1000L) // 3 minutes timeout
            }
        } catch (e: Exception) {
            AzanAlarmReceiver.writeLog(this, "AdhanLockScreenActivity: WakeLock failed: $e")
        }
    }

    /**
     * Receives ACTION_USER_PRESENT when the user unlocks their phone.
     * When unlocked, this turns off the Adhan and closes the screen.
     */
    private fun registerUnlockReceiver() {
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        unlockReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_USER_PRESENT) {
                    AzanAlarmReceiver.writeLog(
                        this@AdhanLockScreenActivity,
                        "AdhanLockScreenActivity: User unlocked device (ACTION_USER_PRESENT) -> turning off Adhan"
                    )
                    stopAdhanAndFinish()
                }
            }
        }
        registerReceiver(unlockReceiver, filter)
    }

    /**
     * Listens for when AzanPlayerService stops (completed or dismissed).
     */
    private fun registerAdhanStoppedReceiver() {
        val filter = IntentFilter(AzanPlayerService.ACTION_ADHAN_STOPPED)
        adhanStoppedReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                AzanAlarmReceiver.writeLog(
                    this@AdhanLockScreenActivity,
                    "AdhanLockScreenActivity: ACTION_ADHAN_STOPPED received -> closing screen"
                )
                finishAndRemoveTaskSafe()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(adhanStoppedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(adhanStoppedReceiver, filter)
        }
    }

    private fun stopAdhanAndFinish() {
        try {
            // 1. Tell AzanPlayerService to stop
            val stopIntent = Intent(this, AzanPlayerService::class.java).apply {
                action = AzanPlayerService.ACTION_STOP
            }
            startService(stopIntent)
            stopService(Intent(this, AzanPlayerService::class.java))
        } catch (_: Exception) {}

        // 2. Dismiss notifications
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(AzanPlayerService.NOTIFICATION_ID)
            nm.cancel(AzanPlayerService.NOTIFICATION_ID_FLUTTER)
        } catch (_: Exception) {}

        finishAndRemoveTaskSafe()
    }

    private fun finishAndRemoveTaskSafe() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                finishAndRemoveTask()
            } else {
                finish()
            }
        } catch (_: Exception) {
            finish()
        }
    }

    override fun onDestroy() {
        AzanAlarmReceiver.writeLog(this, "AdhanLockScreenActivity.onDestroy")
        try {
            unlockReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        unlockReceiver = null

        try {
            adhanStoppedReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        adhanStoppedReceiver = null

        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (_: Exception) {}
        wakeLock = null

        super.onDestroy()
    }
}
