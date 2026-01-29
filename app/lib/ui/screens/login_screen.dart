import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
// import 'guardian_login_screen.dart'; // Removed
import 'guardians_screen.dart';
import 'admin/admin_login_screen.dart';
import '../components/tr.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Name Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  final _phoneController = TextEditingController();

  String _countryCode = "+91";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Validators
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (_isLogin) return null; // Relax validation for login, strict for registration

    if (value.length < 8) return 'Min 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain 1 uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain 1 number';
    if (!value.contains(RegExp(r'[@#*&!$%^]'))) return 'Must contain 1 special char';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      bool success;
      if (_isLogin) {
        success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        success = await ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _firstNameController.text.trim(),
          _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          _lastNameController.text.trim(),
          _phoneController.text.trim(),
          countryCode: _countryCode,
        );
      }
      
      setState(() => _isLoading = false);
      
      // If success
      if (success) {
        if (!_isLogin && mounted) {
          _showAddGuardianPrompt();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: tr('OK'), onPressed: () {}, textColor: Colors.white),
          ),
        );
      }
    }
  }

  Future<void> _showAddGuardianPrompt() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Tr('Registration Successful'),
        content: Tr('Enhance your safety by adding a trusted Guardian.\n'
          'Share an OTP with them to link accounts instantly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Tr('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuardiansScreen()),
              );
            },
            child: Tr('Add Guardian'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF7C3BED);
    const borderColor = Color(0x1AFFFFFF); // white/10
    const glassColor = Color(0x9918181B); // surface-dark/60 (approx)

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.3), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.2), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.security, size: 32, color: primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: 8),
                  Tr('Log in to continue your protection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: glassColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_isLogin) ...[
                                _buildInputLabel('First Name'),
                                SizedBox(height: 8),
                                _buildDarkTextField(
                                  controller: _firstNameController,
                                  hint: 'Enter your first name',
                                  icon: Icons.person_outline,
                                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                ),
                                SizedBox(height: 16),

                                _buildInputLabel('Middle Name (Optional)'),
                                SizedBox(height: 8),
                                _buildDarkTextField(
                                  controller: _middleNameController,
                                  hint: 'Enter your middle name',
                                  icon: Icons.person_outline,
                                ),
                                SizedBox(height: 16),

                                _buildInputLabel('Last Name'),
                                SizedBox(height: 8),
                                _buildDarkTextField(
                                  controller: _lastNameController,
                                  hint: 'Enter your last name',
                                  icon: Icons.person_outline,
                                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                ),
                                SizedBox(height: 16),

                                _buildInputLabel('Phone Number'),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    _HoverableCountryCodePicker(
                                      onChanged: (country) => setState(() => _countryCode = country.dialCode!),
                                    ),
                                    Expanded(
                                      child: _buildDarkTextField(
                                        controller: _phoneController,
                                        hint: 'Enter phone number',
                                        icon: Icons.phone_outlined,
                                        isPhone: true,
                                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                              ],

                              _buildInputLabel('Email Address'),
                              SizedBox(height: 8),
                              _buildDarkTextField(
                                controller: _emailController,
                                hint: 'name@example.com',
                                icon: Icons.email_outlined,
                                validator: _validateEmail,
                              ),
                              SizedBox(height: 16),

                              _buildInputLabel('Password'),
                              SizedBox(height: 8),
                              _buildDarkTextField(
                                controller: _passwordController,
                                hint: 'Enter your password',
                                icon: Icons.lock_outline, // Not used if suffix is present but consistent style
                                isPassword: true,
                                validator: _validatePassword,
                              ),

                              if (_isLogin) ...[
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {}, // Logic says no changes, but usually forgot password invokes something. Original code had no action for it? Check. Original had Text only maybe? No, it was just not implemented fully.
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Tr('Forgot Password?',
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],

                              SizedBox(height: 24),

                              // Primary Button
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(
                                          _isLogin ? 'Log In' : 'Register',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),

                              if (_isLogin) ...[
                                SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: borderColor)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Tr('OR CONTINUE WITH',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: borderColor)),
                                  ],
                                ),
                                SizedBox(height: 24),

                                // Pinterest-style Social Buttons
                                OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: const Color(0xFF18181B),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Using generic icon for Gmail as assets might not exist, verify later if I should use logic
                                      Icon(Icons.mail_outline, size: 20), 
                                      SizedBox(width: 12),
                                      Tr('Continue with Gmail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: const Color(0xFF18181B),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.smartphone, size: 20),
                                      SizedBox(width: 12),
                                      Tr('Continue with Mobile Number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Register' : 'Log In',
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  // Admin login link kept low profile
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                      );
                    },
                    child: Tr('Admin Login',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool isPassword = false,
    bool isPhone = false,
    String? Function(String?)? validator,
  }) {
    if (isPassword) {
      return _PasswordProtectedField(
        controller: controller,
        hint: hint,
        validator: validator,
      );
    }

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: isPhone ? TextInputType.phone : (hint.contains('@') ? TextInputType.emailAddress : TextInputType.text),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3BED)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[500], size: 20) : null,
      ),
    );
  }
}

class _PasswordProtectedField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _PasswordProtectedField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  State<_PasswordProtectedField> createState() => _PasswordProtectedFieldState();
}

class _PasswordProtectedFieldState extends State<_PasswordProtectedField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3BED)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500], size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.grey[500],
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
    );
  }
}

class _HoverableCountryCodePicker extends StatefulWidget {
  final ValueChanged<CountryCode> onChanged;
  const _HoverableCountryCodePicker({required this.onChanged});

  @override
  State<_HoverableCountryCodePicker> createState() => _HoverableCountryCodePickerState();
}

class _HoverableCountryCodePickerState extends State<_HoverableCountryCodePicker> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovering 
                ? const Color(0xFF7C3BED) 
                : const Color(0x1AFFFFFF),
          ),
        ),
        child: CountryCodePicker(
          onChanged: widget.onChanged,
          initialSelection: 'IN',
          favorite: const ['+91', 'US'],
          textStyle: const TextStyle(color: Colors.white),
          dialogTextStyle: const TextStyle(color: Colors.white),
          dialogBackgroundColor: const Color(0xFF18181B),
          searchStyle: const TextStyle(color: Colors.white),
          barrierColor: Colors.black.withOpacity(0.8),
          closeIcon: const Icon(Icons.close, color: Colors.white),
          searchDecoration: InputDecoration(
            hintText: tr('Search country'),
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white),
          ),
          showCountryOnly: false,
          showOnlyCountryWhenClosed: false,
          alignLeft: false,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
