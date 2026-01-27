import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/scan_view_model.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/guardian_view_model.dart';
import '../../services/api_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/ai_service.dart';

// ============ STATE NOTIFIERS ============

/// Manages the list of scans from API
class ScansNotifier extends StateNotifier<AsyncValue<List<ScanViewModel>>> {
  final Ref ref;
  
  ScansNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadScans();
  }
  
  Future<void> loadScans() async {
    // state = const AsyncValue.loading(); // Don't show loading on every refresh for UX
    try {
      final history = await apiService.getHistory(limit: 50);
      final scans = history.map((scan) => ScanViewModel.fromJson(scan as Map<String, dynamic>)).toList();
      
      // Cache locally
      for (final scanMap in history) {
        if (scanMap is Map<String, dynamic>) {
          await offlineCacheService.cacheScan(scanMap);
        }
      }
      
      state = AsyncValue.data(scans);
      state = AsyncValue.data(scans);
    } catch (e) {
      // Don't auto-logout on 401 here to prevent race conditions or loops.
      // Just show error state. AuthNotifier handles session validity.
       
      // Try to load from cache
      final cached = offlineCacheService.getCachedScans();
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached.map((s) => ScanViewModel.fromJson(s)).toList());
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }
  
  Future<ScanViewModel?> analyzeMessage(String sender, String message) async {
    try {
      final result = await apiService.analyzeSms(sender: sender, message: message);
      final scan = ScanViewModel.fromJson(result);
      
      state.whenData((scans) {
        state = AsyncValue.data([scan, ...scans]);
      });
      await offlineCacheService.cacheScan(result);
      return scan;
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // ref.read(authProvider.notifier).logout();
      }
      rethrow;
    }
  }

  /// Unified manual scan (Text, URL, Phone)
  Future<ScanViewModel?> manualScan(String content) async {
    try {
      // 1. Hybrid Shield: Check Local AI First
      final aiPrediction = await aiService.predict(content);
      final double aiConf = aiPrediction['confidence'];
      final String aiLabel = aiPrediction['label'];
      
      Map<String, dynamic> result;
      
      // If AI is SURE it's a scam, or if we have no internet (TODO: check connectivity)
      if (aiLabel == 'SCAM' && aiConf > 0.90) {
         result = {
           'risk_level': 'HIGH',
           'reason': 'AI detected scam pattern (Offline)',
           'scam_type': 'AI_DETECTED',
           'confidence': aiConf,
           'created_at': DateTime.now().toIso8601String(),
         };
         // Sync with backend in background - PASS LOCAL VERDICT
         apiService.manualScan(
            content: content, 
            localRiskLevel: 'HIGH',
            localConfidence: aiConf,
            localScamType: 'AI_DETECTED'
         ).ignore();
      } else {
         // Fallback to Server
         result = await apiService.manualScan(content: content);
      }

      final scanMap = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender': 'Manual Check',
        'message': content,
        'platform': 'MANUAL',
        'risk_level': result['risk_level'],
        'risk_reason': result['reason'],
        'scam_type': result['scam_type'],
        'confidence': result['confidence'],
        'created_at': DateTime.now().toIso8601String(),
        'guardian_alerted': false,
      };

      final scan = ScanViewModel.fromJson(scanMap);
      
      state.whenData((scans) {
        state = AsyncValue.data([scan, ...scans]);
      });
      
      await offlineCacheService.cacheScan(scanMap);
      
      return scan;
    } catch (e) {
      print('Manual scan error in provider: $e');
      if (e.toString().contains('Unauthorized')) {
        // ref.read(authProvider.notifier).logout();
      }
      rethrow;
    }
  }

  Future<ScanViewModel?> analyzeImage(XFile imageFile) async {
    try {
      final result = await apiService.analyzeImage(imageFile);
      final scan = ScanViewModel.fromJson(result);
      
      state.whenData((scans) {
        state = AsyncValue.data([scan, ...scans]);
      });
      await offlineCacheService.cacheScan(result);
      return scan;
    } catch (e) {
      print('Image analysis error in provider: $e');
      if (e.toString().contains('Unauthorized')) {
        // ref.read(authProvider.notifier).logout();
      }
      rethrow;
    }
  }
}

/// Manages guardians from API
class GuardiansNotifier extends StateNotifier<AsyncValue<List<GuardianViewModel>>> {
  final Ref ref;
  GuardiansNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadGuardians();
  }
  
  Future<void> loadGuardians() async {
    state = const AsyncValue.loading();
    try {
      final guardians = await apiService.getGuardians();
      state = AsyncValue.data(
        guardians.map((g) => GuardianViewModel.fromJson(g as Map<String, dynamic>)).toList()
      );
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // ref.read(authProvider.notifier).logout();
        state = AsyncValue.error(e, StackTrace.current);
        return;
      }
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<bool> addGuardian({
    required String name,
    required String phone,
    String? telegramChatId,
  }) async {
    try {
      final result = await apiService.addGuardian(
        name: name,
        phone: phone,
        telegramChatId: telegramChatId,
      );
      final guardian = GuardianViewModel.fromJson(result);
      
      state.whenData((guardians) {
        state = AsyncValue.data([...guardians, guardian]);
      });
      
      return true;
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        // ref.read(authProvider.notifier).logout();
      }
      return false;
    }
  }
}

