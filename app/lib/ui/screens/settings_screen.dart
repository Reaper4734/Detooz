import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _autoBlock = true;
  bool _aiScanning = true;
  bool _whatsapp = false;
  bool _guardianAlerts = true;
  bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: const [
              Icon(Icons.chevron_left, color: AppColors.primary, size: 30),
              Text('Back', style: TextStyle(color: AppColors.primary, fontSize: 16)),
            ],
          ),
        ),
        leadingWidth: 80,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
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
                  title: 'Auto-block high risk',
                  subtitle: 'Filter known scam numbers',
                  value: _autoBlock,
                  onChanged: (v) => setState(() => _autoBlock = v),
                ),
                const Divider(height: 1, indent: 60),
                _buildSwitchTile(
                  icon: Icons.psychology,
                  iconColor: Colors.purple,
                  title: 'AI Message Scanning',
                  subtitle: 'Analyze incoming SMS',
                  value: _aiScanning,
                  onChanged: (v) => setState(() => _aiScanning = v),
                ),
                const Divider(height: 1, indent: 60),
                _buildSwitchTile(
                  icon: Icons.chat,
                  iconColor: Colors.green,
                  title: 'WhatsApp Integration',
                  subtitle: 'Scan forwarded messages',
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
                _buildSwitchTile(
                  icon: Icons.supervised_user_circle,
                  iconColor: AppColors.danger,
                  title: 'Guardian Alerts',
                  subtitle: 'Notify family of threats',
                  value: _guardianAlerts,
                  onChanged: (v) => setState(() => _guardianAlerts = v),
                ),
                const Divider(height: 1, indent: 60),
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  iconColor: AppColors.warning,
                  title: 'Push Notifications',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
              ],
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
                  title: 'System Default',
                  isSelected: currentTheme == ThemeMode.system,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.system),
                ),
                const Divider(height: 1, indent: 60),
                _buildThemeTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  isSelected: currentTheme == ThemeMode.dark,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                ),
                const Divider(height: 1, indent: 60),
                _buildThemeTile(
                  icon: Icons.light_mode,
                  title: 'Light Mode',
                  isSelected: currentTheme == ThemeMode.light,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text('ScamShield v1.0.4', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                const SizedBox(height: 4),
                Text('© 2023 Security Corp.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
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
            const SizedBox(width: 16),
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
