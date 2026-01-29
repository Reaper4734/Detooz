import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_provider.dart';
import '../providers.dart';
import 'language_selector_screen.dart';
import '../components/tr.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // These will sync with API settings
  bool _aiScanning = true;
  bool _whatsapp = false;
  final bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final settingsAsync = ref.watch(userSettingsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Tr('Settings'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              Icon(Icons.chevron_left, color: AppColors.primary, size: 30),
              Tr('Back', style: TextStyle(color: AppColors.primary, fontSize: 16)),
            ],
          ),
        ),
        leadingWidth: 80,
      ),
      body: settingsAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Tr('Error loading settings: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Profile Header
            profileAsync.when(
              data: (user) => Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          if (user.phone != null)
                            Text(user.phone!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(), 
              error: (_,__) => SizedBox(),
            ),

            _buildSectionHeader('Detection'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.shield,
                    iconColor: Colors.blue,
                    title: tr('Auto-block high risk'),
                    subtitle: tr('Filter known scam numbers'),
                    value: settings.autoBlockHighRisk,
                    onChanged: (v) {
                      ref.read(userSettingsProvider.notifier).updateSettings(autoBlockHighRisk: v);
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSwitchTile(
                    icon: Icons.psychology,
                    iconColor: Colors.purple,
                    title: tr('AI Message Scanning'),
                    subtitle: tr('Analyze incoming SMS'),
                    value: _aiScanning,
                    onChanged: (v) => setState(() => _aiScanning = v),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSwitchTile(
                    icon: Icons.chat,
                    iconColor: Colors.green,
                    title: tr('WhatsApp Integration'),
                    subtitle: tr('Scan forwarded messages'),
                    value: _whatsapp,
                    onChanged: (v) => setState(() => _whatsapp = v),
                  ),
                ],
              ),
            ),
            
            _buildSectionHeader('Alerts'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildDropdownTile(
                    icon: Icons.supervised_user_circle,
                    iconColor: AppColors.danger,
                    title: tr('Guardian Alert Threshold'),
                    subtitle: tr('When to notify family'),
                    value: settings.alertGuardiansThreshold,
                    options: const ['HIGH', 'MEDIUM', 'ALL'],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(userSettingsProvider.notifier).updateSettings(alertGuardiansThreshold: v);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildSwitchTile(
                    icon: Icons.notifications_active,
                    iconColor: AppColors.warning,
                    title: tr('Receive Safety Tips'),
                    value: settings.receiveTips,
                    onChanged: (v) {
                      ref.read(userSettingsProvider.notifier).updateSettings(receiveTips: v);
                    },
                  ),
                ],
              ),
            ),

            _buildSectionHeader('Language'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: InkWell(
                onTap: () => showLanguageSelector(context, ref),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.translate, color: Colors.blue, size: 20),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tr('App Language', style: TextStyle(fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Consumer(
                              builder: (context, ref, _) {
                                final langCode = ref.watch(languageProvider);
                                final langName = langCode == 'en' ? 'English' : 
                                  langCode == 'hi' ? 'हिन्दी (Hindi)' :
                                  langCode == 'bn' ? 'বাংলা (Bengali)' :
                                  langCode == 'ta' ? 'தமிழ் (Tamil)' :
                                  langCode == 'te' ? 'తెలుగు (Telugu)' :
                                  langCode == 'mr' ? 'मराठी (Marathi)' :
                                  langCode;
                                return Text(
                                  langName,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            
            _buildSectionHeader('Appearance'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildThemeTile(
                    icon: Icons.settings_brightness,
                    title: tr('System Default'),
                    isSelected: currentTheme == ThemeMode.system,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.system),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildThemeTile(
                    icon: Icons.dark_mode,
                    title: tr('Dark Mode'),
                    isSelected: currentTheme == ThemeMode.dark,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildThemeTile(
                    icon: Icons.light_mode,
                    title: tr('Light Mode'),
                    isSelected: currentTheme == ThemeMode.light,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 32),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout),
                label: Tr('Log Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  foregroundColor: AppColors.danger,
                  elevation: 0,
                  side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Tr('DeTooz v1.1.0', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                  SizedBox(height: 4),
                  Tr('© 2026 DeTooz Team', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
                ],
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondaryLight,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value, 
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                ],
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            underline: SizedBox(),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.language, color: Theme.of(context).iconTheme.color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
