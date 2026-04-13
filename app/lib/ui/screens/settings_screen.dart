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
              buildBrutalistHeader(context, 'Settings'),

              // ── ACCOUNT ──
              buildSectionLabel(context, 'Account'),
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
              buildSectionLabel(context, 'Alerts'),
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
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                error: (e, _) => Text(e.toString(), style: const TextStyle(color: Color(0xFFEF4444))),
              ),
              const SizedBox(height: 24),

              // ── LANGUAGE ──
              buildSectionLabel(context, 'Language'),
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
              buildSectionLabel(context, 'Appearance'),
              buildSettingsCard(context, children: [
                _radioRow('System', ThemeMode.system, currentTheme, ref),
                _radioRow('Dark Mode', ThemeMode.dark, currentTheme, ref),
                _radioRow('Light Mode', ThemeMode.light, currentTheme, ref, isLast: true),
              ]),
              const SizedBox(height: 24),

              // ── LOG OUT ──
              GestureDetector(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: const Color(0xFFEF4444), width: 2), // Red border
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'LOG OUT',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: 13,
                          fontWeight: FontWeight.w700, // Explicitly heavy for Brutalism
                          color: Color(0xFFEF4444),
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
                  color: isActive ? const Color(0xFF7C3AED) : AppColors.textSecondary(context),
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
                          color: Color(0xFF7C3AED),
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
}
