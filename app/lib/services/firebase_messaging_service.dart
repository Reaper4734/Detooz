import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'notification_service.dart';
import 'api_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Background init failed: $e');
    return;
  }
  
  debugPrint('🔔 Background FCM message received: ${message.messageId}');
  
  // Show local notification for background message
  final data = message.data;
  if (data.containsKey('type') && data['type'] == 'guardian_alert') {
    await NotificationService().showGuardianAlert(
      protectedUserName: data['user_name'] ?? 'Protected User',
      scamType: data['scam_type'] ?? 'Scam Detected',
      sender: data['sender'] ?? 'Unknown',
      messagePreview: data['message_preview'] ?? '',
      alertId: int.tryParse(data['alert_id'] ?? '0'),
    );
  }
}

/// Firebase Cloud Messaging Service
/// Handles push notifications for guardian alerts even when app is closed
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  FirebaseMessaging? _messaging;
  String? _fcmToken;
  bool _isInitialized = false;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    if (kIsWeb) return; // Push notifications not supported/configured on Web yet
    if (_isInitialized) return;

    _messaging = FirebaseMessaging.instance;

    // Request notification permissions
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,  // For urgent alerts
      provisional: false,
    );

    debugPrint('🔔 FCM Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      // Get FCM token
      _fcmToken = await _messaging!.getToken();
      debugPrint('🔔 FCM Token: $_fcmToken');

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle messages when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Check for initial message (app opened from terminated state via notification)
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;
      debugPrint('🔔 Firebase Messaging initialized successfully');
    } else {
      debugPrint('❌ FCM Permission denied');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Register FCM token with backend
  Future<void> registerTokenWithBackend() async {
    if (_fcmToken == null) return;

    try {
      final success = await apiService.registerFcmToken(_fcmToken!);
      if (success) {
        debugPrint('🔔 FCM token registered with backend');
      } else {
        debugPrint('⚠️ FCM token registration returned false');
      }
    } catch (e) {
      debugPrint('❌ Failed to register FCM token: $e');
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String newToken) {
    debugPrint('🔔 FCM Token refreshed: $newToken');
    _fcmToken = newToken;
    registerTokenWithBackend();
  }

  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground FCM message: ${message.notification?.title}');

    final data = message.data;
    
    // Show notification based on type
    if (data['type'] == 'guardian_alert') {
      notificationService.showGuardianAlert(
        protectedUserName: data['user_name'] ?? 'Protected User',
        scamType: data['scam_type'] ?? 'Scam Detected',
        sender: data['sender'] ?? 'Unknown',
        messagePreview: data['message_preview'] ?? '',
        alertId: int.tryParse(data['alert_id'] ?? '0'),
      );
    } else if (message.notification != null) {
      // Generic notification
      notificationService.showNotification(
        title: message.notification!.title ?? 'Detooz',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 App opened from notification: ${message.data}');
    // TODO: Navigate to specific screen based on message data
  }

  /// Subscribe to a topic (e.g., "guardian_alerts")
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.subscribeToTopic(topic);
    debugPrint('🔔 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) return;
    await _messaging!.unsubscribeFromTopic(topic);
    debugPrint('🔔 Unsubscribed from topic: $topic');
  }
}

/// Global instance
final firebaseMessagingService = FirebaseMessagingService();
