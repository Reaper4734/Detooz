import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to check network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  Future<bool> hasInternet() async {
    try {
      final result = await _connectivity.checkConnectivity();
      // Returns a list of connectivity results
      return result.isNotEmpty && 
             !result.contains(ConnectivityResult.none);
    } catch (e) {
      // If check fails, assume no internet
      return false;
    }
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged => 
      _connectivity.onConnectivityChanged;
}

final connectivityService = ConnectivityService();
