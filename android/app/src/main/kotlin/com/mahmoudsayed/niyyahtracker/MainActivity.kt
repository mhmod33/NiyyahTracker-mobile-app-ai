package com.mahmoudsayed.niyyahtracker

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.mahmoudsayed.niyyahtracker/azan"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAzan" -> {
                        val alarmId = call.argument<Int>("alarmId")!!
                        val triggerAtMs = (call.argument<Number>("triggerAtMs")!!).toLong()
                        val filePath = call.argument<String>("filePath")!!
                        val prayerName = call.argument<String>("prayerName")!!

                        scheduleAzan(alarmId, triggerAtMs, filePath, prayerName)
                        result.success(true)
                    }
                    "cancelAzan" -> {
                        val alarmId = call.argument<Int>("alarmId")!!
                        cancelAzan(alarmId)
                        result.success(true)
                    }
                    "cancelAllAzan" -> {
                        for (id in 5001..5005) {
                            cancelAzan(id)
                        }
                        result.success(true)
                    }
                    "stopAzan" -> {
                        val intent = Intent(this, AzanPlayerService::class.java).apply {
                            action = AzanPlayerService.ACTION_STOP
                        }
                        try {
                            startService(intent)
                        } catch (_: Exception) {}
                        try {
                            stopService(Intent(this, AzanPlayerService::class.java))
                        } catch (_: Exception) {}
                        // Also cancel Flutter and native notifications.
                        try {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.cancel(4000)
                            nm.cancel(4006)
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "setMuteOnVolumeDown" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val sp = getSharedPreferences("azan_prefs", Context.MODE_PRIVATE)
                        sp.edit().putBoolean("mute_on_volume_down", enabled).apply()
                        result.success(true)
                    }
                    "showAdhanLockScreen" -> {
                        val prayerName = call.argument<String>("prayerName") ?: "المغرب"
                        val lockScreenIntent = Intent(this, AdhanLockScreenActivity::class.java).apply {
                            putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(lockScreenIntent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleAzan(alarmId: Int, triggerAtMs: Long, filePath: String, prayerName: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(this, AzanAlarmReceiver::class.java).apply {
            putExtra(AzanAlarmReceiver.EXTRA_FILE_PATH, filePath)
            putExtra(AzanAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AzanAlarmReceiver.EXTRA_ALARM_ID, alarmId)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent
                )
            }
        } catch (_: Exception) {}

        // Persist alarm data so BootReceiver can reschedule after device restart
        try {
            val sp = getSharedPreferences("azan_alarms", Context.MODE_PRIVATE)
            sp.edit()
                .putLong("alarm_${alarmId}_triggerMs", triggerAtMs)
                .putString("alarm_${alarmId}_filePath", filePath)
                .putString("alarm_${alarmId}_prayerName", prayerName)
                .apply()
        } catch (_: Exception) {}
    }

    private fun cancelAzan(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AzanAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)

        // Remove persisted alarm data so BootReceiver doesn't reschedule it
        try {
            val sp = getSharedPreferences("azan_alarms", Context.MODE_PRIVATE)
            sp.edit()
                .remove("alarm_${alarmId}_triggerMs")
                .remove("alarm_${alarmId}_filePath")
                .remove("alarm_${alarmId}_prayerName")
                .apply()
        } catch (_: Exception) {}
    }
}
