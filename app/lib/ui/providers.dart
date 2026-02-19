import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../contracts/scan_view_model.dart';
import '../../contracts/guardian_view_model.dart';
import '../../services/api_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/ai_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/translation/translation_service.dart';

// ============ STATE NOTIFIERS ============

/// Manages the list of scans from API
class ScansNotifier extends StateNotifier<AsyncValue<List<ScanViewModel>>> {
  final Ref ref;
  
  // Removed auto-load from constructor to prevent race conditions on login/logout
  ScansNotifier(this.ref) : super(const AsyncValue.loading());
  
  Future<void> loadScans() async {
    // Device-only history: read exclusively from local Hive cache.
    // Each device maintains its own scan history.
    try {
      final cached = offlineCacheService.getCachedScans();
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached.map((s) => ScanViewModel.fromJson(s)).toList());
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
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
      
      // Check connectivity status
      final hasInternet = await connectivityService.hasInternet();
      
      // If AI is SURE it's a scam, OR if we have no internet → use local result
      if ((aiLabel == 'SCAM' && aiConf > 0.90) || !hasInternet) {
         // Map local AI labels to risk levels
         String riskLevel = 'LOW';
         String reason = 'Analyzed offline';
         String? scamType;
         
         if (aiLabel == 'SCAM') {
           riskLevel = aiConf > 0.70 ? 'HIGH' : 'MEDIUM';
           reason = hasInternet ? 'AI detected scam pattern' : 'AI detected scam pattern (Offline)';
           scamType = 'AI_DETECTED';
         } else if (aiLabel == 'OTP') {
           riskLevel = 'LOW';
           reason = 'Transactional OTP message';
           scamType = 'OTP';
         } else {
           riskLevel = 'LOW';
           reason = hasInternet ? 'Safe message' : 'Safe message (Analyzed Offline)';
         }
         
         result = {
           'risk_level': riskLevel,
           'risk_reason': reason,
           'scam_type': scamType,
           'confidence': aiConf,
           'created_at': DateTime.now().toIso8601String(),
           'source': 'local',  // Mark as local AI analysis
         };
         
         // Sync with backend in background if online
         if (hasInternet && aiLabel == 'SCAM') {
           apiService.manualScan(content: content).ignore();
         }
      } else {
         // Fallback to Server (we have internet and AI is uncertain)
         result = await apiService.manualScan(content: content);
      }

      final scanMap = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'sender': 'Manual Check',
        'message': content,
        'platform': 'MANUAL',
        'risk_level': result['risk_level'],
        'risk_reason': result['risk_reason'],
        'scam_type': result['scam_type'],
        'confidence': result['confidence'],
        'created_at': DateTime.now().toIso8601String(),
        'guardian_alerted': false,
        'source': result['source'] ?? 'cloud',  // 'local' or 'cloud'
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
  // Removed auto-load from constructor
  GuardiansNotifier(this.ref) : super(const AsyncValue.loading());
  
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

/// Auth state with auto-reconnect capability
class AuthNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref ref;
  StreamSubscription<bool>? _healthSubscription;
  bool _wasOffline = false;

  AuthNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initHealthMonitoring();
    checkAuth();
  }
  
  void _initHealthMonitoring() {
    // Start periodic health checks
    connectivityService.startHealthMonitoring();
    
    // Listen for backend coming online
    _healthSubscription = connectivityService.onBackendHealthChanged.listen((isOnline) {
      if (isOnline && _wasOffline) {
        debugPrint('🔄 Backend came online! Re-authenticating...');
        checkAuth();
      }
      _wasOffline = !isOnline;
    });
  }
  
  @override
  void dispose() {
    _healthSubscription?.cancel();
    connectivityService.stopHealthMonitoring();
    super.dispose();
  }
  
