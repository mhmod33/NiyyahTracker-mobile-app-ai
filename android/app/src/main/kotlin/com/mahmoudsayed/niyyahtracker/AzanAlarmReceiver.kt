package com.mahmoudsayed.niyyahtracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AzanAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "AzanAlarmReceiver"
        const val EXTRA_FILE_PATH = "file_path"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val filePath = intent.getStringExtra(EXTRA_FILE_PATH)
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)

        Log.d(TAG, "Alarm received for $prayerName (id=$alarmId), file=$filePath")

        if (filePath == null) {
            Log.e(TAG, "No file path, cannot play azan")
            return
        }

        val serviceIntent = Intent(context, AzanPlayerService::class.java).apply {
            putExtra(EXTRA_FILE_PATH, filePath)
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_ALARM_ID, alarmId)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting AzanPlayerService", e)
        }
    }
}
