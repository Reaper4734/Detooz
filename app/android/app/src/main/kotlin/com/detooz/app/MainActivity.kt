package com.detooz.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    companion object {
        private const val SMS_CHANNEL = "com.detooz.app/sms_notifications"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup SMS notification listener channel (handles SMS, WhatsApp, Telegram)
        val smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        )
        SmsNotificationListener.methodChannel = smsChannel
        
        smsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationListenerSettings" -> {
                    openNotificationAccess()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val packageName = packageName
        val flat = android.provider.Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }

    private fun openNotificationAccess() {
        startActivity(android.content.Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }
}
