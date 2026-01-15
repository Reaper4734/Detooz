package com.detooz.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Accessibility Service for detecting WhatsApp messages
 * This service monitors WhatsApp for new message content
 */
class DetoozAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "DetoozAccessibility"
        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val CHANNEL_NAME = "com.detooz.app/accessibility"
        
        // Static reference for Flutter communication
        var methodChannel: MethodChannel? = null
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                        AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED
            packageNames = arrayOf(WHATSAPP_PACKAGE)
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        
        serviceInfo = info
        Log.d(TAG, "Accessibility Service connected for WhatsApp detection")
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        
        if (event.packageName != WHATSAPP_PACKAGE) return
        
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleWindowContentChanged(event)
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                handleNotification(event)
            }
        }
    }
    
    private fun handleWindowContentChanged(event: AccessibilityEvent) {
        val source = event.source ?: return
        
        // Try to extract message content from WhatsApp chat
        val messages = extractMessagesFromNode(source)
        
        for (message in messages) {
            if (message.isNotBlank()) {
                sendMessageToFlutter(message, "WhatsApp Chat")
            }
        }
        
        source.recycle()
    }
    
    private fun handleNotification(event: AccessibilityEvent) {
        val text = event.text.joinToString(" ")
        if (text.isNotBlank()) {
            sendMessageToFlutter(text, "WhatsApp Notification")
        }
    }
    
    private fun extractMessagesFromNode(node: AccessibilityNodeInfo): List<String> {
        val messages = mutableListOf<String>()
        
        // Look for message text views
        val textViews = mutableListOf<AccessibilityNodeInfo>()
        findTextNodes(node, textViews)
        
        for (textView in textViews) {
            val text = textView.text?.toString()
            if (!text.isNullOrBlank() && text.length > 10) {
                // Filter out UI elements, keep actual messages
                if (!isUIElement(text)) {
                    messages.add(text)
                }
            }
        }
        
        return messages
    }
    
    private fun findTextNodes(node: AccessibilityNodeInfo, result: MutableList<AccessibilityNodeInfo>) {
        if (node.text != null) {
            result.add(node)
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            findTextNodes(child, result)
        }
    }
    
    private fun isUIElement(text: String): Boolean {
        val uiKeywords = listOf(
            "today", "yesterday", "online", "typing",
            "seen", "delivered", "sent", "mute", "archive",
            "delete", "forward", "reply", "copy"
        )
        return uiKeywords.any { text.lowercase().contains(it) && text.length < 30 }
    }
    
    private fun sendMessageToFlutter(message: String, source: String) {
        Log.d(TAG, "Detected message from $source: ${message.take(50)}...")
        
        methodChannel?.invokeMethod("onWhatsAppMessage", mapOf(
            "message" to message,
            "source" to source,
            "timestamp" to System.currentTimeMillis()
        ))
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service interrupted")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Accessibility Service destroyed")
    }
}
