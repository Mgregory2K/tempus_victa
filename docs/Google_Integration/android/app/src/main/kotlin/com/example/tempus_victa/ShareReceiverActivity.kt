package com.example.tempus_victa

import android.app.Activity
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import org.json.JSONArray
import org.json.JSONObject

class ShareReceiverActivity : Activity() {

    private fun prefs(): SharedPreferences =
        applicationContext.getSharedPreferences("tempus_prefs", MODE_PRIVATE)

    private fun guessMime(uri: Uri): String? {
        val type = contentResolver.getType(uri)
        if (type != null) return type
        val ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        return if (ext.isNullOrBlank()) null else MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
    }

    private fun enqueueShare(obj: JSONObject) {
        val p = prefs()
        val key = "tempus.pendingShares.v1"
        val raw = p.getString(key, null)
        val arr = if (raw.isNullOrBlank()) JSONArray() else JSONArray(raw)
        arr.put(obj)
        p.edit().putString(key, arr.toString()).apply()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val i = intent
        if (i == null) {
            finish()
            return
        }

        val action = i.action ?: ""
        val now = System.currentTimeMillis()

        if (Intent.ACTION_SEND == action) {
            handleSend(i, now)
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            handleSendMultiple(i, now)
        }

        // Bring app to front.
        val launch = Intent(this, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(launch)

        finish()
    }

    private fun handleSend(i: Intent, now: Long) {
        val text = i.getStringExtra(Intent.EXTRA_TEXT)
        val subject = i.getStringExtra(Intent.EXTRA_SUBJECT)

        val stream = i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (stream != null) {
            val obj = JSONObject()
            obj.put("kind", "image")
            obj.put("uri", stream.toString())
            obj.put("mimeType", guessMime(stream) ?: "")
            obj.put("subject", subject ?: "")
            obj.put("tsMs", now)
            enqueueShare(obj)
            return
        }

        val cleaned = (text ?: "").trim()
        val kind = if (cleaned.startsWith("http://") || cleaned.startsWith("https://")) "link" else "text"
        val obj = JSONObject()
        obj.put("kind", kind)
        obj.put("text", cleaned)
        obj.put("subject", subject ?: "")
        obj.put("tsMs", now)
        enqueueShare(obj)
    }

    private fun handleSendMultiple(i: Intent, now: Long) {
        val subject = i.getStringExtra(Intent.EXTRA_SUBJECT)
        val list = i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (list != null) {
            for (u in list) {
                val obj = JSONObject()
                obj.put("kind", "image")
                obj.put("uri", u.toString())
                obj.put("mimeType", guessMime(u) ?: "")
                obj.put("subject", subject ?: "")
                obj.put("tsMs", now)
                enqueueShare(obj)
            }
        }
    }
}
