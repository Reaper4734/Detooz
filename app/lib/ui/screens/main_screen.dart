import 'package:flutter/material.dart';
import '../components/bottom_nav_bar.dart';
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
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
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
    // This enables guardian alerts even when app is closed
    firebaseMessagingService.registerTokenWithBackend();
    
    // Initialize SMS/WhatsApp/Telegram receiver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      smsReceiverService.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
