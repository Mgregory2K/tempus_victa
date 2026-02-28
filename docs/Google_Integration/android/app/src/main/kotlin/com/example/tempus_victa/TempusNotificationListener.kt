package com.example.tempus_victa

/**
 * Compatibility shim: if your manifest ever references TempusNotificationListener,
 * this keeps it working by inheriting the same capture behavior.
 */
class TempusNotificationListener : IngestNotificationListener()
