import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Track which field is being edited (null = none)
  String? _editingField;
  
  // Controllers for each field
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  bool _isSaving = false;
  
  // Original values for cancel
  String _originalValue = '';

  @override
  void initState() {
    super.initState();
    // Load fresh profile data
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() => _editingField = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
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
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Tr('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              _buildAvatar(profile.name),
              const SizedBox(height: 32),
              
              // Personal Info
              _buildSectionHeader('Personal Info'),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildEditableField(
                      fieldKey: 'firstName',
                      label: 'First Name',
                      controller: _firstNameController,
                      value: profile.firstName,
                      isRequired: true,
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    _buildEditableField(
                      fieldKey: 'middleName',
                      label: 'Middle Name',
                      controller: _middleNameController,
                      value: profile.middleName ?? '',
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    _buildEditableField(
                      fieldKey: 'lastName',
                      label: 'Last Name',
                      controller: _lastNameController,
                      value: profile.lastName,
                      isRequired: true,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Contact Info
              _buildSectionHeader('Contact Info'),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildEditableField(
                      fieldKey: 'email',
                      label: 'Email',
                      controller: _emailController,
                      value: profile.email,
                      icon: Icons.email_outlined,
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    _buildEditableField(
                      fieldKey: 'phone',
                      label: 'Phone',
                      controller: _phoneController,
                      value: profile.phone ?? 'Not set',
                      icon: Icons.phone_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderDark, width: 4),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tr(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: child,
    );
  }

  Widget _buildEditableField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required String value,
    IconData? icon,
    bool isRequired = false,
  }) {
    final isEditing = _editingField == fieldKey;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF71717A), size: 16),
                const SizedBox(width: 8),
              ],
              Tr(
                label,
                style: const TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (isRequired)
                const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          
          // Value or Edit Field
          if (isEditing)
            _buildEditMode(controller)
          else
            _buildViewMode(fieldKey, value.isEmpty ? 'Not set' : value, controller),
        ],
      ),
    );
  }

  Widget _buildViewMode(String fieldKey, String value, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: value == 'Not set' ? const Color(0xFF71717A) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _startEditing(fieldKey, controller),
          icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildEditMode(TextEditingController controller) {
    return Column(
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF27272A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => _cancelEditing(controller),
              child: const Tr('Cancel', style: TextStyle(color: Color(0xFF71717A))),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveField,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Tr('Save', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}
