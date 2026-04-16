import 'dart:convert';
import 'dart:io';
import '../components/neo_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'otp_verification_screen.dart';
import 'change_email_screen.dart';
import '../components/settings_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  String? _editingField;
  
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  bool _isSaving = false;
  String _originalValue = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
    
    final profile = ref.read(userProfileProvider).asData?.value;
    
    _firstNameController = TextEditingController(text: profile?.firstName ?? '');
    _middleNameController = TextEditingController(text: profile?.middleName ?? '');
    _lastNameController = TextEditingController(text: profile?.lastName ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEditing(String field, TextEditingController controller) {
    setState(() {
      _editingField = field;
      _originalValue = controller.text;
    });
  }

  void _cancelEditing(TextEditingController controller) {
    controller.text = _originalValue;
    setState(() {
      _editingField = null;
      _originalValue = '';
    });
  }

  Future<void> _saveField() async {
    if (_editingField == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      await ref.read(userProfileProvider.notifier).updateProfile(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim().isNotEmpty 
            ? _middleNameController.text.trim() 
            : null,
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
      );
      
      if (mounted) {
        NeoSnackBar.show(context, message: tr('Saved'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom, duration: const Duration(seconds: 1));
        setState(() => _editingField = null);
      }
    } catch (e) {
      if (mounted) {
        NeoSnackBar.show(context, message: 'Failed: $e', type: NeoSnackbarType.error, position: NeoSnackbarPosition.bottom);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final profileAsync = ref.watch(userProfileProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildBrutalistHeader(context, tr('My Profile')),
                
                // ── Avatar Block ──
                Center(
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: SizedBox(
                      width: 80, height: 80,
                      child: Stack(children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.surface(context), shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 3)],
                          ),
                          child: ClipOval(
                            child: _buildAvatarContent(profile.name, profilePicture: profile.profilePicture),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // ── Personal Info ──
                buildSectionLabel(context, tr('Personal Info')),
                _buildBrutalField(
                  fieldKey: 'firstName', label: tr('First Name'), controller: _firstNameController,
                  value: profile.firstName, isRequired: true, icon: Icons.person,
                ),
                _buildBrutalField(
                  fieldKey: 'middleName', label: tr('Middle Name'), controller: _middleNameController,
                  value: profile.middleName ?? '', icon: Icons.person_outline,
                ),
                _buildBrutalField(
                  fieldKey: 'lastName', label: tr('Last Name'), controller: _lastNameController,
                  value: profile.lastName, isRequired: true, icon: Icons.person,
                ),
                const SizedBox(height: 8),
                
                // ── Contact Info ──
                buildSectionLabel(context, tr('Contact Info')),
                _buildBrutalField(
                  fieldKey: 'email', label: tr('Email Address'), controller: _emailController,
                  value: profile.email, icon: Icons.mail, readOnly: true,
                  onTap: () async {
                    // Step 1: Verify Old Email OTP First
                    final oldEmailVerified = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OTPVerificationScreen(
                          identifier: profile.email,
                          isPhone: false,
                          onVerifyOTP: (otp) async {
                            await Future.delayed(const Duration(milliseconds: 600));
                            return otp == '123456'; // Default mock UI test OTP
                          },
                        ),
                      ),
                    );

                    // Step 2: Open Change Email Screen if verified
                    if (oldEmailVerified == true && mounted) {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeEmailScreen(currentEmail: profile.email),
                        ),
                      );
                      if (result == true && mounted) {
                        ref.read(userProfileProvider.notifier).loadProfile();
                      }
                    }
                  },
                ),
                _buildBrutalField(
                  fieldKey: 'phone', label: tr('Phone Number'), controller: _phoneController,
                  value: profile.phone ?? '', icon: Icons.phone,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppColors.danger))),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String name, {String? profilePicture}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    if (profilePicture != null && profilePicture.isNotEmpty) {
      try {
        final bytes = base64Decode(profilePicture);
        return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildInitialAvatarContent(initial));
      } catch (_) {
        return _buildInitialAvatarContent(initial);
      }
    }
    return _buildInitialAvatarContent(initial);
  }

  Widget _buildInitialAvatarContent(String initial) {
    return Center(child: Text(initial, style: const TextStyle(
      fontFamily: 'IntegralCF', fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF00C2D1)
    )));
  }

  Widget _buildBrutalField({
    required String fieldKey, required String label, required TextEditingController controller,
    required String value, IconData? icon, bool isRequired = false, bool readOnly = false, IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final isEditing = _editingField == fieldKey;
    final displayValue = value.isEmpty ? 'Not set' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr(label.toUpperCase()), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1,
            color: AppColors.textSecondary(context),
          )),
          if (isRequired) Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        
        if (isEditing)
          Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                    border: InputBorder.none,
                    isDense: true,
                    prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.textSecondary(context)) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => _cancelEditing(controller),
                    child: Text(tr('CANCEL'), style: TextStyle(
                      fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context)
                    )),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSaving ? null : _saveField,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr('SAVE'), style: const TextStyle(
                              fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white
                            )),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border.all(color: AppColors.divider(context)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.textSecondary(context)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: readOnly ? AppColors.textSecondary(context) : (value.isNotEmpty ? AppColors.textPrimary(context) : AppColors.textSecondary(context).withOpacity(0.5)),
                  ),
                ),
              ),
              if (!readOnly)
                GestureDetector(
                  onTap: () => _startEditing(fieldKey, controller),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.edit, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                  ),
                )
              else if (onTap != null)
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.edit, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
                  ),
                )
              else if (trailingIcon != null)
                Icon(trailingIcon, size: 16, color: AppColors.textSecondary(context)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 16), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.textPrimary(context)),
              title: Text(tr('Take Photo'), style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.textPrimary(context)),
              title: Text(tr('Choose from Gallery'), style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    
    if (source == null) return;
    
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    
    if (picked == null) return;
    
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: tr('Edit Photo'),
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: tr('Edit Photo'),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return;
    
    setState(() => _isSaving = true);
    try {
      final bytes = await File(croppedFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      await apiService.uploadProfilePicture(base64Image);
      await ref.read(userProfileProvider.notifier).loadProfile();
      if (mounted) {
        NeoSnackBar.show(context, message: tr('Profile picture updated!'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
      }
    } catch (e) {
      if (mounted) {
        NeoSnackBar.show(context, message: 'Failed to upload: $e', type: NeoSnackbarType.error, position: NeoSnackbarPosition.bottom);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /*
  Future<void> _verifyEmail(String email) async {
    try {
      NeoSnackBar.show(context, message: tr('Sending verification code...'), type: NeoSnackbarType.loading, position: NeoSnackbarPosition.bottom, duration: const Duration(seconds: 2));
      
      final sendResult = await ApiService().sendEmailOTP(email: email);
      if (sendResult['success'] != true && sendResult['message'] != null) {
        if (!mounted) return;
        NeoSnackBar.show(context, message: sendResult['message'], type: NeoSnackbarType.error, position: NeoSnackbarPosition.bottom);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      NeoSnackBar.show(context, message: 'Failed to send OTP: $e', type: NeoSnackbarType.error, position: NeoSnackbarPosition.bottom);
      return;
    }
    
    if (!mounted) return;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(
          identifier: email,
          isPhone: false,
          onVerifyOTP: (otp) async {
            final response = await ApiService().verifyEmailOTP(email: email, otp: otp);
            if (response['access_token'] != null) {
              return true;
            }
            return false;
          },
          onResendOTP: () async {
            await ApiService().sendEmailOTP(email: email);
          },
        ),
      ),
    );
    
    if (result == true && mounted) {
      ref.read(userProfileProvider.notifier).loadProfile();
      NeoSnackBar.show(context, message: tr('Email verified!'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
    }
  }
  */
}