/// Auth state
class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    checkAuth();
  }
  
  Future<void> checkAuth() async {
    // Artificial delay to ensure splash is visible (optional, but good for UX)
    // await Future.delayed(const Duration(milliseconds: 500)); 
    final token = await apiService.token;
    if (token == null) {
      await offlineCacheService.clearAll();
      state = const AsyncValue.data(false);
      return;
    }

    try {
      // Validate token by fetching profile
      await apiService.getUserProfile();
      state = const AsyncValue.data(true);
    } catch (e) {
      // Token invalid (e.g. user deleted from DB)
      await apiService.clearToken();
      await offlineCacheService.clearAll();
      state = const AsyncValue.data(false);
    }
  }
  
  Future<bool> login(String email, String password) async {
    try {
      final result = await apiService.login(email: email, password: password);
      final success = result['access_token'] != null;
      state = AsyncValue.data(success);
      return success;
    } catch (e) {
      throw e.toString();
    }
  }
  
  Future<bool> register(String email, String password, String firstName, String? middleName, String lastName, String phone, {String? countryCode}) async {
    try {
      final result = await apiService.register(
        email: email,
        password: password,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phone: phone,
        countryCode: countryCode,
      );
      final success = result['access_token'] != null;
      state = AsyncValue.data(success);
      return success;
    } catch (e) {
      throw e.toString();
    }
  }
  
  Future<void> logout() async {
    await apiService.clearToken();
    await offlineCacheService.clearAll();
    
    // Reset other providers to clear memory state
    ref.invalidate(scansProvider);
    ref.invalidate(guardiansProvider);
    ref.invalidate(userStatsProvider);
    ref.invalidate(userProfileProvider);
    
    state = const AsyncValue.data(false);
  }
}

// ============ PROVIDERS ============

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<bool>>((ref) {
  return AuthNotifier(ref);
});

/// Scans provider (API-connected)
final scansProvider = StateNotifierProvider<ScansNotifier, AsyncValue<List<ScanViewModel>>>((ref) {
  return ScansNotifier(ref);
});

/// Guardians provider (API-connected)
final guardiansProvider = StateNotifierProvider<GuardiansNotifier, AsyncValue<List<GuardianViewModel>>>((ref) {
  return GuardiansNotifier(ref);
});

/// Recent scans (just the latest 5)
final recentScansProvider = Provider<List<ScanViewModel>>((ref) {
  final scansAsync = ref.watch(scansProvider);
  return scansAsync.when(
    data: (scans) => scans.take(5).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Scan history (all scans)
final scanHistoryProvider = Provider<List<ScanViewModel>>((ref) {
  final scansAsync = ref.watch(scansProvider);
  return scansAsync.when(
    data: (scans) => scans,
    loading: () => [],
    error: (_, __) => [],
  );
});

// ============ USER PROFILE ============

class UserProfile {
  final int id;
  final String email;
  final String name;
  final String? phone;
  
  UserProfile({required this.id, required this.email, required this.name, this.phone});
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      phone: json['phone'],
    );
  }
}

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  UserProfileNotifier() : super(const AsyncValue.loading()) {
    loadProfile();
  }
  
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final data = await apiService.getUserProfile();
      state = AsyncValue.data(UserProfile.fromJson(data));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return UserProfileNotifier();
});

// ============ USER STATS & SETTINGS ============

/// User statistics model
class UserStats {
  final int totalScans;
  final int highRiskBlocked;
  final int mediumRiskDetected;
  final int lowRiskSafe;
  final int guardiansCount;
  final int trustedSendersCount;
  final int blockedSendersCount;
  final int protectionScore;
  final DateTime? lastScanAt;
  
  UserStats({
    required this.totalScans,
    required this.highRiskBlocked,
    required this.mediumRiskDetected,
    required this.lowRiskSafe,
    required this.guardiansCount,
    required this.trustedSendersCount,
    required this.blockedSendersCount,
    required this.protectionScore,
    this.lastScanAt,
  });
  
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalScans: json['total_scans'] ?? 0,
      highRiskBlocked: json['high_risk_blocked'] ?? 0,
      mediumRiskDetected: json['medium_risk_detected'] ?? 0,
      lowRiskSafe: json['low_risk_safe'] ?? 0,
      guardiansCount: json['guardians_count'] ?? 0,
      trustedSendersCount: json['trusted_senders_count'] ?? 0,
      blockedSendersCount: json['blocked_senders_count'] ?? 0,
      protectionScore: json['protection_score'] ?? 0,
      lastScanAt: json['last_scan_at'] != null 
        ? DateTime.parse(json['last_scan_at']) 
        : null,
    );
  }
}

/// User settings model
class UserSettings {
  final String language;
  final bool autoBlockHighRisk;
  final String alertGuardiansThreshold;
  final bool receiveTips;
  
