import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';
import '../services/connectivity_service.dart';
import '../services/sms_sender_service.dart';
import '../ui/components/scam_alert_overlay.dart';
import '../ui/screens/permission_wizard_screen.dart';
import '../services/offline_cache_service.dart';

/// Unified Message Receiver Service
/// Handles incoming messages from SMS, WhatsApp, and Telegram via Notification Listener
/// Privacy: Only processes messages from UNKNOWN senders (saved contacts are skipped on Android)
class SmsReceiverService {
  static final SmsReceiverService _instance = SmsReceiverService._internal();
  factory SmsReceiverService() => _instance;
  SmsReceiverService._internal();
  
  // Unified method channel for all messaging platforms
  final MethodChannel _messageChannel = 
      const MethodChannel('com.detooz.app/sms_notifications');
  
  bool _isInitialized = false;
  BuildContext? _context;
  
  /// Initialize the message receiver
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    _context = context;
    
    // Setup unified message channel (handles SMS, WhatsApp, Telegram)
    _setupMessageChannel();
    
    // Force re-bind of notification service (Fixes "Silent Failure" after updates)
    await reconnectNotificationService();
    
    // Check and request permission on Android
    await _checkAndroidPermission();
    
    _isInitialized = true;
    debugPrint('📱 Unified Message Receiver initialized (SMS, WhatsApp, Telegram)');
  }

  Future<void> reconnectNotificationService() async {
    try {
      await _messageChannel.invokeMethod('reconnectNotificationService');
    } catch (e) {
      debugPrint("Error reconnecting service: $e");
    }
  }

  Future<bool> isNotificationListenerEnabled() async {
    try {
      final bool isEnabled = await _messageChannel.invokeMethod('isNotificationListenerEnabled');
      return isEnabled;
    } catch (e) {
      debugPrint("Error checking permission: $e");
      return false;
    }
  }

  Future<void> _checkAndroidPermission() async {
    try {
      final bool isEnabled = await isNotificationListenerEnabled();
      if (!isEnabled && _context != null) {
        if (!_context!.mounted) return;
        
        // Redirect to Permission Wizard for guided setup
        Navigator.of(_context!).push(
          MaterialPageRoute(builder: (_) => const PermissionWizardScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
    }
  }
  
  Future<void> openNotificationListenerSettings() async {
    try {
      await _messageChannel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      debugPrint("Error opening settings: $e");
    }
  }

  Future<void> openAutostartSettings() async {
    try {
      await _messageChannel.invokeMethod('openAutostartSettings');
    } catch (e) {
      debugPrint("Error opening autostart settings: $e");
    }
  }
  
  void _setupMessageChannel() {
    _messageChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageReceived') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final message = args['message'] as String;
        final sender = args['sender'] as String;
        final platform = args['platform'] as String;
        
        await _handleIncomingMessage(
          message: message, 
          sender: sender, 
          platform: platform
        );
      }
      return null;
    });
  }
  


  /// Handle incoming message from any source (SMS or WhatsApp)
  Future<void> _handleIncomingMessage({
    required String message,
    required String sender,
    required String platform,
  }) async {
    if (message.length < 3) return; // Skip very short messages
    
    debugPrint('📩 Received $platform message from: $sender');
    
    try {
      // 1. Hybrid Shield: Local AI Check (Zero Latency)
      Map<String, dynamic> result;
      
      final aiPrediction = await aiService.predict(message);
      final double aiConf = aiPrediction['confidence'];
      final String aiLabel = aiPrediction['label'];
      
      debugPrint('🧠 AI Prediction: $aiLabel (${(aiConf * 100).toStringAsFixed(1)}%)');

      // Check connectivity
      final hasInternet = await connectivityService.hasInternet();

      // TRAI Regulated Header check (e.g. AD-HDFCBK)
      final bool isTraiSender = RegExp(r"^[A-Z]{2}-?[A-Za-z0-9]{6}$", caseSensitive: false).hasMatch(sender);
      
      // 🛡️ Decision Logic:
      // - HAM/OTP: Always handle locally (privacy)
      // - SCAM with >90% confidence (non-TRAI): Handle locally (fast block)
      // - SCAM with <90% confidence OR TRAI header: Defer to cloud for verification
      // - No internet: Always local
      
      final bool useLocal = !hasInternet || 
                            aiLabel == 'HAM' || 
                            aiLabel == 'OTP' || 
                            (aiLabel == 'SCAM' && aiConf > 0.90 && !isTraiSender);
      
      if (useLocal) {
         String localReason = '';
         if (!hasInternet) {
           localReason = 'Offline Mode';
         } else if (aiLabel == 'HAM' || aiLabel == 'OTP') {
           localReason = 'Local AI (Safe Message)';
         } else {
           localReason = 'High Confidence Local Block';
         }
         debugPrint('🛡️ Hybrid Shield: $localReason!');
         
         // Map local AI result
         String riskLevel = 'LOW';
         String riskReason = 'Safe message';
         
         if (aiLabel == 'SCAM') {
           riskLevel = aiConf > 0.70 ? 'HIGH' : 'MEDIUM';
           riskReason = 'AI detected scam pattern${!hasInternet ? " (Offline)" : ""}';
         } else if (aiLabel == 'OTP') {
           riskLevel = 'LOW';
           riskReason = 'Transactional OTP';
         } else {
           // HAM
           riskLevel = 'LOW';
           riskReason = 'Safe message (AI verified)';
         }
         
         result = {
           'risk_level': riskLevel,
           'risk_reason': riskReason,
           'confidence': aiConf,
           'scam_type': aiLabel == 'SCAM' ? 'AI_DETECTED' : null,
           'source': 'local'  // Mark as local AI analysis
         };
         
         // Async: still send SCAM detections to backend for logging/learning when online
         if (hasInternet && aiLabel == 'SCAM') {
           apiService.analyzeSms(sender: sender, message: message).then((remoteResult) {
              debugPrint('✅ Synced local scan to backend');
           }).catchError((e) {
              debugPrint('❌ Background sync failed: $e');
           });
         }
         
      } else {
         // Only reaches here for: SCAM <90% OR TRAI headers (need cloud verification)
         if (isTraiSender) {
            debugPrint('🛡️ Hybrid Shield: Detected TRAI Header ($sender). Deferring to Server for Regulation Check.');
         } else {
            debugPrint('🛡️ Hybrid Shield: Uncertain ($aiLabel ${(aiConf * 100).toStringAsFixed(0)}%). Deferring to Cloud.');
         }
         
         // ☁️ Cloud Fallback: Verify with Server (DeepScan)
         result = await apiService.analyzeSms(
          sender: sender,
          message: message,
        );
        // Cloud result doesn't have 'source', it will default to 'cloud'
      }
      
      final riskLevel = result['risk_level'] as String?;
      final reason = result['risk_reason'] as String? ?? 'Potential scam detected';
      
      // Save to Local History Cache immediately
      final scanEntry = {
          'id': result['scan_id'] ?? DateTime.now().millisecondsSinceEpoch,
          'sender': sender,
          'message': message,
          'platform': platform.toUpperCase(),
          'risk_level': riskLevel,
          'risk_reason': reason,
          'scam_type': result['scam_type'],
          'confidence': result['confidence'] ?? 0.0,
          'created_at': DateTime.now().toIso8601String(),
          'guardian_alerted': false,
          'source': result['source'] ?? 'cloud',  // 'local' or 'cloud'
      };
      await offlineCacheService.cacheScan(scanEntry);
      
      // Show push notification for HIGH and MEDIUM risk (works in background)
      if (riskLevel == 'HIGH' || riskLevel == 'MEDIUM') {
        await notificationService.showScamAlert(
          sender: sender,
          riskLevel: riskLevel!,
          reason: reason,
          platform: platform,
        );
      }
      
      // Also show full-screen overlay for HIGH risk (only if app is open)
      if (riskLevel == 'HIGH' && _context != null) {
        _showScamAlert(
          sender: sender,
          message: message,
          reason: reason,
          confidence: (result['confidence'] as num?)?.toDouble() ?? 0.9,
          platform: platform,
        );
      } else if (riskLevel == 'MEDIUM') {
        debugPrint('⚠️ MEDIUM risk detected from $sender');
      }
      
      // Send guardian alert (HIGH risk only)
      if (riskLevel == 'HIGH') {
        await _sendGuardianAlert(
          sender: sender,
          message: message,
          scamType: result['scam_type']?.toString() ?? 'Suspected Scam',
          hasInternet: hasInternet,
        );
      }
    } catch (e) {
      debugPrint('❌ Message analysis failed: $e');
    }
  }
  
  void _showScamAlert({
    required String sender,
    required String message,
    required String reason,
    required double confidence,
    required String platform,
  }) {
    if (_context == null) return;
    
    debugPrint('🚨 HIGH RISK $platform message detected! Showing alert...');
    
    ScamAlertOverlay.show(
      _context!,
      sender: '$platform: $sender',
      message: message,
      reason: reason,
      confidence: confidence,
      onBlock: () => _blockSender(sender),
    );
  }
  
  Future<void> _blockSender(String sender) async {
    try {
      await apiService.blockSender(sender);
      debugPrint('🚫 Blocked sender: $sender');
    } catch (e) {
      debugPrint('❌ Failed to block sender: $e');
    }
  }
  
  /// Send guardian alert via API (online) or SMS (offline)
  Future<void> _sendGuardianAlert({
    required String sender,
    required String message,
    required String scamType,
    required bool hasInternet,
  }) async {
    try {
      // Get cached guardian phone number
      final guardianPhone = offlineCacheService.getSetting('guardian_phone');
      
      if (guardianPhone == null || guardianPhone.isEmpty) {
        debugPrint('ℹ️ No guardian linked, skipping alert');
        return;
      }
      
      if (hasInternet) {
        // Online: Use API (FCM push to guardian)
        try {
          await apiService.sendGuardianAlert(
            sender: sender,
            scamType: scamType,
          );
          debugPrint('✅ Guardian alerted via API (FCM)');
        } catch (e) {
          debugPrint('⚠️ API alert failed, falling back to SMS: $e');
          // Fallback to SMS if API fails
          await _sendGuardianSms(guardianPhone, sender, scamType, message);
        }
      } else {
        // Offline: Direct SMS (P2P via carrier)
        await _sendGuardianSms(guardianPhone, sender, scamType, message);
      }
    } catch (e) {
      debugPrint('❌ Guardian alert failed: $e');
    }
  }
  
  /// Send SMS directly to guardian (works offline)
  Future<void> _sendGuardianSms(
    String guardianPhone,
    String sender,
    String scamType,
    String message,
  ) async {
    final success = await smsSenderService.sendGuardianAlert(
      guardianPhone: guardianPhone,
      sender: sender,
      scamType: scamType,
      messagePreview: message,
    );
    
    if (success) {
      debugPrint('📱 Guardian alerted via SMS (offline mode)');
    } else {
      debugPrint('❌ SMS to guardian failed');
    }
  }
}

/// Global instance
final smsReceiverService = SmsReceiverService();

