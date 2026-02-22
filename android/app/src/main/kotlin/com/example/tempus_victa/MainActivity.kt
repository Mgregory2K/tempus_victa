package com.example.tempus_victa

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "tempus/ingest"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "openAppNotificationSettings" -> {
                    try {
                        val intent = Intent()
                        intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                        intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (_: Exception) {
                        try {
                            val intent2 = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent2.data = Uri.parse("package:$packageName")
                            intent2.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent2)
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                }
                "isNotificationAccessEnabled" -> result.success(isNotifListenerEnabled())
                "getNativeBufferSize" -> {
                    val prefs = applicationContext.getSharedPreferences("tempus_ingest", Context.MODE_PRIVATE)
                    val raw = prefs.getString("buffer", "[]") ?: "[]"
                    val arr = JSONArray(raw)
                    result.success(arr.length())
                }
                "fetchAndClearSignals" -> {
                    val prefs = applicationContext.getSharedPreferences("tempus_ingest", Context.MODE_PRIVATE)
                    val raw = prefs.getString("buffer", "[]") ?: "[]"
                    val arr = JSONArray(raw)
                    val out = ArrayList<HashMap<String, Any?>>()

                    for (i in 0 until arr.length()) {
                        val o = arr.optJSONObject(i) ?: JSONObject()
                        val map = HashMap<String, Any?>()
                        map["id"] = o.optString("id")
                        map["createdAtMs"] = o.optLong("createdAtMs")
                        map["source"] = o.optString("source")
                        map["packageName"] = o.optString("packageName")
                        map["title"] = o.optString("title")
                        map["body"] = o.optString("body")
                        out.add(map)
                    }

                    prefs.edit().putString("buffer", "[]").apply()
                    result.success(out)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotifListenerEnabled(): Boolean {
        return try {
            val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            if (enabled.isNullOrEmpty()) return false
            enabled.contains(packageName)
        } catch (_: Exception) {
            false
        }
    }
}
