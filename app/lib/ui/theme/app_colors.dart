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
  static const Color borderDark = Color(0xFF7C3AED); // Purple glow edge
  static const Color borderLight = Color(0xFFC4B5FD); // Violet-300 — neon purple glow
  
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

  // ============ ADAPTIVE HELPERS ============
  // Use these in screens to auto-switch between light/dark

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? backgroundDark : backgroundLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceDark : surfaceLight;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textPrimaryDark : textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textSecondaryDark : textSecondaryLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? borderDark : borderLight;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Smoky purple shadow for cards — gives a 3D glow illusion
  static List<BoxShadow> cardShadow(BuildContext context) =>
      isDark(context)
          ? [
              BoxShadow(
                color: primary.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: primary.withOpacity(0.08),
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ]
          : [
              BoxShadow(
                color: primary.withOpacity(0.10),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: primary.withOpacity(0.06),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ];
}
