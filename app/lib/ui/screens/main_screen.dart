import 'package:flutter/material.dart';
import '../components/bottom_nav_bar.dart';
import '../theme/responsive_utils.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'guardians_screen.dart';
import 'settings_screen.dart';
import 'education_screen.dart';

import '../../services/sms_receiver_service.dart';
import '../../services/firebase_messaging_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Navigate to a specific tab by index
  void navigateToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryScreen(),
    const GuardiansScreen(),
    const EducationScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Register FCM token with backend for push notifications
    firebaseMessagingService.registerTokenWithBackend();
    
    // Initialize SMS/WhatsApp/Telegram receiver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      smsReceiverService.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
