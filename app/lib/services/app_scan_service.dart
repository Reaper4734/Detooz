import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api_service.dart';
import 'notification_service.dart';

class AppScanService {
  static const EventChannel _appScannerChannel = EventChannel('com.detooz.app/apk_scanner');

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      _appScannerChannel.receiveBroadcastStream().listen(_onAppInstalled, onError: _onError);
      debugPrint('🛡️ AppScanService initialized: Listening for APK installations.');
    }

    _isInitialized = true;
  }

  void _onAppInstalled(dynamic event) async {
    try {
      final Map<dynamic, dynamic> data = event as Map<dynamic, dynamic>;
      
      final String packageName = data['packageName'] ?? 'unknown';
      final String appName = data['appName'] ?? 'unknown';
      final String signature = data['signature'] ?? '';
      
      // Convert requestedPermissions from dynamic List to List<String>
      final List<dynamic> rawPermissions = data['requestedPermissions'] ?? [];
      final List<String> permissions = rawPermissions.map((e) => e.toString()).toList();

      debugPrint('📦 New App Detected: $appName ($packageName)');
      debugPrint('🔑 Signature SHA-256: $signature');

      // Send to Backend for AI Scanning
      final isMalicious = await _scanAppWithBackend(
        packageName: packageName,
        appName: appName,
        signature: signature,
        permissions: permissions,
      );

      if (isMalicious) {
        // Trigger Critical Alert to User!
        await notificationService.showScamAlert(
          title: '🚨 CRITICAL MALWARE DETECTED',
          body: 'The app "$appName" is highly dangerous! Do not open it. Uninstall immediately.',
        );
        
        // Note: The backend will automatically trigger the Guardian Alert when the scan API returns malicious!
      }
    } catch (e) {
      debugPrint('❌ AppScanService Error parsing event: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('❌ AppScanService EventChannel Error: $error');
  }

  /// Sends the extracted app metadata to the Python backend
  Future<bool> _scanAppWithBackend({
    required String packageName,
    required String appName,
    required String signature,
    required List<String> permissions,
  }) async {
    try {
      // We will create this endpoint in the backend in Phase 3
      final response = await apiService.post(
        '/scan/app',
        {
          'package_name': packageName,
          'app_name': appName,
          'signature_sha256': signature,
          'requested_permissions': permissions,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_malicious'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Failed to scan app with backend: $e');
      return false; // Fail open
    }
  }
}

final appScanService = AppScanService();
