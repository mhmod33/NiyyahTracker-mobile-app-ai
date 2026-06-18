package com.mahmoudsayed.niyyahtracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AzanAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_FILE_PATH = "file_path"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_ALARM_ID = "alarm_id"

        fun writeLog(context: Context, message: String) {
            try {
                val file = File(context.filesDir, "azan_debug.log")
                val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
                file.appendText("[$ts] [Native] $message\n")
                val lines = file.readLines()
                if (lines.size > 300) {
                    file.writeText(lines.takeLast(300).joinToString("\n") + "\n")
                }
            } catch (_: Exception) {}
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val filePath = intent.getStringExtra(EXTRA_FILE_PATH)
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)

        Log.d("AzanAlarmReceiver", "onReceive prayer=$prayerName filePath=$filePath alarmId=$alarmId")
        writeLog(context, "AzanAlarmReceiver.onReceive prayer=$prayerName alarmId=$alarmId filePath=$filePath")

        if (filePath == null) {
            writeLog(context, "AzanAlarmReceiver: filePath is null — aborting")
            return
        }

        val file = File(filePath)
        writeLog(context, "AzanAlarmReceiver: file exists=${file.exists()} size=${if (file.exists()) file.length() else -1}")

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
            writeLog(context, "AzanAlarmReceiver: startForegroundService called OK")
        } catch (e: Exception) {
            Log.e("AzanAlarmReceiver", "Failed to start service: $e")
            writeLog(context, "AzanAlarmReceiver: startForegroundService FAILED: $e")
        }
    }
}
