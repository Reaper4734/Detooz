import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to check network connectivity and backend reachability
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  
  // Backend health status
  final _backendHealthController = StreamController<bool>.broadcast();
  Stream<bool> get onBackendHealthChanged => _backendHealthController.stream;
  bool _isBackendReachable = false;
  bool get isBackendReachable => _isBackendReachable;
  
  Timer? _healthCheckTimer;
  
  /// Smart URL detection for backend
  static String get _healthUrl {
    if (kIsWeb) return 'http://localhost:8000/health';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000/health';
    return 'http://127.0.0.1:8000/health';
  }

  /// Check if device has internet connectivity
  Future<bool> hasInternet() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.isNotEmpty && 
             !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Ping backend to check if it's reachable
  Future<bool> pingBackend() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      
      final request = await client.getUrl(Uri.parse(_healthUrl));
      final response = await request.close().timeout(const Duration(seconds: 3));
      
      final isHealthy = response.statusCode == 200;
      _updateBackendHealth(isHealthy);
      return isHealthy;
    } catch (e) {
      _updateBackendHealth(false);
      return false;
    }
  }
  
  void _updateBackendHealth(bool isHealthy) {
    if (_isBackendReachable != isHealthy) {
      _isBackendReachable = isHealthy;
      _backendHealthController.add(isHealthy);
      debugPrint('🌐 Backend health changed: ${isHealthy ? "ONLINE" : "OFFLINE"}');
    }
  }
  
  /// Start periodic backend health checks (every 60 seconds)
  void startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    // Initial check
    pingBackend();
    // Periodic checks
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      pingBackend();
    });
    debugPrint('🔄 Started backend health monitoring (60s interval)');
  }
  
  /// Stop health monitoring (call on app dispose)
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged => 
      _connectivity.onConnectivityChanged;
  
  void dispose() {
    stopHealthMonitoring();
    _backendHealthController.close();
  }
}

final connectivityService = ConnectivityService();

