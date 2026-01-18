package com.detooz.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    companion object {
        private const val ACCESSIBILITY_CHANNEL = "com.detooz.app/accessibility"
        private const val SMS_CHANNEL = "com.detooz.app/sms_notifications"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Setup accessibility channel for WhatsApp detection
        val accessibilityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_CHANNEL
        )
        DetoozAccessibilityService.methodChannel = accessibilityChannel
        
        // Setup SMS notification listener channel
        val smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL
        )
        SmsNotificationListener.methodChannel = smsChannel
    }
}

