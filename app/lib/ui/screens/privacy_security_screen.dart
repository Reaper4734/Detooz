import 'package:flutter/material.dart';
import '../components/neo_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../../services/api_service.dart';
import '../components/settings_widgets.dart';

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
  final bool _isDeleting = false;
  bool _showDeleteModal = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _sharePatterns = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildBrutalistHeader(context, tr('Privacy & Security')),

                  // ── Security Section ──
                  buildSectionLabel(context, tr('Security')),
                  buildSettingsCard(context, children: [
                    buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.key, iconColor: AppColors.warning),
                      title: tr('Change Password'),
                      trailing: Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary(context).withOpacity(0.3)),
                      onTap: _showChangePasswordDialog,
                    ),
                    buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.fingerprint, iconColor: AppColors.primary),
                      title: tr('Biometric Lock'),
                      subtitle: tr('Require fingerprint or face to open'),
                      trailing: BrutalToggle(value: _biometricEnabled, onChanged: _toggleBiometric),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // ── Data Privacy Section ──
                  buildSectionLabel(context, tr('Data Privacy')),
                  buildSettingsCard(context, children: [
                    buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.analytics, iconColor: AppColors.textSecondary(context).withOpacity(0.3)),
                      title: tr('Share Scam Patterns'),
                      subtitle: tr('Help improve detection (anonymous)'),
                      trailing: BrutalToggle(value: _sharePatterns, onChanged: _toggleSharePatterns),
                    ),
                    buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.download, iconColor: AppColors.primary),
                      title: tr('Export My Data'),
                      subtitle: tr('Download a copy of your data'),
                      trailing: _isExporting 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) 
                          : Icon(Icons.download, size: 18, color: AppColors.textSecondary(context).withOpacity(0.3)),
                      isLast: true,
                      onTap: _isExporting ? null : _exportData,
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // ── Danger Zone ──
                  buildSectionLabel(context, tr('Danger Zone')),
                  buildSettingsCard(context, borderColor: AppColors.danger.withValues(alpha: 0.4), children: [
                    buildSettingsRow(context,
                      leading: buildRowIcon(context, Icons.delete_forever, iconColor: AppColors.danger, bgColor: AppColors.danger.withValues(alpha: 0.1), borderColor: AppColors.danger.withValues(alpha: 0.2)),
                      title: tr('Delete Account'),
                      titleColor: AppColors.danger,
                      subtitle: tr('Permanently delete your account and data'),
                      isLast: true,
                      onTap: () => setState(() => _showDeleteModal = true),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Delete Account Modal ──
            if (_showDeleteModal) _buildDeleteAccountModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountModal() {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border.all(color: AppColors.divider(context), width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(offset: const Offset(4, 4), color: AppColors.divider(context))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Warning icon
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.warning, size: 24, color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('Delete Account?'), style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context),
                  )),
                  const SizedBox(height: 8),
                  Text(tr('This action is permanent and cannot be undone. Enter your password to confirm.'),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  
                  if (errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppColors.danger.withValues(alpha: 0.1),
                      child: Text(errorMessage!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),

                  // Password field
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      border: Border.all(color: AppColors.divider(context), width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: tr('Password'),
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary(context).withOpacity(0.4)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading ? null : () => setState(() => _showDeleteModal = false),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.background(context),
                            border: Border.all(color: AppColors.divider(context)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(child: Text(tr('CANCEL'), style: TextStyle(
                            fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context),
                          ))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading ? null : () async {
                          if (passwordController.text.isEmpty) {
                            setModalState(() => errorMessage = 'Password is required');
                            return;
                          }
                          setModalState(() {
                            isLoading = true;
                            errorMessage = null;
                          });
                          try {
                            await apiService.deleteAccount(password: passwordController.text);
                            if (mounted) {
                              setState(() => _showDeleteModal = false);
                              await apiService.clearToken();
                              ref.read(authProvider.notifier).state = const AsyncValue.data(false);
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            setModalState(() {
                              isLoading = false;
                              errorMessage = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(4)),
                          child: Center(child: isLoading 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(tr('DELETE'), style: const TextStyle(
                                fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                              ))),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }
    );
  }

  // --- Change Password Dialog ---
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
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: AppColors.divider(context), width: 2)),
          title: Text(tr('Change Password'), style: TextStyle(fontFamily: 'IntegralCF', fontSize: 16, color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.danger.withValues(alpha: 0.1),
                    child: Text(errorMessage!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                _buildBrutalPasswordField('Current Password', currentPasswordController),
                const SizedBox(height: 12),
                _buildBrutalPasswordField('New Password', newPasswordController),
                const SizedBox(height: 12),
                _buildBrutalPasswordField('Confirm Password', confirmPasswordController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(tr('CANCEL'), style: TextStyle(fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context))),
            ),
            GestureDetector(
              onTap: isLoading ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  setDialogState(() => errorMessage = 'Passwords do not match');
                  return;
                }
                if (newPasswordController.text.length < 8) {
                  setDialogState(() => errorMessage = tr('Password must be at least 8 characters'));
                  return;
                }
                if (!newPasswordController.text.contains(RegExp(r'[A-Z]'))) {
                  setDialogState(() => errorMessage = tr('Must contain 1 uppercase letter'));
                  return;
                }
                if (!newPasswordController.text.contains(RegExp(r'[0-9]'))) {
                  setDialogState(() => errorMessage = tr('Must contain 1 number'));
                  return;
                }
                if (!newPasswordController.text.contains(RegExp(r'[@#*&!$%^]'))) {
                  setDialogState(() => errorMessage = tr('Must contain 1 special char'));
                  return;
                }
                setDialogState(() { isLoading = true; errorMessage = null; });
                try {
                  await apiService.changePassword(
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    NeoSnackBar.show(context, message: tr('Password changed successfully'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    errorMessage = e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                child: isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('CHANGE'), style: const TextStyle(fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrutalPasswordField(String hint, TextEditingController controller) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border.all(color: AppColors.divider(context), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
        decoration: InputDecoration(
          hintText: tr(hint),
          hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary(context).withOpacity(0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  // --- Biometric Lock ---
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!canAuthenticate || !isDeviceSupported) {
        if (mounted) {
          NeoSnackBar.show(context, message: tr('Setup fingerprint or face ID in device settings first'), type: NeoSnackbarType.warning, position: NeoSnackbarPosition.bottom, duration: const Duration(seconds: 3));
        }
        return;
      }
      
      try {
        final didAuthenticate = await _localAuth.authenticate(localizedReason: 'Enable biometric lock for Detooz');
        if (didAuthenticate) {
          setState(() => _biometricEnabled = true);
          if (mounted) {
            NeoSnackBar.show(context, message: tr('Biometric lock enabled'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
          }
        }
      } on PlatformException catch (e) {
        if (mounted) {
          String message = 'Biometric not available';
          if (e.code == 'NotEnrolled') message = 'No fingerprints registered. Setup in device settings.';
          else if (e.code == 'NotAvailable') message = 'Biometric hardware not available';
          else if (e.message != null) message = e.message!;
          NeoSnackBar.show(context, message: message, type: NeoSnackbarType.warning, position: NeoSnackbarPosition.bottom);
        }
      }
    } else {
      setState(() => _biometricEnabled = false);
      if (mounted) {
        NeoSnackBar.show(context, message: tr('Biometric lock disabled'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
      }
    }
  }

  // --- Share Patterns Toggle ---
  Future<void> _toggleSharePatterns(bool value) async {
    setState(() => _sharePatterns = value);
    if (mounted) {
      NeoSnackBar.show(context, message: value ? 'Sharing enabled' : 'Sharing disabled', type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom, duration: const Duration(seconds: 1));
    }
  }

  // --- Export Data ---
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final data = await apiService.exportData();
      final directory = await getExternalStorageDirectory();
      final downloadsDir = Directory('${directory?.parent.parent.parent.parent.path}/Download');
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${downloadsDir.path}/detooz_data_export_$timestamp.txt');
      await file.writeAsString(data);
      
      if (mounted) {
        NeoSnackBar.show(context, message: 'Data exported to ${file.path}', type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom, duration: const Duration(seconds: 4));
      }
    } catch (e) {
      if (mounted) NeoSnackBar.show(context, message: 'Export failed: $e', type: NeoSnackbarType.error, position: NeoSnackbarPosition.bottom);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
