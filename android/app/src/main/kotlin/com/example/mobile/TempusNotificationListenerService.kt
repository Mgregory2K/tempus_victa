package com.example.mobile

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.time.Instant

class TempusNotificationListenerService : NotificationListenerService() {

  companion object {
    const val ACTION_TEMPUS_NOTIFICATION = "com.example.mobile.TEMPUS_NOTIFICATION"
  }

  override fun onNotificationPosted(sbn: StatusBarNotification?) {
    if (sbn == null) return
    val n = sbn.notification ?: return
    val extras = n.extras
    val title = extras.getCharSequence("android.title")?.toString()
    val text = extras.getCharSequence("android.text")?.toString()

    val intent = Intent(ACTION_TEMPUS_NOTIFICATION)
    intent.putExtra("package", sbn.packageName)
    intent.putExtra("title", title)
    intent.putExtra("text", text)
    intent.putExtra("postedAtUtc", Instant.now().toString())
    sendBroadcast(intent)
  }
}