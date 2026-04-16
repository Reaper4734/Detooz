import 'package:flutter/material.dart';


import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_provider.dart';
import 'ui/providers.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/login_screen.dart';
import 'services/offline_cache_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_messaging_service.dart';
import 'services/ai_service.dart';
import 'services/translation/translation_service.dart';
import '../ui/components/tr.dart';
import '../ui/components/tr_strings.dart';

/// Global navigator key for notification tap navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase (required for FCM push notifications) - Skip on Web for now
    if (!kIsWeb) {
      await Firebase.initializeApp();
      
      // Initialize Firebase Cloud Messaging (for push when app is closed)
      try {
        await firebaseMessagingService.initialize();
      } catch (e) {
        debugPrint('⚠️ Firebase Messaging init failed (Play Services disabled/restricted?): $e');
      }
    } else {
      debugPrint('⚠️ Web detected: Skipping Firebase initialization');
    }

    // Initialize offline cache
    await offlineCacheService.initialize();
    
    // Initialize local push notifications
    await notificationService.initialize();
    notificationService.setNavigatorKey(navigatorKey);

    // Initialize AI Model (Hybrid Shield)
    await aiService.loadModel();
    
    // Initialize Translation Service (ML Kit)
    await TranslationService().initialize();
    
    // Preload is handled during Language Selector screen; Hive persists it instantly.
    
    runApp(const ProviderScope(child: MyApp()));
  } catch (e, stack) {
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF8B0000), // Dark Red
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'FATAL ERROR ON STARTUP:\n\n$e\n\n$stack',
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final currentLang = ref.watch(languageProvider);

    return MaterialApp(
      key: ValueKey('${themeMode.name}_$currentLang'),
      navigatorKey: navigatorKey,
      title: tr('Detooz'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return authState.when(
      data: (isAuthenticated) => isAuthenticated ? const MainScreen() : const LoginScreen(),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const LoginScreen(), // Default to login on error
    );
  }
}
