package com.example.tempus_victa

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Marked 'open' so a compatibility shim service can extend it.
 */
open class IngestNotificationListener : NotificationListenerService() {

    private val TAG = "TVIngest"

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "Notification listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            val ctx = applicationContext ?: return
            val prefs = ctx.getSharedPreferences("tempus_ingest", Context.MODE_PRIVATE)

            val extras = sbn.notification.extras
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""
            val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
            val body = if (bigText.isNotEmpty()) bigText else text

            val obj = JSONObject()
            obj.put("id", sbn.key ?: System.currentTimeMillis().toString())
            obj.put("createdAtMs", System.currentTimeMillis())
            obj.put("source", "notification")
            obj.put("packageName", sbn.packageName ?: "android")
            obj.put("title", title)
            obj.put("body", body)

            val existing = prefs.getString("buffer", "[]") ?: "[]"
            val arr = JSONArray(existing)
            arr.put(obj)
            prefs.edit().putString("buffer", arr.toString()).apply()

            Log.i(TAG, "Captured notif pkg=${sbn.packageName} title=${title.take(60)} body=${body.take(60)} bufferCount=${arr.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "onNotificationPosted failed", e)
        }
    }
}
