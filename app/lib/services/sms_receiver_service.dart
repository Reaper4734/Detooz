import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../ui/components/scam_alert_overlay.dart';

/// Service that handles incoming SMS messages and WhatsApp detection
class SmsReceiverService {
  static final SmsReceiverService _instance = SmsReceiverService._internal();
  factory SmsReceiverService() => _instance;
  SmsReceiverService._internal();
  
  final Telephony telephony = Telephony.instance;
  final MethodChannel _accessibilityChannel = 
      const MethodChannel('com.detooz.app/accessibility');
  
  bool _isInitialized = false;
  BuildContext? _context;
  
  /// Initialize the SMS receiver
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    _context = context;
    
    // Request SMS permissions
    final smsStatus = await Permission.sms.request();
    if (smsStatus.isGranted) {
      _startSmsListener();
    }
    
    // Setup WhatsApp accessibility channel
    _setupAccessibilityChannel();
    
    _isInitialized = true;
  }
  
  void _startSmsListener() {
    telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: _backgroundMessageHandler,
    );
  }
  
  Future<void> _handleIncomingSms(SmsMessage message) async {
    final sender = message.address ?? 'Unknown';
    final body = message.body ?? '';
    
    if (body.isEmpty) return;
    
    try {
      // Call backend API
      final result = await apiService.analyzeSms(
        sender: sender,
        message: body,
      );
      
      final riskLevel = result['risk_level'] as String?;
      
      if (riskLevel == 'HIGH' && _context != null) {
        // Show alert overlay
        _showScamAlert(
          sender: sender,
          message: body,
          reason: result['risk_reason'] ?? 'Potential scam detected',
          confidence: (result['confidence'] as num?)?.toDouble() ?? 0.9,
        );
      } else if (riskLevel == 'MEDIUM') {
        // Show notification (less intrusive)
        _showWarningNotification(sender, result['risk_reason'] ?? 'Suspicious message');
      }
      // LOW risk: do nothing
      
    } catch (e) {
      debugPrint('SMS analysis failed: $e');
    }
  }
  
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
    // TODO: Implement local notification for MEDIUM risk
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

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(SmsMessage message) async {
  // In background, we can't show UI, but we can analyze and log
  final sender = message.address ?? 'Unknown';
  final body = message.body ?? '';
  
  if (body.isEmpty) return;
  
  try {
    await apiService.analyzeSms(sender: sender, message: body);
    // Backend will handle guardian alerts automatically
  } catch (e) {
    debugPrint('Background SMS analysis failed: $e');
  }
}

/// Global instance
final smsReceiverService = SmsReceiverService();