  UserSettings({
    this.language = 'en',
    this.autoBlockHighRisk = true,
    this.alertGuardiansThreshold = 'HIGH',
    this.receiveTips = true,
  });
  
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      language: json['language'] ?? 'en',
      autoBlockHighRisk: json['auto_block_high_risk'] ?? true,
      alertGuardiansThreshold: json['alert_guardians_threshold'] ?? 'HIGH',
      receiveTips: json['receive_tips'] ?? true,
    );
  }
}

/// User stats provider
class UserStatsNotifier extends StateNotifier<AsyncValue<UserStats>> {
  UserStatsNotifier() : super(const AsyncValue.loading()) {
    loadStats();
  }
  
  Future<void> loadStats() async {
    state = const AsyncValue.loading();
    try {
      final data = await apiService.getUserStats();
      state = AsyncValue.data(UserStats.fromJson(data));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final userStatsProvider = StateNotifierProvider<UserStatsNotifier, AsyncValue<UserStats>>((ref) {
  return UserStatsNotifier();
});

/// User settings provider
class UserSettingsNotifier extends StateNotifier<AsyncValue<UserSettings>> {
  UserSettingsNotifier() : super(const AsyncValue.loading()) {
    loadSettings();
  }
  
  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final data = await apiService.getUserSettings();
      state = AsyncValue.data(UserSettings.fromJson(data));
    } catch (e) {
      // Return default settings on error
      state = AsyncValue.data(UserSettings());
    }
  }
  
  Future<bool> updateSettings({
    String? language,
    bool? autoBlockHighRisk,
    String? alertGuardiansThreshold,
    bool? receiveTips,
  }) async {
    try {
      final data = await apiService.updateUserSettings(
        language: language,
        autoBlockHighRisk: autoBlockHighRisk,
        alertGuardiansThreshold: alertGuardiansThreshold,
        receiveTips: receiveTips,
      );
      state = AsyncValue.data(UserSettings.fromJson(data));
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> setLanguage(String lang) async {
    try {
      await apiService.setLanguage(lang);
      state.whenData((settings) {
        state = AsyncValue.data(UserSettings(
          language: lang,
          autoBlockHighRisk: settings.autoBlockHighRisk,
          alertGuardiansThreshold: settings.alertGuardiansThreshold,
          receiveTips: settings.receiveTips,
        ));
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}

final userSettingsProvider = StateNotifierProvider<UserSettingsNotifier, AsyncValue<UserSettings>>((ref) {
  return UserSettingsNotifier();
});

// ============ TRUSTED SENDERS ============

/// Trusted sender model
class TrustedSender {
  final int id;
  final String sender;
  final String? name;
  final String? reason;
  final DateTime createdAt;
  
  TrustedSender({
    required this.id,
    required this.sender,
    this.name,
    this.reason,
    required this.createdAt,
  });
  
  factory TrustedSender.fromJson(Map<String, dynamic> json) {
    return TrustedSender(
      id: json['id'],
      sender: json['sender'],
      name: json['name'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Trusted senders provider
class TrustedSendersNotifier extends StateNotifier<AsyncValue<List<TrustedSender>>> {
  TrustedSendersNotifier() : super(const AsyncValue.loading()) {
    loadTrustedSenders();
  }
  
  Future<void> loadTrustedSenders() async {
    state = const AsyncValue.loading();
    try {
      final data = await apiService.getTrustedSenders();
      final senders = data.map((s) => TrustedSender.fromJson(s as Map<String, dynamic>)).toList();
      state = AsyncValue.data(senders);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<bool> markTrusted(String sender, {String? name, String? reason}) async {
    try {
      final result = await apiService.markTrusted(sender: sender, name: name, reason: reason);
      final newSender = TrustedSender.fromJson(result);
      state.whenData((senders) {
        state = AsyncValue.data([...senders, newSender]);
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> removeTrusted(String sender) async {
    try {
      await apiService.removeTrusted(sender);
      state.whenData((senders) {
        state = AsyncValue.data(senders.where((s) => s.sender != sender).toList());
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}

final trustedSendersProvider = StateNotifierProvider<TrustedSendersNotifier, AsyncValue<List<TrustedSender>>>((ref) {
  return TrustedSendersNotifier();
});

// ============ FEEDBACK ============

/// Submit feedback on a scan
Future<bool> submitScanFeedback(int scanId, String verdict, {String? comment}) async {
  try {
    await apiService.submitFeedback(
      scanId: scanId,
      userVerdict: verdict,
      comment: comment,
    );
    return true;
  } catch (e) {
    return false;
  }
}

// ============ REPUTATION ============

/// Check URL reputation
Future<Map<String, dynamic>?> checkUrlReputation(String url) async {
  try {
    return await apiService.checkUrlReputation(url);
  } catch (e) {
    return null;
  }
}

/// Check phone reputation
Future<Map<String, dynamic>?> checkPhoneReputation(String phone) async {
  try {
    return await apiService.checkPhoneReputation(phone);
  } catch (e) {
    return null;
  }
}

/// Report a scam
Future<bool> reportScam(String value, String type, {String? reason}) async {
  try {
    await apiService.reportScam(value: value, type: type, reason: reason);
    return true;
  } catch (e) {
    return false;
  }
}
