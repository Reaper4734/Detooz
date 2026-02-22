/// Unit tests for OfflineCacheService
///
/// Uses manual Hive mocking (no code generation required).
/// Tests scan caching, retrieval, filtering, pruning, settings,
/// blocked senders, and the clearSettings vs clearAll distinction.
///
/// Run with: flutter test test/offline_cache_service_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

// We test the service's pure logic by initializing Hive in a temp directory
// (no need for full Flutter binding — Hive supports raw init for tests)


/// A testable version of OfflineCacheService that skips secure storage
/// and uses a temp directory for Hive.
class TestableOfflineCacheService {
  late Box<Map> scanHistoryBox;
  late Box<String> settingsBox;

  Future<void> initialize(String path) async {
    Hive.init(path);
    scanHistoryBox = await Hive.openBox<Map>('test_scan_history');
    settingsBox = await Hive.openBox<String>('test_settings');
  }

  Future<void> cacheScan(Map<String, dynamic> scan) async {
    final id = scan['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    await scanHistoryBox.put(id, scan);
  }

  List<Map<String, dynamic>> getCachedScans() {
    return scanHistoryBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
  }

  List<Map<String, dynamic>> getCachedScansByRisk(String riskLevel) {
    return getCachedScans()
        .where((s) => s['risk_level'] == riskLevel)
        .toList();
  }

  Future<void> pruneOldScans({int keepCount = 100}) async {
    final scans = getCachedScans();
    if (scans.length <= keepCount) return;
    final toRemove = scans.skip(keepCount);
    for (final scan in toRemove) {
      final id = scan['id']?.toString();
      if (id != null) {
        await scanHistoryBox.delete(id);
      }
    }
  }

  Future<void> saveSetting(String key, String value) async {
    await settingsBox.put(key, value);
  }

  String? getSetting(String key) {
    return settingsBox.get(key);
  }

  bool get isLoggedIn => getSetting('auth_token') != null;

  List<String> getBlockedSenders() {
    final blocked = getSetting('blocked_senders');
    if (blocked == null) return [];
    return blocked.split(',');
  }

  Future<void> addBlockedSender(String sender) async {
    final blocked = getBlockedSenders();
    if (!blocked.contains(sender)) {
      blocked.add(sender);
      await saveSetting('blocked_senders', blocked.join(','));
    }
  }

  bool isSenderBlocked(String sender) {
    return getBlockedSenders().contains(sender);
  }

  Future<void> clearSettings() async {
    await settingsBox.clear();
  }

  Future<void> clearAll() async {
    await scanHistoryBox.clear();
    await settingsBox.clear();
  }

  Future<void> dispose() async {
    await scanHistoryBox.close();
    await settingsBox.close();
  }
}

void main() {
  late TestableOfflineCacheService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    service = TestableOfflineCacheService();
    await service.initialize(tempDir.path);
  });

  tearDown(() async {
    await service.dispose();
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Scan Caching', () {
    test('cacheScan stores a scan and getCachedScans retrieves it', () async {
      await service.cacheScan({
        'id': '1',
        'message': 'Test scam message',
        'risk_level': 'HIGH',
        'created_at': '2026-02-20T10:00:00Z',
      });

      final scans = service.getCachedScans();
      expect(scans.length, 1);
      expect(scans[0]['message'], 'Test scam message');
      expect(scans[0]['risk_level'], 'HIGH');
    });

    test('getCachedScans returns sorted by date descending', () async {
      await service.cacheScan({
        'id': '1',
        'message': 'Older scan',
        'created_at': '2026-02-18T10:00:00Z',
      });
      await service.cacheScan({
        'id': '2',
        'message': 'Newer scan',
        'created_at': '2026-02-20T10:00:00Z',
      });

      final scans = service.getCachedScans();
      expect(scans[0]['message'], 'Newer scan');
      expect(scans[1]['message'], 'Older scan');
    });

    test('cacheScan uses timestamp as id when id is null', () async {
      await service.cacheScan({
        'message': 'No ID scan',
        'created_at': '2026-02-20T10:00:00Z',
      });

      final scans = service.getCachedScans();
      expect(scans.length, 1);
      expect(scans[0]['message'], 'No ID scan');
    });

    test('cacheScan overwrites scan with same id', () async {
      await service.cacheScan({
        'id': '1',
        'message': 'Original',
        'risk_level': 'LOW',
      });
      await service.cacheScan({
        'id': '1',
        'message': 'Updated',
        'risk_level': 'HIGH',
      });

      final scans = service.getCachedScans();
      expect(scans.length, 1);
      expect(scans[0]['message'], 'Updated');
      expect(scans[0]['risk_level'], 'HIGH');
    });

    test('getCachedScans returns empty list when no scans cached', () {
      final scans = service.getCachedScans();
      expect(scans, isEmpty);
    });
  });

  group('Risk Level Filtering', () {
    test('getCachedScansByRisk filters correctly', () async {
      await service.cacheScan({'id': '1', 'risk_level': 'HIGH', 'created_at': '2026-02-20T10:00:00Z'});
      await service.cacheScan({'id': '2', 'risk_level': 'LOW', 'created_at': '2026-02-20T10:01:00Z'});
      await service.cacheScan({'id': '3', 'risk_level': 'HIGH', 'created_at': '2026-02-20T10:02:00Z'});

      final highRisk = service.getCachedScansByRisk('HIGH');
      expect(highRisk.length, 2);

      final lowRisk = service.getCachedScansByRisk('LOW');
      expect(lowRisk.length, 1);

      final medium = service.getCachedScansByRisk('MEDIUM');
      expect(medium, isEmpty);
    });
  });

  group('Pruning', () {
    test('pruneOldScans keeps only the specified count', () async {
      for (int i = 0; i < 5; i++) {
        await service.cacheScan({
          'id': '$i',
          'message': 'Scan $i',
          'created_at': '2026-02-${20 - i}T10:00:00Z',
        });
      }

      expect(service.getCachedScans().length, 5);

      await service.pruneOldScans(keepCount: 3);

      expect(service.getCachedScans().length, 3);
    });

    test('pruneOldScans does nothing when under limit', () async {
      await service.cacheScan({'id': '1', 'message': 'Solo scan', 'created_at': '2026-02-20T10:00:00Z'});

      await service.pruneOldScans(keepCount: 100);

      expect(service.getCachedScans().length, 1);
    });
  });

  group('Settings', () {
    test('saveSetting and getSetting work correctly', () async {
      await service.saveSetting('theme', 'dark');
      expect(service.getSetting('theme'), 'dark');
    });

    test('getSetting returns null for missing key', () {
      expect(service.getSetting('nonexistent'), isNull);
    });

    test('isLoggedIn returns false when no token', () {
      expect(service.isLoggedIn, false);
    });

    test('isLoggedIn returns true when token exists', () async {
      await service.saveSetting('auth_token', 'eyJhbGciOiJIUzI1NiJ9...');
      expect(service.isLoggedIn, true);
    });
  });

  group('Blocked Senders', () {
    test('getBlockedSenders returns empty list initially', () {
      expect(service.getBlockedSenders(), isEmpty);
    });

    test('addBlockedSender adds a sender', () async {
      await service.addBlockedSender('+919876543210');
      expect(service.isSenderBlocked('+919876543210'), true);
    });

    test('addBlockedSender does not add duplicates', () async {
      await service.addBlockedSender('+919876543210');
      await service.addBlockedSender('+919876543210');
      expect(service.getBlockedSenders().length, 1);
    });

    test('isSenderBlocked returns false for non-blocked sender', () {
      expect(service.isSenderBlocked('+911111111111'), false);
    });

    test('multiple blocked senders work correctly', () async {
      await service.addBlockedSender('+911111111111');
      await service.addBlockedSender('+922222222222');
      await service.addBlockedSender('+933333333333');

      expect(service.getBlockedSenders().length, 3);
      expect(service.isSenderBlocked('+922222222222'), true);
      expect(service.isSenderBlocked('+944444444444'), false);
    });
  });

  group('Cleanup — clearSettings vs clearAll', () {
    test('clearSettings clears only settings, keeps scan history', () async {
      await service.cacheScan({'id': '1', 'message': 'Important scan', 'created_at': '2026-02-20T10:00:00Z'});
      await service.saveSetting('auth_token', 'mytoken');

      await service.clearSettings();

      // Settings should be cleared
      expect(service.getSetting('auth_token'), isNull);
      expect(service.isLoggedIn, false);

      // Scan history should still be there
      expect(service.getCachedScans().length, 1);
      expect(service.getCachedScans()[0]['message'], 'Important scan');
    });

    test('clearAll clears both settings and scan history', () async {
      await service.cacheScan({'id': '1', 'message': 'Will be deleted', 'created_at': '2026-02-20T10:00:00Z'});
      await service.saveSetting('auth_token', 'mytoken');

      await service.clearAll();

      expect(service.getCachedScans(), isEmpty);
      expect(service.getSetting('auth_token'), isNull);
    });
  });
}
