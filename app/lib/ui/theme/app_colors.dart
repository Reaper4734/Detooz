import 'package:flutter/material.dart';

/// Obsidian Brutalism Design Tokens for Detooz
/// Aligned to the CSS reference design system (`:root` variables)
/// All 7 reference UIs share this unified token set.
class AppColors {
  // ─── PRIMARY ───
  static const Color primary = Color(0xFF00C2D1);       // --cyan
  static const Color primaryDark = Color(0xFF00C2D1);   // Same as primary per reference
  static const Color primaryGlow = Color(0xFF00C2D1);   // Legacy alias → same cyan
  static const Color accent = Color(0xFFFF3D00);        // Orange accent

  // ─── BACKGROUND ───
  static const Color backgroundLight = Color(0xFFF4F7FA);  // --bg-main light
  static const Color backgroundDark = Color(0xFF121417);   // --color-obsidian

  // ─── SURFACE ───
  static const Color surfaceLight = Color(0xFFFFFFFF);     // --bg-card light
  static const Color surfaceDark = Color(0xFF1A1D21);      // --bg-card (neutral gray)

  // ─── EXTENDED SURFACE TOKENS ───
  static const Color cardDark = Color(0xFF1A1D21);         // --bg-card
  static const Color cardLight = Color(0xFFFFFFFF);        // --bg-card light
  static const Color cardHoverDark = Color(0xFF1E2227);    // --bg-card-hover
  static const Color cardHoverLight = Color(0xFFF8F9FA);   // --bg-card-hover light
  static const Color panelDark = Color(0xFF1A1F24);        // --bg-panel
  static const Color panelLight = Color(0xFFF1F4F8);       // --bg-panel light
  static const Color cyanGlow = Color(0x2600C2D1);         // rgba(0,194,209,0.15)
  static const Color shadowCyan = Color(0x4000C2D1);       // rgba(0,194,209,0.25)

  // ─── BORDER ───
  static const Color borderLight = Color(0xFFD4D9E0);     // --border-primary light
  static const Color borderDark = Color(0xFF363B42);       // rgba(217,221,227,0.12) on #121417

  // ─── TEXT ───
  static const Color textPrimaryLight = Color(0xFF121417);   // --text-primary light
  static const Color textSecondaryLight = Color(0xFF5B6470); // --text-secondary light
  static const Color textPrimaryDark = Color(0xFFD9DDE3);    // --color-mist
  static const Color textSecondaryDark = Color(0xFFB4B8BD);  // rgba(217,221,227,0.7)

  // ─── FUNCTIONAL ───
  static const Color danger = Color(0xFFE94F4F);         // --red
  static const Color dangerDark = Color(0xFFE94F4F);     // unified
  static const Color success = Color(0xFF28C76F);        // --green
  static const Color warning = Color(0xFFF5A623);        // --yellow

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
          ? const Color(0xFF2F3136) : const Color(0xFFE6EBF0);

  /// Neo-Brutalist block shadow for cards
  static List<BoxShadow> brutalCardShadow(BuildContext context) => [
    BoxShadow(
      offset: brutalShadowOffset,
      color: isDark(context) ? Colors.white.withValues(alpha: 0.15) : brutalShadow,
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
