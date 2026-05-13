package com.mahmoudsayed.niyyahtracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.mahmoudsayed.niyyahtracker/azan"
        const val TAG = "AzanScheduler"
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
                        } catch (e: Exception) {
                            Log.e(TAG, "Error stopping azan service", e)
                        }
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
            Log.d(TAG, "Scheduled azan for $prayerName at $triggerAtMs (id=$alarmId)")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling azan alarm", e)
        }
    }

    private fun cancelAzan(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AzanAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled azan alarm id=$alarmId")
    }
}
