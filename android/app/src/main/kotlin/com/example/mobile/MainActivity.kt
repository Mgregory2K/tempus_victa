package com.example.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  private val shareChannelName = "tempus/share_intent"
  private val notifChannelName = "tempus/notification_intent"

  private var shareSink: EventChannel.EventSink? = null
  private var notifSink: EventChannel.EventSink? = null

  private val notifReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      if (intent == null) return
      if (intent.action != TempusNotificationListenerService.ACTION_TEMPUS_NOTIFICATION) return

      val payload = hashMapOf<String, Any?>(
        "package" to intent.getStringExtra("package"),
        "title" to intent.getStringExtra("title"),
        "text" to intent.getStringExtra("text"),
        "postedAtUtc" to intent.getStringExtra("postedAtUtc"),
      )
      notifSink?.success(payload)
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // Register receiver for notifications while app is running.
    val filter = IntentFilter(TempusNotificationListenerService.ACTION_TEMPUS_NOTIFICATION)

    // Android 13+ requires explicit exported-ness for dynamically registered receivers
    // unless it's exclusively for system broadcasts.
    if (Build.VERSION.SDK_INT >= 33) {
      registerReceiver(notifReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      @Suppress("DEPRECATION")
      registerReceiver(notifReceiver, filter)
    }
  }

  override fun onDestroy() {
    // Be defensive: if the activity dies before registration completes or gets double-called.
    try {
      unregisterReceiver(notifReceiver)
    } catch (_: IllegalArgumentException) {
      // Receiver wasn't registered (or already unregistered). Safe to ignore.
    }
    super.onDestroy()
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Share EventChannel
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          shareSink = events
          // Emit initial share if app launched via share.
          emitShareIntent(intent)
        }

        override fun onCancel(arguments: Any?) {
          shareSink = null
        }
      }
    )

    // Notification EventChannel
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, notifChannelName).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          notifSink = events
        }

        override fun onCancel(arguments: Any?) {
          notifSink = null
        }
      }
    )

    // MethodChannel for pulling initial share (optional)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tempus/share_methods")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialSharedText" -> result.success(extractSharedText(intent))
          else -> result.notImplemented()
        }
      }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    emitShareIntent(intent)
  }

  private fun emitShareIntent(intent: Intent?) {
    val text = extractSharedText(intent)
    if (text != null && text.isNotBlank()) {
      val payload = hashMapOf<String, Any?>(
        "text" to text,
        "receivedAtUtc" to java.time.Instant.now().toString(),
        "source" to "android_share",
      )
      shareSink?.success(payload)
    }
  }

  private fun extractSharedText(intent: Intent?): String? {
    if (intent == null) return null
    val action = intent.action ?: return null
    val type = intent.type ?: ""
    if (Intent.ACTION_SEND == action && type.startsWith("text/")) {
      return intent.getStringExtra(Intent.EXTRA_TEXT)
    }
    return null
  }
}