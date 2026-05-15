package com.detooz.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SmsManager
import android.Manifest
import android.content.pm.PackageManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.EventChannel
import androidx.core.content.ContextCompat

class MainActivity: FlutterFragmentActivity() {
    
    companion object {
        private const val SMS_CHANNEL = "com.detooz.app/sms_notifications"
        private const val SMS_SENDER_CHANNEL = "com.detooz.app/sms"
        private const val APP_SCANNER_CHANNEL = "com.detooz.app/apk_scanner"
    }
    
    private var appScanEventSink: EventChannel.EventSink? = null
    private var packageReceiver: BroadcastReceiver? = null
    
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
                "openAutostartSettings" -> {
                    openAutostartSettings()
                    result.success(true)
                }
                "reconnectNotificationService" -> {
                    reconnectNotificationService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Setup SMS sender channel (for guardian alerts when offline)
        val smsSenderChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_SENDER_CHANNEL
        )
        
        smsSenderChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    
                    if (phone == null || message == null) {
                        result.error("INVALID_ARGS", "Phone and message are required", null)
                        return@setMethodCallHandler
                    }
                    
                    val success = sendDirectSms(phone, message)
                    result.success(success)
                }
                "canSendSms" -> {
                    result.success(hasSmsPermission())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Setup App Scanner event channel
        val appScannerChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_SCANNER_CHANNEL
        )
        appScannerChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                appScanEventSink = events
                registerPackageReceiver()
            }
            override fun onCancel(arguments: Any?) {
                appScanEventSink = null
                unregisterPackageReceiver()
            }
        })
    }
    
    private fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, 
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun sendDirectSms(phone: String, message: String): Boolean {
        return try {
            if (!hasSmsPermission()) {
                android.util.Log.e("MainActivity", "❌ SEND_SMS permission not granted")
                return false
            }
            
            val smsManager = SmsManager.getDefault()
            
            // Split message if too long
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            
            android.util.Log.d("MainActivity", "📱 SMS sent to $phone")
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ SMS send failed: ${e.message}")
            false
        }
    }

    private fun reconnectNotificationService() {
        try {
            val pm = packageManager
            val componentName = android.content.ComponentName(this, SmsNotificationListener::class.java)
            pm.setComponentEnabledSetting(
                componentName,
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                android.content.pm.PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                componentName,
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                android.content.pm.PackageManager.DONT_KILL_APP
            )
            android.util.Log.d("MainActivity", "🔄 Toggled Notification Listener Component to force re-bind")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Failed to toggle service: ${e.message}")
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

    private fun openAutostartSettings() {
        val intents = listOf(
            android.content.Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManagerActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            android.content.Intent().setComponent(android.content.ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.MainActivity"))
        )

        for (intent in intents) {
            try {
                startActivity(intent)
                return
            } catch (e: Exception) {
                // Continue to next
            }
        }
        
        // Fallback to Application Details
        try {
            val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.setData(android.net.Uri.parse("package:$packageName"))
            startActivity(intent)
        } catch (e: Exception) {
            // Ignore
        }
    }
    
    private fun registerPackageReceiver() {
        if (packageReceiver == null) {
            packageReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action == Intent.ACTION_PACKAGE_ADDED) {
                        val uri = intent.data
                        val pkgName = uri?.schemeSpecificPart ?: return
                        
                        // Ignore our own app updates
                        if (pkgName == context.packageName) return
                        
                        Thread {
                            val appData = extractAppMetadata(context, pkgName)
                            runOnUiThread {
                                appScanEventSink?.success(appData)
                            }
                        }.start()
                    }
                }
            }
            val filter = IntentFilter(Intent.ACTION_PACKAGE_ADDED).apply {
                addDataScheme("package")
            }
            registerReceiver(packageReceiver, filter)
            android.util.Log.d("MainActivity", "✅ Registered APK Scanner Package Receiver")
        }
    }

    private fun unregisterPackageReceiver() {
        packageReceiver?.let {
            unregisterReceiver(it)
            packageReceiver = null
        }
    }

    private fun extractAppMetadata(context: Context, pkgName: String): Map<String, Any> {
        val pm = context.packageManager
        val data = mutableMapOf<String, Any>()
        data["packageName"] = pkgName
        
        try {
            val packageInfo = pm.getPackageInfo(
                pkgName, 
                PackageManager.GET_PERMISSIONS or PackageManager.GET_SIGNING_CERTIFICATES
            )
            data["appName"] = packageInfo.applicationInfo.loadLabel(pm).toString()
            data["requestedPermissions"] = packageInfo.requestedPermissions?.toList() ?: emptyList<String>()
            
            // Extract SHA-256 signature
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                val signatures = packageInfo.signingInfo?.apkContentsSigners
                if (signatures != null && signatures.isNotEmpty()) {
                    val md = java.security.MessageDigest.getInstance("SHA-256")
                    md.update(signatures[0].toByteArray())
                    val hash = md.digest().joinToString("") { "%02x".format(it) }
                    data["signature"] = hash
                }
            } else {
                @Suppress("DEPRECATION")
                val signatures = pm.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES).signatures
                if (signatures != null && signatures.isNotEmpty()) {
                    val md = java.security.MessageDigest.getInstance("SHA-256")
                    md.update(signatures[0].toByteArray())
                    val hash = md.digest().joinToString("") { "%02x".format(it) }
                    data["signature"] = hash
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error extracting metadata for $pkgName: ${e.message}")
            data["error"] = e.message ?: "Unknown error"
        }
        
        return data
    }
}
