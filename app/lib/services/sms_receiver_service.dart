import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../ui/components/scam_alert_overlay.dart';

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
    
    _isInitialized = true;
    debugPrint('📱 Unified Message Receiver initialized (SMS, WhatsApp, Telegram)');
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
    if (message.length < 10) return; // Skip very short messages
    
    debugPrint('📩 Received $platform message from: $sender');
    
    try {
      // Send to backend for analysis
      final result = await apiService.analyzeSms(
        sender: sender,
        message: message,
      );
      
      final riskLevel = result['risk_level'] as String?;
      
      if (riskLevel == 'HIGH' && _context != null) {
        _showScamAlert(
          sender: sender,
          message: message,
          reason: result['risk_reason'] ?? 'Potential scam detected',
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

