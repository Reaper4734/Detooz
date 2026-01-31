import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_provider.dart';
import '../providers.dart';
import 'language_selector_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'bookmarks_screen.dart';
import '../components/tr.dart';

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

    
    // Aesthetic Constants
    const glassColor = Color(0xFF18181B); // Zinc-900
    const glassBorder = Color(0xFF3F3F46); // Zinc-700/Border
    const primaryColor = Color(0xFF7C3AED); // Violet-600
    const trueBlack = Color(0xFF000000); 

    return Scaffold(
      backgroundColor: trueBlack,
      appBar: AppBar(
        title: Tr('Settings', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
        backgroundColor: trueBlack.withOpacity(0.9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 80,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
              const SizedBox(width: 4),
              Tr('Back', style: TextStyle(color: primaryColor, fontSize: 17, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: glassBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Summary Card (name + email, no edit button)
            _buildProfileCard(),
            
            const SizedBox(height: 32),
            
            // Account Section
            _buildSectionHeader('Account'),
            _buildGlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildIcon(Icons.person, const Color(0x1A7C3AED), primaryColor),
                      const SizedBox(width: 16),
                      Expanded(child: Tr('My Profile', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF71717A), size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Privacy & Security Row
            _buildGlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacySecurityScreen()),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildIcon(Icons.security, const Color(0x1A22C55E), const Color(0xFF22C55E)),
                      const SizedBox(width: 16),
                      Expanded(child: Tr('Privacy & Security', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF71717A), size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // My Bookmarks Row
            _buildGlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BookmarksScreen()),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildIcon(Icons.bookmark, const Color(0x1AF59E0B), const Color(0xFFF59E0B)),
                      const SizedBox(width: 16),
                      Expanded(child: Tr('My Bookmarks', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF71717A), size: 16),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Alerts Section (Only Safety Tips)
            _buildSectionHeader('Alerts'),
            settingsAsync.when(
              data: (settings) => _buildGlassCard(
                child: _buildSwitchRow(
                  icon: Icons.lightbulb,
                  iconBg: const Color(0x1AEAB308),
                  iconColor: const Color(0xFFEAB308),
                  title: tr('Safety Tips'),
                  value: settings.receiveTips,
                  onChanged: (v) => ref.read(userSettingsProvider.notifier).updateSettings(receiveTips: v),
                ),
              ),
              loading: () => _buildLoadingCard(),
              error: (e, _) => _buildErrorCard(e.toString()),
            ),

            const SizedBox(height: 32),

            // 5️⃣ Language Section (Independent)
            _buildSectionHeader('Language'),
            _buildGlassCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => showLanguageSelector(context, ref),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildIcon(Icons.language, const Color(0x1A6366F1), const Color(0xFF6366F1)),
                      const SizedBox(width: 16),
                      Expanded(child: Tr('Language', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
                      Consumer(builder: (context, ref, _) {
                          final langCode = ref.watch(languageProvider);
                          final langName = langCode == 'en' ? 'English' : 
                                            langCode == 'hi' ? 'हिन्दी' : langCode;
                          return Text(
                              langName,
                              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 15),
                          );
                      }),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA1A1AA)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 6️⃣ Appearance Section (Independent)
            _buildSectionHeader('Appearance'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSelectionRow(
                    title: tr('System'),
                    isSelected: currentTheme == ThemeMode.system,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.system),
                  ),
                  _buildDivider(),
                  _buildSelectionRow(
                    title: tr('Dark Mode'),
                    isSelected: currentTheme == ThemeMode.dark,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                  ),
                  _buildDivider(),
                  _buildSelectionRow(
                    title: tr('Light Mode'),
                    isSelected: currentTheme == ThemeMode.light,
                    onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 7️⃣ Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 8),
                      Tr('Log Out', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 8️⃣ Footer
            Center(
              child: Column(
                children: [
                   Tr('DeTooz Enterprise v2.4.0 (Build 301)', style: const TextStyle(color: Color(0xFF52525B), fontSize: 12, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 4),
                   Tr('© 2024 DeTooz Security Inc. All rights reserved.', style: const TextStyle(color: Color(0xFF3F3F46), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

  Widget _buildProfileCard() {
    final profileAsync = ref.watch(userProfileProvider);
    
    return profileAsync.when(
      data: (user) => _buildGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // No Edit button - just arrow to indicate tappable
          ],
        ),
      ),
      loading: () => _buildGlassCard(child: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))))),
      error: (e, __) => _buildGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: const Center(
                child: Text('?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Loading...', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Tr(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF71717A), // Zinc-500
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withOpacity(0.8), // Zinc-900 Glass
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3F3F46)), // Zinc-700
      ),
      child: child,
    );
  }

  Widget _buildLoadingCard() {
    return _buildGlassCard(
      child: const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))),
    );
  }

  Widget _buildErrorCard(String error) {
     return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Text(error, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildIcon(IconData icon, Color bg, Color color) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, indent: 68, color: Color(0xFF27272A)); // Zinc-800
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildIcon(icon, iconBg, iconColor),
          const SizedBox(width: 16),
          Expanded(child: Tr(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF7C3AED), // Primary Purple
            activeTrackColor: const Color(0xFF7C3AED).withOpacity(0.5),
            inactiveThumbColor: const Color(0xFFA1A1AA),
            inactiveTrackColor: const Color(0xFF27272A),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildIcon(icon, iconBg, iconColor),
          const SizedBox(width: 16),
          Expanded(child: Tr(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
          trailing,
        ],
      ),
    );
  }

    Widget _buildSelectionRow({
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
            const SizedBox(width: 4), 
            Expanded(child: Tr(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white))),
            if (isSelected) 
              const Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 20)
            else
              Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF52525B), width: 2))),
          ],
        ),
      ),
    );
  }
}
