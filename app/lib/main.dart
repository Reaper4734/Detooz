import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/theme_provider.dart';
import 'ui/screens/main_screen.dart';
import 'services/offline_cache_service.dart';
import 'services/sms_receiver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize offline cache
  await offlineCacheService.initialize();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  
  @override
  void initState() {
    super.initState();
    // Initialize SMS receiver after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      smsReceiverService.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Detooz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
