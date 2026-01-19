package com.detooz.app

import android.app.Notification
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.IBinder
import android.provider.ContactsContract
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Unified Notification Listener Service for all messaging platforms
 * 
 * Captures notifications from:
 * - SMS (Google Messages, Samsung, stock Android)
 * - WhatsApp
 * - Telegram
 * 
 * Privacy Feature: Ignores messages from saved contacts
 * Only analyzes messages from UNKNOWN senders
 */
class SmsNotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "UnifiedMessageListener"
        private const val CHANNEL_NAME = "com.detooz.app/sms_notifications"
        
        // All messaging app packages we monitor
        private val MESSAGING_PACKAGES = mapOf(
            // SMS Apps
            "com.google.android.apps.messaging" to "SMS",
            "com.samsung.android.messaging" to "SMS",
            "com.android.mms" to "SMS",
            "com.oneplus.mms" to "SMS",
            "com.miui.mms" to "SMS",  // Xiaomi
            
            // WhatsApp
            "com.whatsapp" to "WHATSAPP",
            "com.whatsapp.w4b" to "WHATSAPP",  // WhatsApp Business
            
            // Telegram
            "org.telegram.messenger" to "TELEGRAM",
            "org.telegram.messenger.web" to "TELEGRAM"
        )
        
        // Static reference for Flutter communication
        var methodChannel: MethodChannel? = null
        
        // Prevent duplicate processing
        private val recentMessages = LinkedHashSet<String>()
        private const val MAX_RECENT = 200
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "Unified Message Listener bound")
        return super.onBind(intent)
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔧 SmsNotificationListener Created")
        startForegroundService()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        Log.d(TAG, "🔄 SmsNotificationListener Started (Sticky)")
        // Ensure foreground is active
        startForegroundService()
        return START_STICKY
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "✅ Unified Message Listener connected - monitoring SMS, WhatsApp, Telegram")
    }

    private fun startForegroundService() {
        try {
            val channelId = "detooz_protection_service"
            val channelName = "Protection Service"
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    channelName,
                    android.app.NotificationManager.IMPORTANCE_LOW
                )
                val manager = getSystemService(android.app.NotificationManager::class.java)
                manager.createNotificationChannel(channel)
            }

            val notification = android.app.Notification.Builder(this, channelId)
                .setContentTitle("Detooz is Active")
                .setContentText("Scanning for scam messages in background... 🛡️")
                .setSmallIcon(android.R.drawable.ic_dialog_info) // Using system icon as fallback
                .build()

            // ID 1337 for leet protection
            startForeground(1337, notification)
            Log.d(TAG, "🛡️ Foreground Service Started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start foreground service: ${e.message}")
        }
    }
    
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        
        val packageName = sbn.packageName ?: return
        Log.d(TAG, "🔔 Notification posted from: $packageName") // Debug log
        
        // Check if this is a messaging app we monitor
        var platform = MESSAGING_PACKAGES[packageName]
        
        // Fallback: Auto-detect SMS apps by package name (e.g. Truecaller, Textra)
        if (platform == null) {
            if (packageName.contains("sms") || 
                packageName.contains("mms") || 
                packageName.contains("messaging")) {
                platform = "SMS"
                Log.d(TAG, "⚠️ Auto-detected generic SMS app: $packageName")
            } else {
                return
            }
        }
        
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        
        // Extract sender (notification title)
        val sender = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: return
        
        // Extract full message content
        val message = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: ""
        
        if (message.isBlank() || message.length < 3) {
            return
        }
        
        // PRIVACY FEATURE: Skip saved contacts
        if (isContactSaved(sender)) {
            Log.d(TAG, "⏭️ Skipping message from saved contact: $sender")
            return
        }
        
        // Create unique key to prevent duplicates
        val messageKey = "${platform}_${sender}_${message.hashCode()}"
        if (recentMessages.contains(messageKey)) {
            return
        }
        
        // Add to recent (with size limit)
        recentMessages.add(messageKey)
        if (recentMessages.size > MAX_RECENT) {
            recentMessages.remove(recentMessages.first())
        }
        
        Log.d(TAG, "📩 $platform message from UNKNOWN sender: $sender")
        Log.d(TAG, "📝 Message preview: ${message.take(50)}...")
        
        // Send to Flutter for scam analysis
        sendToFlutter(sender, message, platform)
    }
    
    /**
     * Check if the sender is a saved contact
     * Returns true if contact is saved (should be skipped)
     */
    private fun isContactSaved(sender: String): Boolean {
        try {
            val contentResolver: ContentResolver = applicationContext.contentResolver
            
            // Try to find by display name
            val nameUri = Uri.withAppendedPath(
                ContactsContract.Contacts.CONTENT_FILTER_URI,
                Uri.encode(sender)
            )
            val nameCursor: Cursor? = contentResolver.query(
                nameUri,
                arrayOf(ContactsContract.Contacts._ID),
                null,
                null,
                null
            )
            nameCursor?.use {
                if (it.count > 0) {
                    return true
                }
            }
            
            // Try to find by phone number (for SMS)
            if (sender.any { it.isDigit() }) {
                val phoneUri = Uri.withAppendedPath(
                    ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                    Uri.encode(sender)
                )
                val phoneCursor: Cursor? = contentResolver.query(
                    phoneUri,
                    arrayOf(ContactsContract.PhoneLookup._ID),
                    null,
                    null,
                    null
                )
                phoneCursor?.use {
                    if (it.count > 0) {
                        return true
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking contacts: ${e.message}")
            // On error, assume not saved (analyze the message)
            return false
        }
        
        return false
    }
    
    private fun sendToFlutter(sender: String, message: String, platform: String) {
        try {
            methodChannel?.invokeMethod("onMessageReceived", mapOf(
                "sender" to sender,
                "message" to message,
                "platform" to platform,
                "timestamp" to System.currentTimeMillis()
            ))
            Log.d(TAG, "✅ $platform message sent to Flutter for analysis")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send to Flutter: ${e.message}")
        }
    }
    
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Not needed
    }
    
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "❌ Unified Message Listener disconnected")
    }
}
