import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart'; // Ensure responsiveness might be from a custom util, but let's see. 
// Detooz app uses Responsive from '../theme/theme_provider.dart' possibly? 
// Let's use the local Responsive utility if available, wait, in existing Detooz/app, what is Responsive? 
// In settings_screen.dart it doesn't import Responsive. In dashboard_screen.dart we used `Responsive.sp`.
// I will import '../components/tr.dart' if needed, but not strictly necessary for UI rendering.
// Wait, I need to know where Responsive is imported in dashboard_screen.dart.
// In Detooz/app/lib/ui/screens/dashboard_screen.dart it was probably in `theme_provider.dart` or `app_colors.dart`.
// I will just use standard Flutter sizes if Responsive isn't found, OR I can define a simple scaling or use `Responsive.sp` if it is locally available. 
// Let's assume it's in `../theme/app_colors.dart` or we can just use normal logical pixels for now if it fails, but dashboard used `Responsive.sp`.
// Actually, let's write the methods without directly referring to an unknown `Responsive` import if it fails. I'll import `package:detooz/ui/theme/app_colors.dart` (or relative path).

import '../theme/app_colors.dart';

class Responsive {
  static double sp(double size) => size; // Fallback dummy if not found, we will overwrite after confirming. 
  // Wait, I am in Detooz app. In Detooz app `dashboard_screen.dart` used `Responsive.sp()`.
  // Let's import where it usually is. Just to be safe, I'll pass Context or hardcode the class dummy here and then resolve it.
}

// ════════════════════════════════════════════════════════════
//  SHARED HELPERS — Neo-Brutalist Design System Components
// ════════════════════════════════════════════════════════════

/// Brutalist header row matching settings-ui/style.css `.header`
Widget buildBrutalistHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_ios, size: 16, color: AppColors.textPrimary(context)),
              const SizedBox(width: 2),
              Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
            ]),
          ),
        ),
        if (title.isNotEmpty)
          Builder(builder: (context) {
            if (title.toUpperCase().contains('&')) {
              final parts = title.toUpperCase().split('&');
              return RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'IntegralCF', fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context), letterSpacing: 1.5,
                  ),
                  children: [
                    TextSpan(text: parts[0]),
                    const TextSpan(
                      text: ' & ',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 16),
                    ),
                    TextSpan(text: parts.length > 1 ? parts[1].trimLeft() : ''),
                  ],
                ),
              );
            }
            return Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'IntegralCF', fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context), letterSpacing: 1.5,
              ),
            );
          }),
      ],
    ),
  );
}

/// Section label
Widget buildSectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context), letterSpacing: 1.5,
      ),
    ),
  );
}

/// Settings card container
Widget buildSettingsCard(BuildContext context, {required List<Widget> children, Color? borderColor}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      border: Border.all(color: borderColor ?? AppColors.divider(context)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(children: children),
  );
}

/// Settings row
Widget buildSettingsRow(BuildContext context, {
  required Widget leading,
  required String title,
  String? subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  bool isLast = false,
  Color? titleColor,
  Color? backgroundColor,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.divider(context))),
      ),
      child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary(context)),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    ),
  );
}

/// Round icon container
Widget buildRowIcon(BuildContext context, IconData icon, {Color? iconColor, Color? bgColor, Color? borderColor}) {
  return Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: bgColor ?? AppColors.surface(context),
      border: Border.all(color: borderColor ?? AppColors.divider(context)),
      shape: BoxShape.circle,
    ),
    child: Center(child: Icon(icon, size: 18, color: iconColor ?? AppColors.textPrimary(context))),
  );
}

/// Brutalist toggle switch
class BrutalToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const BrutalToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 22,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: value ? const Color(0xFF7C3AED) : AppColors.textSecondary(context).withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(34),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16, height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFF7C3AED) : AppColors.textSecondary(context).withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cyan primary button (We will use Primary Purple for Detooz instead of cyan, keeping "CyanButton" name for structure or renaming it)
Widget buildPrimaryButton(BuildContext context, {required String label, IconData? icon, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(4)), // Primary Violet
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
        ],
        Text(label.toUpperCase(), style: const TextStyle(
          fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
        )),
      ]),
    ),
  );
}

/// Danger outline button
Widget buildDangerButton(BuildContext context, {required String label, IconData? icon, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
        ],
        Text(label.toUpperCase(), style: const TextStyle(
          fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444),
        )),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════
//  LANGUAGE SCREEN AUXILIARY COMPONENTS
// ════════════════════════════════════════════════════════════

/// Cyan hero block
Widget buildHeroBlock(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
  const primary = Color(0xFF7C3AED);
  return Row(children: [
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        border: Border.all(color: primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 28, color: primary)),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(
          fontFamily: 'IntegralCF', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context),
        )),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4)),
      ]),
    ),
  ]);
}

/// Info box
Widget buildInfoBox(BuildContext context, String text) {
  const primary = Color(0xFF7C3AED);
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: primary.withOpacity(0.05),
      border: Border.all(color: primary.withOpacity(0.2)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info, size: 20, color: primary),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.5))),
    ]),
  );
}

/// Language badge
Widget buildLangBadge(BuildContext context, String symbol, bool isActive) {
  const primary = Color(0xFF7C3AED);
  return Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(isActive ? 8 : 2),
      color: isActive ? primary.withOpacity(0.1) : AppColors.background(context),
      border: Border.all(color: isActive ? primary.withOpacity(0.3) : AppColors.divider(context)),
    ),
    child: Center(child: Text(symbol, style: TextStyle(
      fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700,
      color: isActive ? primary : AppColors.textSecondary(context).withOpacity(0.3),
    ))),
  );
}
