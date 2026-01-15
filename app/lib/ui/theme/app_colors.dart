import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF137FEC);      // Blue #137fec

  // Background
  static const Color backgroundLight = Color(0xFFF6F7F8); // #f6f7f8
  static const Color backgroundDark = Color(0xFF101922);  // #101922
  
  // Surface
  static const Color surfaceLight = Color(0xFFFFFFFF);    // #ffffff
  static const Color surfaceDark = Color(0xFF1C2630);     // #1c2630
  
  // Functional
  static const Color danger = Color(0xFFEF4444);          // #ef4444
  static const Color dangerDark = Color(0xFFDC2626);      // #dc2626
  static const Color success = Color(0xFF22C55E);         // #22c55e
  static const Color warning = Color(0xFFF59E0B);         // #f59e0b
  
  // Text
  static const Color textPrimaryLight = Color(0xFF111418);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF9DABB9);
  
  // Legacy / Risk mapping (kept for compatibility during refactor)
  static const Color riskHigh = danger;
  static const Color riskMedium = warning;
  static const Color riskLow = success;
  
  static const Color sms = success;
  static const Color whatsapp = Color(0xFF25D366);
  static const Color telegram = Color(0xFF2AABEE); // Updated Telegram Blue
}
