import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline cache service for storing scan history locally
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();
  
  late Box<Map> _scanHistoryBox;
  late Box<String> _settingsBox;
  bool _isInitialized = false;

  static const _secureStorage = FlutterSecureStorage();
  static const _hiveKeyName = 'hive_encryption_key';

  /// Get or create a Hive encryption key stored in secure storage
  Future<List<int>> _getEncryptionKey() async {
    final existing = await _secureStorage.read(key: _hiveKeyName);
    if (existing != null) {
      return base64Url.decode(existing);
    }
    // Generate a new 32-byte key
    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _secureStorage.write(key: _hiveKeyName, value: base64Url.encode(key));
    return key;
  }

  /// Initialize Hive and open boxes
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    final keyBytes = await _getEncryptionKey();
    final cipher = HiveAesCipher(keyBytes);
    
    _scanHistoryBox = await Hive.openBox<Map>('scan_history', encryptionCipher: cipher);
    _settingsBox = await Hive.openBox<String>('settings', encryptionCipher: cipher);
    
    _isInitialized = true;
  }

  // ============ SCAN HISTORY ============

  /// Cache a scan result locally
  Future<void> cacheScan(Map<String, dynamic> scan) async {
    final id = scan['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _scanHistoryBox.put(id, scan);
  }

  /// Get all cached scans
  List<Map<String, dynamic>> getCachedScans() {
    return _scanHistoryBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
  }

  /// Get cached scans by risk level
  List<Map<String, dynamic>> getCachedScansByRisk(String riskLevel) {
    return getCachedScans()
        .where((s) => s['risk_level'] == riskLevel)
        .toList();
  }

  /// Clear old scans (keep last 100)
  Future<void> pruneOldScans({int keepCount = 100}) async {
    final scans = getCachedScans();
    if (scans.length <= keepCount) return;
    
    final toRemove = scans.skip(keepCount);
    for (final scan in toRemove) {
      final id = scan['id']?.toString();
      if (id != null) {
        await _scanHistoryBox.delete(id);
      }
    }
  }

  /// Sync with server (fetch from API and update cache)
  Future<void> syncWithServer(Future<List<dynamic>> Function() fetchFromServer) async {
    try {
      final serverScans = await fetchFromServer();
      
      // Update cache with server data
      for (final scan in serverScans) {
        if (scan is Map<String, dynamic>) {
          await cacheScan(scan);
        }
      }
      
      await pruneOldScans();
    } catch (e) {
      // Offline - use cached data
      print('Sync failed, using cached data: $e');
    }
  }

  // ============ SETTINGS ============

  /// Save a setting
  Future<void> saveSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  /// Get a setting
  String? getSetting(String key) {
    return _settingsBox.get(key);
  }

  /// Check if user is logged in (has cached token)
  bool get isLoggedIn => getSetting('auth_token') != null;

  // ============ BLOCKED SENDERS ============

  /// Get locally cached blocked senders
  List<String> getBlockedSenders() {
    final blocked = getSetting('blocked_senders');
    if (blocked == null) return [];
    return blocked.split(',');
  }

  /// Add sender to blocked list locally
  Future<void> addBlockedSender(String sender) async {
    final blocked = getBlockedSenders();
    if (!blocked.contains(sender)) {
      blocked.add(sender);
      await saveSetting('blocked_senders', blocked.join(','));
    }
  }

  /// Check if sender is blocked
  bool isSenderBlocked(String sender) {
    return getBlockedSenders().contains(sender);
  }

  // ============ CLEANUP ============

  /// Clear all scan history
  Future<void> clearScans() async {
    await _scanHistoryBox.clear();
  }

  /// Clear only settings (tokens, preferences) - keeps scan history on device
  Future<void> clearSettings() async {
    await _settingsBox.clear();
  }

  /// Clear all cached data (both history and settings)
  Future<void> clearAll() async {
    await _scanHistoryBox.clear();
    await _settingsBox.clear();
  }
}

/// Global instance
final offlineCacheService = OfflineCacheService();
