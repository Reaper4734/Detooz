import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF7C3AED); // Bold Purple
  static const Color primaryGlow = Color(0xFF8B5CF6); // Neon Haze

  // Background
  static const Color backgroundLight = Color(0xFFF6F7F8); 
  static const Color backgroundDark = Color(0xFF000000); // True Black (OLED)
  
  // Surface
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF18181B); // Zinc Glass
  static const Color borderDark = Color(0xFF3F3F46); // Glass Edge
  
  // Functional
  static const Color danger = Color(0xFFF87171); // Hot Red
  static const Color dangerDark = Color(0xFFDC2626);
  static const Color success = Color(0xFF34D399); // Neon Mint
  static const Color warning = Color(0xFFFBBF24); // Solar Yellow
  
  // Text
  static const Color textPrimaryLight = Color(0xFF111418);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondaryDark = Color(0xFFD4D4D8); // Silver
  
  // Legacy / Risk mapping (kept for compatibility during refactor)
  static const Color riskHigh = danger;
  static const Color riskMedium = warning;
  static const Color riskLow = success;
  
  static const Color sms = success;
  static const Color whatsapp = Color(0xFF25D366);
  static const Color telegram = Color(0xFF2AABEE); // Updated Telegram Blue
}
