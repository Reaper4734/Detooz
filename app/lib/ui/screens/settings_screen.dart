import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../providers.dart';
import 'language_selector_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'bookmarks_screen.dart';
import 'language_manager_screen.dart';
import '../components/tr.dart';
import '../components/settings_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  
  @override
  void initState() {
    super.initState();
    // Load profile data when entering settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final currentTheme = ref.watch(themeProvider);
    final settingsAsync = ref.watch(userSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildBrutalistHeader(context, tr('Settings'), showBackButton: false),

              // ── ACCOUNT ──
              buildSectionLabel(context, tr('Account')),
              buildSettingsCard(context, children: [
                buildSettingsRow(context,
                  leading: buildRowIcon(context, Icons.person),
                  title: tr('My Profile'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
                buildSettingsRow(context,
                  leading: buildRowIcon(context, Icons.security),
                  title: tr('Privacy & Security'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
                ),
                buildSettingsRow(context,
                  leading: buildRowIcon(context, Icons.bookmark),
                  title: tr('My Bookmarks'),
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen())),
                ),
              ]),
              const SizedBox(height: 24),

              // ── ALERTS ──
              buildSectionLabel(context, tr('Alerts')),
              settingsAsync.when(
                data: (settings) => buildSettingsCard(context, children: [
                  buildSettingsRow(context,
                    leading: buildRowIcon(context, Icons.lightbulb_outline),
                    title: tr('Safety Tips'),
                    trailing: BrutalToggle(
                      value: settings.receiveTips,
                      onChanged: (v) => ref.read(userSettingsProvider.notifier).updateSettings(receiveTips: v),
                    ),
                    isLast: true,
                  ),
                ]),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Text(e.toString(), style: TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(height: 24),

              // ── LANGUAGE ──
              buildSectionLabel(context, tr('Language')),
              buildSettingsCard(context, children: [
                Consumer(builder: (context, ref, _) {
                    final langCode = ref.watch(languageProvider);
                    final langName = langCode == 'en' ? 'English' : 
                                      langCode == 'hi' ? 'हिन्दी' : langCode;
                    return buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.language),
                      title: tr('App Language'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(langName, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary(context)),
                        ],
                      ),
                      onTap: () => showLanguageSelector(context, ref), // Assuming this still pops up or routes. Wait, the original code had this. I'll keep it. 
                    );
                }),
                buildSettingsRow(context,
                  leading: buildRowIcon(context, Icons.translate),
                  title: tr('SMS Detection Language'),
                  subtitle: tr('Manage scam detection language packs'),
                  trailing: Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary(context)),
                  isLast: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageManagerScreen())),
                ),
              ]),
              const SizedBox(height: 24),

              // ── APPEARANCE ──
              buildSectionLabel(context, tr('Appearance')),
              buildSettingsCard(context, children: [
                _radioRow('System', ThemeMode.system, currentTheme, ref),
                _radioRow('Dark Mode', ThemeMode.dark, currentTheme, ref),
                _radioRow('Light Mode', ThemeMode.light, currentTheme, ref, isLast: true),
              ]),
              const SizedBox(height: 24),

              // ── LOG OUT ──
              GestureDetector(
                onTap: () => _showLogoutDialog(context, ref),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: AppColors.danger, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'LOG OUT',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── FOOTER ──
              Center(
                child: Column(
                  children: [
                     Tr('DeTooz Enterprise v2.4.0 (Build 301)', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                     const SizedBox(height: 4),
                     Tr('© 2024 DeTooz Security Inc. All rights reserved.', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioRow(String title, ThemeMode mode, ThemeMode currentTheme, WidgetRef ref, {bool isLast = false}) {
    final isActive = currentTheme == mode;
    return GestureDetector(
      onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: AppColors.divider(context))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(tr(title), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.textSecondary(context),
                  width: 2,
                ),
              ),
              child: isActive
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: AppColors.divider(context), width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.logout, color: AppColors.danger, size: 24),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'LOG OUT?',
                style: TextStyle(
                  fontFamily: 'IntegralCF', fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Are you sure you want to log out? You will need to sign in again to access your account and scan history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary(context), height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      border: Border.all(color: AppColors.divider(context)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(child: Text(
                      'CANCEL',
                      style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                    )),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(authProvider.notifier).logout();
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(child: Text(
                      'LOG OUT',
                      style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    )),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
