import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification Service for showing on-screen alerts
/// Used for:
/// - Guardian alerts when protected user receives scam
/// - High-risk scam detection warnings
/// - General app notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings (for future)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Guardian Alert Channel (MAX priority - shows on lock screen, heads-up, sound + vibration)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'guardian_alerts',
          'Guardian Alerts',
          description: 'Alerts sent to guardians when scams are detected',
          importance: Importance.max,  // Shows as heads-up notification
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFFFF0000),
          showBadge: true,
        ),
      );

      // Scam Detection Channel (HIGH priority - shows on lock screen with sound)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'scam_alerts',
          'Scam Alerts',
          description: 'Notifications about detected scams',
          importance: Importance.high,  // Shows in notification shade + sound
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      // General Channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'general',
          'General',
          description: 'General app notifications',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Navigate to specific screen based on payload
  }

  /// Show Guardian Alert notification (HIGH priority, full screen intent)
  Future<void> showGuardianAlert({
    required String protectedUserName,
    required String scamType,
    required String sender,
    required String messagePreview,
    int? alertId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'guardian_alerts',
      'Guardian Alerts',
      channelDescription: 'Alerts sent to guardians when scams are detected',
      importance: Importance.max,
      priority: Priority.max,
      ticker: '🚨 SCAM ALERT',
      fullScreenIntent: true, // Shows as full-screen on lock screen
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
      color: Color(0xFFE53935), // Red color
      colorized: true,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alertId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚨 SCAM ALERT: $protectedUserName',
      '$scamType detected from $sender\n"${messagePreview.length > 80 ? '${messagePreview.substring(0, 80)}...' : messagePreview}"',
      details,
      payload: 'guardian_alert:$alertId',
    );

    debugPrint('🔔 Guardian alert notification shown for $protectedUserName');
  }

  /// Show Scam Detection notification (for the user themselves)
  Future<void> showScamAlert({
    required String sender,
    required String riskLevel,
    required String reason,
    required String platform,
  }) async {
    final isHigh = riskLevel == 'HIGH';

    final androidDetails = AndroidNotificationDetails(
      'scam_alerts',
      'Scam Alerts',
      channelDescription: 'Notifications about detected scams',
      importance: isHigh ? Importance.max : Importance.high,
      priority: isHigh ? Priority.max : Priority.high,
      ticker: isHigh ? '🚨 HIGH RISK SCAM' : '⚠️ Suspicious message',
      styleInformation: BigTextStyleInformation(reason),
      color: isHigh ? const Color(0xFFE53935) : const Color(0xFFFF9800),
      colorized: true,
      visibility: NotificationVisibility.public,  // Show on lock screen
      fullScreenIntent: isHigh,  // Full screen for HIGH risk only
      category: isHigh ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final icon = isHigh ? '🚨' : '⚠️';
    final title = '$icon $riskLevel Risk: $platform message from $sender';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      reason,
      details,
      payload: 'scam_alert:$sender',
    );
  }

  /// Show general notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general',
      'General',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

/// Global notification service instance
final notificationService = NotificationService();
