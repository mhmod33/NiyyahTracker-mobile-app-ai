package com.mahmoudsayed.niyyahtracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File

/**
 * Reschedules all native azan AlarmManager alarms after a device reboot.
 *
 * Android cancels all AlarmManager alarms when the device restarts.
 * This receiver fires on BOOT_COMPLETED and reads the alarm data that
 * MainActivity.scheduleAzan() persisted to SharedPreferences, then
 * re-registers each alarm that hasn't yet passed.
 */
class AzanBootReceiver : BroadcastReceiver() {

    companion object {
        // IDs must match the constants in azan_service.dart
        private val ALARM_IDS = intArrayOf(5001, 5002, 5003, 5004, 5005)
        private const val PREFS_NAME = "azan_alarms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON" &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        AzanAlarmReceiver.writeLog(context, "AzanBootReceiver: boot completed — rescheduling alarms")

        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()

        for (alarmId in ALARM_IDS) {
            val triggerMs = sp.getLong("alarm_${alarmId}_triggerMs", 0L)
            val filePath  = sp.getString("alarm_${alarmId}_filePath", null)
            val name      = sp.getString("alarm_${alarmId}_prayerName", null)

            if (triggerMs == 0L || filePath == null || name == null) continue

            // Skip alarms that already passed — no point ringing late
            if (triggerMs <= now) {
                AzanAlarmReceiver.writeLog(context, "AzanBootReceiver: skipping past alarm id=$alarmId ($name) triggerMs=$triggerMs")
                continue
            }

            // Verify the audio file still exists
            if (!File(filePath).exists()) {
                AzanAlarmReceiver.writeLog(context, "AzanBootReceiver: audio file missing for id=$alarmId ($name) path=$filePath — skipping")
                continue
            }

            val receiverIntent = Intent(context, AzanAlarmReceiver::class.java).apply {
                putExtra(AzanAlarmReceiver.EXTRA_FILE_PATH, filePath)
                putExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME, name)
                putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, alarmId)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context, alarmId, receiverIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerMs, pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP, triggerMs, pendingIntent
                        )
                    }
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerMs, pendingIntent
                    )
                }
                AzanAlarmReceiver.writeLog(context, "AzanBootReceiver: rescheduled alarm id=$alarmId ($name) at $triggerMs")
            } catch (e: Exception) {
                AzanAlarmReceiver.writeLog(context, "AzanBootReceiver: FAILED to reschedule id=$alarmId ($name): $e")
            }
        }
    }
}
