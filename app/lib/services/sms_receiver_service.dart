import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';
import '../ui/components/scam_alert_overlay.dart';
import '../ui/screens/permission_wizard_screen.dart';

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

      // 🛡️ Fast Path: If AI is super confident it's a SCAM, block immediately without Network
      // UNLESS: It looks like a TRAI Regulated Header (e.g. AD-HDFCBK), in which case we let the Server decide vs Marketing
      final bool isTraiSender = RegExp(r"^[A-Z]{2}-?[A-Za-z0-9]{6}$", caseSensitive: false).hasMatch(sender);
      
      if (aiLabel == 'SCAM' && aiConf > 0.90 && !isTraiSender) {
         debugPrint('🛡️ Hybrid Shield: High Confidence Local Block!');
         result = {
           'risk_level': 'HIGH',
           'risk_reason': 'AI detected scam pattern (Offline)',
           'confidence': aiConf,
           'scam_type': 'AI_DETECTED'
         };
         
         // Async: still send to backend for logging/learning, but don't wait
         apiService.analyzeSms(sender: sender, message: message).ignore();
         
      } else {
         if (isTraiSender && aiLabel == 'SCAM') {
            debugPrint('🛡️ Hybrid Shield: Detected TRAI Header ($sender). Deferring to Server for Regulation Check.');
         }
         
         // ☁️ Cloud Fallback: If unsure (or HAM), verify with Server (DeepScan)
         result = await apiService.analyzeSms(
          sender: sender,
          message: message,
        );
      }
      
      final riskLevel = result['risk_level'] as String?;
      final reason = result['risk_reason'] as String? ?? 'Potential scam detected';
      
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
}

/// Global instance
final smsReceiverService = SmsReceiverService();

