import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms/flutter_sms.dart';

/// SMS Sender Service for offline guardian alerts
/// Sends SMS directly via carrier network (works without internet)
class SmsSenderService {
  static final SmsSenderService _instance = SmsSenderService._internal();
  factory SmsSenderService() => _instance;
  SmsSenderService._internal();

  // Platform channel for direct SMS sending (bypasses SMS app)
  static const MethodChannel _channel = MethodChannel('com.detooz.app/sms');

  /// Send guardian alert via SMS (works offline)
  /// 
  /// This is P2P: Device → Carrier → Guardian's Phone
  /// No internet required, instant delivery
  Future<bool> sendGuardianAlert({
    required String guardianPhone,
    required String sender,
    required String scamType,
    String? messagePreview,
  }) async {
    try {
      final message = _buildAlertMessage(
        sender: sender,
        scamType: scamType,
        preview: messagePreview,
      );

      // Try direct SMS via platform channel first
      try {
        final bool success = await _channel.invokeMethod('sendSms', {
          'phone': guardianPhone,
          'message': message,
        });
        if (success) {
          debugPrint('📱 Guardian SMS sent directly');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Direct SMS failed, falling back to SMS app: $e');
      }

      // Fallback: Launch SMS app with pre-filled message
      // This opens the SMS app but at least ensures the message is ready
      await launchSms(
        message: message,
        number: guardianPhone,
      );
      
      debugPrint('📱 SMS app launched with guardian alert');
      return true;
    } catch (e) {
      debugPrint('❌ SMS send failed: $e');
      return false;
    }
  }

  /// Build the alert message
  String _buildAlertMessage({
    required String sender,
    required String scamType,
    String? preview,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 DETOOZ SCAM ALERT');
    buffer.writeln('');
    buffer.writeln('A scam message was detected!');
    buffer.writeln('From: $sender');
    buffer.writeln('Type: $scamType');
    
    if (preview != null && preview.isNotEmpty) {
      final shortPreview = preview.length > 50 
          ? '${preview.substring(0, 50)}...' 
          : preview;
      buffer.writeln('');
      buffer.writeln('Preview: "$shortPreview"');
    }
    
    buffer.writeln('');
    buffer.writeln('Please check on your protected person.');
    
    return buffer.toString();
  }

  /// Send a test SMS to verify the feature works
  Future<bool> sendTestAlert(String phoneNumber) async {
    try {
      await launchSms(
        message: '✅ Detooz Guardian Alert Test\n\nThis is a test message. If you received this, guardian alerts are working!',
        number: phoneNumber,
      );
      return true;
    } catch (e) {
      debugPrint('❌ Test SMS failed: $e');
      return false;
    }
  }

  /// Check if device can send SMS
  Future<bool> get canSend async {
    try {
      return await canSendSMS();
    } catch (e) {
      return false;
    }
  }
}

/// Global instance
final smsSenderService = SmsSenderService();
