import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:another_telephony/telephony.dart';  // Temporarily disabled - AGP 8.x issue
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../ui/components/scam_alert_overlay.dart';

/// Service that handles incoming SMS messages and WhatsApp detection
/// Note: SMS listener temporarily disabled due to AGP 8.x compatibility issues
class SmsReceiverService {
  static final SmsReceiverService _instance = SmsReceiverService._internal();
  factory SmsReceiverService() => _instance;
  SmsReceiverService._internal();
  
  // final Telephony telephony = Telephony.instance;  // Disabled
  final MethodChannel _accessibilityChannel = 
      const MethodChannel('com.detooz.app/accessibility');
  
  bool _isInitialized = false;
  BuildContext? _context;
  
  /// Initialize the SMS receiver
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    _context = context;
    
    // SMS listener temporarily disabled
    // final smsStatus = await Permission.sms.request();
    // if (smsStatus.isGranted) {
    //   _startSmsListener();
    // }
    
    // Setup WhatsApp accessibility channel
    _setupAccessibilityChannel();
    
    _isInitialized = true;
  }
  
  // void _startSmsListener() {
  //   telephony.listenIncomingSms(
  //     onNewMessage: _handleIncomingSms,
  //     onBackgroundMessage: _backgroundMessageHandler,
  //   );
  // }
  
  // Future<void> _handleIncomingSms(SmsMessage message) async {
  //   // ... SMS handling code disabled
  // }
  
  void _setupAccessibilityChannel() {
    _accessibilityChannel.setMethodCallHandler((call) async {
      if (call.method == 'onWhatsAppMessage') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final message = args['message'] as String;
        final source = args['source'] as String;
        
        await _handleWhatsAppMessage(message, source);
      }
      return null;
    });
  }
  
  Future<void> _handleWhatsAppMessage(String message, String source) async {
    if (message.length < 20) return; // Skip very short messages
    
    try {
      final result = await apiService.analyzeSms(
        sender: source,
        message: message,
      );
      
      final riskLevel = result['risk_level'] as String?;
      
      if (riskLevel == 'HIGH' && _context != null) {
        _showScamAlert(
          sender: 'WhatsApp',
          message: message,
          reason: result['risk_reason'] ?? 'Potential scam detected',
          confidence: (result['confidence'] as num?)?.toDouble() ?? 0.9,
        );
      }
    } catch (e) {
      debugPrint('WhatsApp analysis failed: $e');
    }
  }
  
  void _showScamAlert({
    required String sender,
    required String message,
    required String reason,
    required double confidence,
  }) {
    if (_context == null) return;
    
    ScamAlertOverlay.show(
      _context!,
      sender: sender,
      message: message,
      reason: reason,
      confidence: confidence,
      onBlock: () => _blockSender(sender),
    );
  }
  
  void _showWarningNotification(String sender, String reason) {
    debugPrint('⚠️ Warning from $sender: $reason');
  }
  
  Future<void> _blockSender(String sender) async {
    try {
      await apiService.blockSender(sender);
      debugPrint('Blocked sender: $sender');
    } catch (e) {
      debugPrint('Failed to block sender: $e');
    }
  }
}

/// Global instance
final smsReceiverService = SmsReceiverService();
