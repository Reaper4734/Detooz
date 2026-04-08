import 'package:flutter/material.dart';

/// Neo-Brutalist Design Tokens for Detooz
/// Migrated from design-kit.md CSS variables
/// Backward-compatible API surface preserved for unmigrated screens.
class AppColors {
  // ─── PRIMARY ───
  static const Color primary = Color(0xFF00E5FF);       // Cyan accent
  static const Color primaryDark = Color(0xFF00B8D4);   // Darker cyan
  static const Color primaryGlow = Color(0xFF00E5FF);   // Alias for legacy compat
  static const Color accent = Color(0xFFFF3D00);        // Orange accent

  // ─── BACKGROUND ───
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF101113);

  // ─── SURFACE ───
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A1A2E);

  // ─── BORDER ───
  static const Color borderLight = Color(0xFF000000);
  static const Color borderDark = Color(0xFF333333);

  // ─── TEXT ───
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF555555);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFAAAAAA);

  // ─── FUNCTIONAL ───
  static const Color danger = Color(0xFFFF3B30);
  static const Color dangerDark = Color(0xFFDC2626);    // Legacy compat
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFCC00);

  // ─── RISK LEVELS ───
  static const Color riskHigh = danger;
  static const Color riskMedium = warning;
  static const Color riskLow = success;

  // ─── PLATFORM ───
  static const Color sms = success;
  static const Color whatsapp = Color(0xFF25D366);
  static const Color telegram = Color(0xFF2AABEE);

  // ─── NEO-BRUTALIST SPECIFICS ───
  static const Color brutalShadow = Color(0xFF000000);
  static const double brutalBorderWidth = 2.0;
  static const Offset brutalShadowOffset = Offset(4, 4);

  // ════════ ADAPTIVE HELPERS ════════

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

  /// Divider / border colour (adaptive)
  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

  /// Neo-Brutalist block shadow for cards
  static List<BoxShadow> brutalCardShadow(BuildContext context) => [
    BoxShadow(
      offset: brutalShadowOffset,
      color: isDark(context) ? Colors.white.withOpacity(0.15) : brutalShadow,
      blurRadius: 0,
      spreadRadius: 0,
    ),
  ];

  /// Legacy soft shadow — aliased to brutal shadow for new design language
  static List<BoxShadow> cardShadow(BuildContext context) =>
      brutalCardShadow(context);

  /// Non-context background (for CustomPainter where context isn't available)
  static const Color background_static = backgroundDark;
}
