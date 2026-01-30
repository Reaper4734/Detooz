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
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Safety: Handle completely null profile or fields
    final profile = ref.read(userProfileProvider).asData?.value;
    
    // Default empty if null
    final fullName = profile?.name ?? '';
    final nameParts = fullName.split(' ');
    
    String first = '';
    String last = '';
    String middle = '';
    
    if (nameParts.isNotEmpty) {
      first = nameParts.first;
      if (nameParts.length > 1) {
        last = nameParts.last;
      }
      if (nameParts.length > 2) {
        middle = nameParts.sublist(1, nameParts.length - 1).join(' ');
      }
    }
    
    _firstNameController = TextEditingController(text: first);
    _middleNameController = TextEditingController(text: middle);
    _lastNameController = TextEditingController(text: last);
    _phoneController = TextEditingController(text: profile?.phone ?? '');

    _firstNameController.addListener(_onFieldChanged);
    _middleNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isSaving = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully (Demo)'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final profile = ref.read(userProfileProvider).asData?.value;
    
    final userName = profile?.name ?? 'User';
    final userEmail = profile?.email ?? 'user@example.com';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfilePhoto(userName),
                      const SizedBox(height: 32),
                      _buildPersonalInfoSection(),
                      const SizedBox(height: 24),
                      _buildContactInfoSection(userEmail),
                      const SizedBox(height: 24),
                      _buildSecurityNotice(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(bottom: BorderSide(color: AppColors.borderDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Tr(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: (_isDirty && !_isSaving) ? _saveProfile : null,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : Tr(
                  'Save',
                  style: TextStyle(
                    color: _isDirty ? AppColors.primary : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto(String name) {
    String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Column(
      children: [
        Stack(
          children: [
            Container(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundDark, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Tr(
          'Tap to change profile photo',
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildGlassCard(
      title: 'Personal Info',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _buildTextField(
            label: 'First Name',
            controller: _firstNameController,
            hint: 'Enter first name', 
            validator: (v) => v!.isEmpty ? 'First name is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Middle Name',
            controller: _middleNameController,
            hint: 'Enter middle name',
            isOptional: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Last Name',
            controller: _lastNameController,
            hint: 'Enter last name',
            validator: (v) => v!.isEmpty ? 'Last name is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoSection(String email) {
    return _buildGlassCard(
      title: 'Contact Info',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Tr('Email Address', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: AppColors.textSecondaryLight, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Tr('Mobile Number', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
              ),
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('+91', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF27272A),
                        hintText: 'Mobile number',
                        hintStyle: const TextStyle(color: Color(0xFF52525B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Tr(
                  'Your mobile number is used for security alerts.',
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tr(
                  'Identity Protection',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Tr(
                  'Keeping your personal data accurate helps DeTooz protect your digital identity from unauthorized access attempts.',
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Tr(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isOptional = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Tr(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13)),
              if (isOptional)
                const Tr(' (Optional)', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF27272A),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF52525B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark, // #000000
        border: Border(top: BorderSide(color: Color(0xFF3F3F46), width: 1)), // #3F3F46 1px
      ),
      child: Row(
        children: [
          // CANCEL BUTTON (Secondary - Left)
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3F3F46), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: const Color(0xFFD4D4D8), // #D4D4D8 Text
                  padding: EdgeInsets.zero,
                ),
                child: const Tr(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16), // 16px Gap
          
          // SAVE BUTTON (Primary - Right)
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isDirty && !_isSaving ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.4), // Neon Haze Glow
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ] : [],
              ),
              child: ElevatedButton(
                onPressed: (_isDirty && !_isSaving) ? _saveProfile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED), // Bold Purple
                  disabledBackgroundColor: const Color(0xFF7C3AED).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0, // Shadow handled by Container
                  padding: EdgeInsets.zero,
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Tr(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
