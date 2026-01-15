import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/scan_view_model.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/guardian_view_model.dart';
import '../../services/api_service.dart';
import '../../services/offline_cache_service.dart';

// ============ STATE NOTIFIERS ============

/// Manages the list of scans from API
class ScansNotifier extends StateNotifier<AsyncValue<List<ScanViewModel>>> {
  ScansNotifier() : super(const AsyncValue.loading()) {
    loadScans();
  }
  
  Future<void> loadScans() async {
    state = const AsyncValue.loading();
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
    } catch (e) {
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
      
      // Add to current state
      state.whenData((scans) {
        state = AsyncValue.data([scan, ...scans]);
      });
      
      // Cache
      await offlineCacheService.cacheScan(result);
      
      return scan;
    } catch (e) {
      return null;
    }
  }
}

/// Manages guardians from API
class GuardiansNotifier extends StateNotifier<AsyncValue<List<GuardianViewModel>>> {
  GuardiansNotifier() : super(const AsyncValue.loading()) {
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
      return false;
    }
  }
}

/// Auth state
class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false) {
    checkAuth();
  }
  
  Future<void> checkAuth() async {
    final token = await apiService.token;
    state = token != null;
  }
  
  Future<bool> login(String email, String password) async {
    try {
      final result = await apiService.login(email: email, password: password);
      state = result['access_token'] != null;
      return state;
    } catch (e) {
      state = false;
      return false;
    }
  }
  
  Future<bool> register(String email, String password, String name, String phone) async {
    try {
      final result = await apiService.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      state = result['access_token'] != null;
      return state;
    } catch (e) {
      state = false;
      return false;
    }
  }
  
  Future<void> logout() async {
    await apiService.clearToken();
    state = false;
  }
}

// ============ PROVIDERS ============

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

/// Scans provider (API-connected)
final scansProvider = StateNotifierProvider<ScansNotifier, AsyncValue<List<ScanViewModel>>>((ref) {
  return ScansNotifier();
});

/// Guardians provider (API-connected)
final guardiansProvider = StateNotifierProvider<GuardiansNotifier, AsyncValue<List<GuardianViewModel>>>((ref) {
  return GuardiansNotifier();
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