  Future<void> checkAuth() async {
    debugPrint('🔐 checkAuth: Starting...');
    final token = await apiService.token;
    debugPrint('🔐 checkAuth: Token = ${token != null ? "exists" : "null"}');
    
    if (token == null) {
      await offlineCacheService.clearAll();
      state = const AsyncValue.data(false);
      debugPrint('🔐 checkAuth: No token, going to login');
      return;
    }

    // Check connectivity first
    final hasInternet = await connectivityService.hasInternet();
    if (!hasInternet) {
       debugPrint('🔐 checkAuth: Offline mode, assuming Valid Token');
       _wasOffline = true;
       state = const AsyncValue.data(true);
       return;
    }
    
    // Also check if backend is actually reachable
    final backendReachable = await connectivityService.pingBackend();
    if (!backendReachable) {
       debugPrint('🔐 checkAuth: Backend unreachable, entering Offline Mode');
       _wasOffline = true;
       state = const AsyncValue.data(true);
       return;
    }

    try {
      // Validate token by fetching profile
      debugPrint('🔐 checkAuth: Validating token with /auth/me...');
      
      // Use shorter timeout for startup check (5s) to avoid "stuck on loading"
      await apiService.getUserProfile().timeout(const Duration(seconds: 5));
      
      _wasOffline = false;
      state = const AsyncValue.data(true);
      debugPrint('🔐 checkAuth: Token valid, authenticated!');
    } catch (e) {
      debugPrint('🔐 checkAuth: Validation failed - $e');
      
      // Only logout if explicitly Unauthorized
      if (e.toString().contains('Unauthorized')) {
         debugPrint('🔐 checkAuth: Token expired/invalid. Logging out.');
         await apiService.clearToken();
         await offlineCacheService.clearAll();
         state = const AsyncValue.data(false);
      } else {
         // Network error / Timeout -> Assume Offline Mode (Allow Access)
         debugPrint('🔐 checkAuth: Network error ($e), entering Offline Mode');
         _wasOffline = true;
         state = const AsyncValue.data(true);
      }
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
  
  Future<bool> register(String email, String password, String firstName, String? middleName, String lastName, String phone, {String? countryCode, String? emailToken, String? phoneToken}) async {
    try {
      final result = await apiService.register(
        email: email,
        password: password,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phone: phone,
        countryCode: countryCode,
        emailToken: emailToken,
        phoneToken: phoneToken,
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
    // Only clear settings (tokens etc), NOT scan history.
    // Scan history stays on the device for when the user logs back in.
    await offlineCacheService.clearSettings();
    
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
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final String? profilePicture;
  final DateTime? gracePeriodEnd;
  
  UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.phone,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.profilePicture,
    this.gracePeriodEnd,
  });
  
  /// Computed full name
  String get name => [firstName, middleName, lastName]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');
  
  /// Returns true if email verification is missing (phone is optional)
  bool get needsVerification => !emailVerified;
  
  /// Days remaining in grace period (null if no grace period set)
  int? get daysRemainingInGracePeriod {
    if (gracePeriodEnd == null) return null;
    final diff = gracePeriodEnd!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'],
      lastName: json['last_name'] ?? '',
      phone: json['phone'],
      emailVerified: json['email_verified'] ?? false,
      phoneVerified: json['phone_verified'] ?? false,
      profilePicture: json['profile_picture'],
      gracePeriodEnd: json['verification_grace_period_end'] != null 
          ? DateTime.tryParse(json['verification_grace_period_end'])
          : null,
    );
  }
}

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  // Removed auto-load from constructor
  UserProfileNotifier() : super(const AsyncValue.loading());
  
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final data = await apiService.getUserProfile();
      state = AsyncValue.data(UserProfile.fromJson(data));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Update profile and refresh
  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final data = await apiService.updateProfile(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phone: phone,
      );
      state = AsyncValue.data(UserProfile.fromJson(data));
    } catch (e) {
      rethrow; // Let UI handle the error
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
  // Removed auto-load from constructor to prevent race conditions
  UserStatsNotifier() : super(const AsyncValue.loading());
  
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
  // Removed auto-load from constructor to prevent race conditions
  UserSettingsNotifier() : super(const AsyncValue.loading());
  
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
  // Removed auto-load from constructor
  TrustedSendersNotifier() : super(const AsyncValue.loading());
  
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

// ============ TRANSLATION ============

/// Language state notifier for translation
/// When language changes, widgets that watch this will rebuild
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('en') {
    // Load the actual current language from TranslationService
    _initLanguage();
  }
  
  Future<void> _initLanguage() async {
    // Get current language from TranslationService (which loaded from SharedPreferences)
    final currentLang = TranslationService().currentLanguage;
    
    // Preload common UI strings into translation cache for sync access
    if (currentLang != 'en') {
      await TranslationService().preloadTranslations([
        // Navigation
        'Home', 'History', 'Guardians', 'Profile', 'Settings', 'Learn',
        'Back', 'Scan', 'English',
        // History filter chips
        'All', 'High Risk', 'Medium Risk', 'Safe',
        // Guardian tabs
        'Protect Me', 'Protect Others', 'Guardian Network',
        'Add New Guardian', 'My Guardians', 'People I Protect',
        // Common actions
        'Download', 'Cancel', 'OK', 'Restart Now', 'Later',
        // Dashboard
        'Protection Active', 'High Risk Blocked',
        // Education screen
        'Alerts', 'Tips', 'News', 'Search scams, tips...',
        'View All', 'Retry', 'min read',
        'Learn to Protect Yourself', 'Read Full Article',
        'Golden Rules', 'Never share OTPs',
        'Banks will never ask for your One-Time Password.',
        'Verify before clicking',
        'Check sender\'s address for misspellings.',
        'Quick Check: Bank Calls', 'DO', 'DON\'T',
        'Hang up and call the number on the back of your card.',
        'Trust caller ID or press numbers to "speak to an agent".',
        'Failed to load content',
        // Feed screen
        'Read more...', 'Latest Feed',
      ]);
    }
    
    // Set state AFTER preload completes to trigger rebuild with cached translations
    // Always set state (even if same value) by using a temp value trick
    if (currentLang != 'en') {
      state = 'en'; // Temp change
      state = currentLang; // Actual change - triggers rebuild
    } else {
      state = currentLang;
    }
  }
  
  Future<void> setLanguage(String code) async {
    state = code;
    
    // Preload common translations when language changes
    if (code != 'en') {
      await TranslationService().preloadTranslations([
        // Navigation
        'Home', 'History', 'Guardians', 'Profile', 'Settings', 'Learn',
        'Back', 'Scan', 'English',
        // History filter chips
        'All', 'High Risk', 'Medium Risk', 'Safe',
        // Guardian tabs
        'Protect Me', 'Protect Others', 'Guardian Network',
        'Add New Guardian', 'My Guardians', 'People I Protect',
        // Common actions
        'Download', 'Cancel', 'OK', 'Restart Now', 'Later',
        // Dashboard
        'Protection Active', 'High Risk Blocked',
        // Education screen
        'Alerts', 'Tips', 'News', 'Search scams, tips...',
        'View All', 'Retry', 'min read',
        'Learn to Protect Yourself', 'Read Full Article',
        'Golden Rules', 'Never share OTPs',
        'Banks will never ask for your One-Time Password.',
        'Verify before clicking',
        'Check sender\'s address for misspellings.',
        'Quick Check: Bank Calls', 'DO', 'DON\'T',
        'Hang up and call the number on the back of your card.',
        'Trust caller ID or press numbers to "speak to an agent".',
        'Failed to load content',
        // Feed screen
        'Read more...', 'Latest Feed',
      ]);
    }
  }
}

/// Language provider - watch this to rebuild when language changes
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

