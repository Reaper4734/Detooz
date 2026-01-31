import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../../services/api_service.dart';

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  ConsumerState<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _sharePatterns = false;
  bool _isExporting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load settings - share patterns defaults to false
    // TODO: Add shareScamPatterns to backend UserSettings model
    setState(() {
      _sharePatterns = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Tr('Privacy & Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Section
            _buildSectionHeader('Security'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildNavigationRow(
                    icon: Icons.key,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Change Password',
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(color: AppColors.borderDark, height: 1),
                  _buildSwitchRow(
                    icon: Icons.fingerprint,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Biometric Lock',
                    subtitle: 'Use fingerprint or face to unlock',
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Data Privacy Section
            _buildSectionHeader('Data Privacy'),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildSwitchRow(
                    icon: Icons.analytics_outlined,
                    iconColor: const Color(0xFF22C55E),
                    title: 'Share Scam Patterns',
                    subtitle: 'Help improve detection (anonymous)',
                    value: _sharePatterns,
                    onChanged: _toggleSharePatterns,
                  ),
                  const Divider(color: AppColors.borderDark, height: 1),
                  _buildNavigationRow(
                    icon: Icons.download,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Export My Data',
                    subtitle: 'Download all your data',
                    isLoading: _isExporting,
                    onTap: _exportData,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Danger Zone
            _buildSectionHeader('Danger Zone'),
            _buildGlassCard(
              borderColor: const Color(0x33EF4444),
              child: _buildNavigationRow(
                icon: Icons.delete_forever,
                iconColor: const Color(0xFFEF4444),
                title: 'Delete Account',
                titleColor: const Color(0xFFEF4444),
                subtitle: 'Permanently delete your account',
                isLoading: _isDeleting,
                onTap: _showDeleteAccountDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Change Password ---
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Tr('Change Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0x1AEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ),
                _buildPasswordField('Current Password', currentPasswordController),
                const SizedBox(height: 16),
                _buildPasswordField('New Password', newPasswordController),
                const SizedBox(height: 16),
                _buildPasswordField('Confirm Password', confirmPasswordController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Tr('Cancel', style: TextStyle(color: Color(0xFF71717A))),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                // Validate
                if (newPasswordController.text != confirmPasswordController.text) {
                  setDialogState(() => errorMessage = 'Passwords do not match');
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  setDialogState(() => errorMessage = 'Password must be at least 6 characters');
                  return;
                }
                
                setDialogState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                
                try {
                  await apiService.changePassword(
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    errorMessage = e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Tr('Change', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF71717A)),
        filled: true,
        fillColor: const Color(0xFF27272A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  // --- Biometric Lock ---
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Check if biometric is available
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canAuthenticate || !isDeviceSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Setup fingerprint or face ID in device settings first'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Authenticate first
      try {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Enable biometric lock for Detooz',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (didAuthenticate) {
          setState(() => _biometricEnabled = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric lock enabled'), backgroundColor: AppColors.success),
            );
          }
          // TODO: Save to secure storage
        }
      } on PlatformException catch (e) {
        if (mounted) {
          String message = 'Biometric not available';
          if (e.code == 'NotEnrolled') {
            message = 'No fingerprints registered. Setup in device settings.';
          } else if (e.code == 'NotAvailable') {
            message = 'Biometric hardware not available';
          } else if (e.message != null) {
            message = e.message!;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.warning),
          );
        }
      }
    } else {
      setState(() => _biometricEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric lock disabled'), backgroundColor: AppColors.success),
        );
      }
      // TODO: Remove from secure storage
    }
  }

  // --- Share Patterns Toggle ---
  Future<void> _toggleSharePatterns(bool value) async {
    setState(() => _sharePatterns = value);
    // TODO: Persist to backend when shareScamPatterns field is added
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Sharing enabled' : 'Sharing disabled'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // --- Export Data ---
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    
    try {
      final data = await apiService.exportData();
      
      // Save to downloads
      final directory = await getExternalStorageDirectory();
      final downloadsDir = Directory('${directory?.parent.parent.parent.parent.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${downloadsDir.path}/detooz_data_export_$timestamp.txt');
      await file.writeAsString(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported to ${file.path}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // --- Delete Account ---
  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete Account', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is permanent and cannot be undone. All your data will be deleted:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text('• Profile information', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                const Text('• Scan history', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                const Text('• Settings & preferences', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                const SizedBox(height: 16),
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x1AEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ),
                const Text('Enter your password to confirm:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _buildPasswordField('Password', passwordController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (passwordController.text.isEmpty) {
                  setDialogState(() => errorMessage = 'Password is required');
                  return;
                }
                
                setDialogState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                
                try {
                  await apiService.deleteAccount(password: passwordController.text);
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    // Logout and go to login
                    await apiService.clearToken();
                    ref.read(authProvider.notifier).state = const AsyncValue.data(false);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    errorMessage = e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    
    passwordController.dispose();
  }

  // --- UI Helpers ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Tr(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF71717A),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.borderDark),
      ),
      child: child,
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tr(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: titleColor ?? Colors.white)),
                  if (subtitle != null)
                    Tr(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            else
              const Icon(Icons.arrow_forward_ios, color: Color(0xFF71717A), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                if (subtitle != null)
                  Tr(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            inactiveThumbColor: const Color(0xFF71717A),
            inactiveTrackColor: const Color(0xFF3F3F46),
          ),
        ],
      ),
    );
  }
}
