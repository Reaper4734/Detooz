import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';
import 'guardians_screen.dart';
import 'admin/admin_login_screen.dart';
import 'otp_verification_screen.dart';
import '../components/tr.dart';
import '../../services/google_auth_service.dart';
import '../../services/api_service.dart';
import 'forgot_password_screen.dart';


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
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _countryCode = "+91";

  // Verification states
  bool _emailVerified = false;
  String? _emailVerificationToken;

  // Google Auth
  final GoogleAuthService _googleAuthService = GoogleAuthService();

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

  // ─── VALIDATORS ─────────────────────────────────────

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return tr('Email is required');
    final regex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!regex.hasMatch(value)) return tr('Enter a valid email address');
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return tr('Password is required');
    if (_isLogin) return null;
    if (value.length < 8) return tr('Min 8 characters');
    if (!value.contains(RegExp(r'[A-Z]'))) return tr('Must contain 1 uppercase letter');
    if (!value.contains(RegExp(r'[0-9]'))) return tr('Must contain 1 number');
    if (!value.contains(RegExp(r'[@#*&!$%^]'))) return tr('Must contain 1 special char');
    return null;
  }

  // ─── SUBMIT ─────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool success;
      if (_isLogin) {
        // ─── LOGIN FLOW ───
        success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        // ─── REGISTRATION FLOW ───
        // 1. Force Email Verification FIRST (Mandatory)
        if (_emailVerificationToken == null) {
          final isVerified = await _forceEmailVerification();
          if (!isVerified) {
            setState(() => _isLoading = false);
            return; // Abort registration, let user fix email/try again
          }
        }

        // 2. We now have the token; proceed to register the user
        success = await ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _firstNameController.text.trim(),
          _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          _lastNameController.text.trim(),
          _phoneController.text.trim(),
          countryCode: _countryCode,
          emailToken: _emailVerificationToken,
        );

        if (success && mounted) {
          setState(() => _isLoading = false);
          _showAddGuardianPrompt();
          return;
        }
      }

      setState(() => _isLoading = false);
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

  // ─── MANDATORY EMAIL VERIFICATION BEFORE REGISTRATION ──

  Future<bool> _forceEmailVerification() async {
    final email = _emailController.text.trim();

    try {
      // Send OTP automatically
      await ApiService().sendEmailOTP(email: email);
    } catch (e) {
      // Even if sending fails, still navigate to OTP screen (it has a resend button)
    }

    if (!mounted) return false;

    // Navigate to OTP screen
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(
          identifier: email,
          isPhone: false,
          onVerifyOTP: (otp) async {
            final token = await ApiService().verifyEmailOnly(email: email, otp: otp);
            if (token != null) {
              _emailVerificationToken = token;
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

    if (verified == true && mounted) {
      setState(() => _emailVerified = true);
      return true;
    } else {
      if (mounted) {
        // User tried to go back or failed — allow them to edit email
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Email verification is required to create an account.')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }
  }

  // ─── ADD GUARDIAN PROMPT (Neo-Brutalist) ─────────────

  Future<void> _showAddGuardianPrompt() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border(context), width: 2),
        ),
        title: Tr('Registration Successful',
          style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w800),
        ),
        content: Tr('Enhance your safety by adding a trusted Guardian.\n'
          'Share an OTP with them to link accounts instantly.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Tr('Later', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              boxShadow: [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardiansScreen()));
              },
              child: Tr('Add Guardian', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GOOGLE SIGN-IN ─────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _googleAuthService.signIn();

      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? tr('Google Sign-In failed')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiService().googleSignIn(idToken: result.idToken!);

      setState(() => _isLoading = false);

      if (response['access_token'] != null) {
        await ref.read(authProvider.notifier).checkAuth();
        if (response['is_new_user'] == true && mounted) {
          _showAddGuardianPrompt();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['detail'] ?? tr('Sign-In failed')),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // ─── BUILD — Neo-Brutalist UI ─────────────────────────
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          // ─── Background Decorations ───
          Positioned(
            bottom: -50, left: -50,
            child: Transform.rotate(
              angle: 45 * 3.14159 / 180,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider(context).withOpacity(0.05)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 30, right: -30,
            child: Transform.rotate(
              angle: -15 * 3.14159 / 180,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
              ),
            ),
          ),

          // ─── Main Content ───
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.sp(24),
                vertical: Responsive.sp(40),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Icon Box ───
                    Container(
                      width: Responsive.sp(44),
                      height: Responsive.sp(44),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        boxShadow: [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                      ),
                      child: Center(
                        child: Icon(Icons.security, color: Colors.white, size: Responsive.sp(26)),
                      ),
                    ),
                    SizedBox(height: Responsive.sp(22)),

                    // ─── Title ───
                    Text(
                      _isLogin ? 'WELCOME\nBACK' : 'CREATE\nACCOUNT',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(38),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: -1,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    SizedBox(height: Responsive.sp(8)),

                    // ─── Subtitle ───
                    Tr(
                      _isLogin
                        ? 'Log in to continue your\nprotection.'
                        : 'Sign up to protect your digital presence.',
                      style: TextStyle(
                        fontSize: Responsive.sp(15),
                        color: AppColors.textSecondary(context),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: Responsive.sp(28)),

                    // ─── Form Fields ───
                    if (_isLogin) ..._buildLoginForm(context)
                    else ..._buildRegisterForm(context),

                    SizedBox(height: Responsive.sp(28)),

                    // ─── Submit Button ───
                    GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        height: Responsive.h(52),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          boxShadow: [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                        ),
                        child: Center(
                          child: _isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                              )
                            : Text(
                                _isLogin ? 'LOG IN' : 'REGISTER',
                                style: TextStyle(
                                  fontFamily: 'IntegralCF',
                                  fontSize: Responsive.sp(16),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                        ),
                      ),
                    ),

                    if (_isLogin) ...[
                      SizedBox(height: Responsive.sp(28)),

                      // ─── OR Divider ───
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.divider(context))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: Responsive.sp(14)),
                            child: Tr('OR CONTINUE WITH',
                              style: TextStyle(
                                fontSize: Responsive.sp(10),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.divider(context))),
                        ],
                      ),

                      SizedBox(height: Responsive.sp(28)),

                      // ─── Google Button ───
                      GestureDetector(
                        onTap: _isLoading ? null : _handleGoogleSignIn,
                        child: Container(
                          height: Responsive.h(52),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context) ? Colors.white : Colors.black,
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(4, 4),
                                color: AppColors.isDark(context) 
                                  ? Colors.white.withOpacity(0.15) 
                                  : Colors.black,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google "G" — simple text approach to avoid painter overlap
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.isDark(context) ? Colors.black54 : Colors.white54,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.isDark(context) ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'GOOGLE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: Responsive.sp(14),
                                  color: AppColors.isDark(context) ? Colors.black : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: Responsive.sp(40)),

                    // ─── Footer Toggle ───
                    Center(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = !_isLogin;
                          _emailVerified = false;
                          _emailVerificationToken = null;
                        }),
                        child: RichText(
                          text: TextSpan(
                            text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                            style: TextStyle(
                              fontSize: Responsive.sp(13),
                              color: AppColors.textSecondary(context),
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin ? 'REGISTER' : 'LOG IN',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.sp(16)),

                    // ─── Admin Login ───
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
                        },
                        child: Tr('Admin Login',
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── FORM BUILDERS ────────────────────────────────────
  // ═══════════════════════════════════════════════════════

  List<Widget> _buildLoginForm(BuildContext context) {
    return [
      _buildLabel(tr('EMAIL ADDRESS')),
      _buildNeoTextField(
        controller: _emailController,
        hint: 'user@protection.io',
        keyboardType: TextInputType.emailAddress,
        validator: _validateEmail,
      ),
      SizedBox(height: Responsive.sp(18)),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLabel(tr('PASSWORD')),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: Text(
              tr('FORGOT PASSWORD?'),
              style: TextStyle(
                fontSize: Responsive.sp(11),
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      _NeoPasswordField(
        controller: _passwordController,
        hint: tr('Enter your password'),
        validator: _validatePassword,
      ),
    ];
  }

  List<Widget> _buildRegisterForm(BuildContext context) {
    return [
      // First & Last Name (side by side)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(tr('FIRST NAME')),
                _buildNeoTextField(
                  controller: _firstNameController,
                  hint: tr('John'),
                  validator: (v) => v?.isEmpty == true ? tr('Required') : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(tr('LAST NAME')),
                _buildNeoTextField(
                  controller: _lastNameController,
                  hint: tr('Doe'),
                  validator: (v) => v?.isEmpty == true ? tr('Required') : null,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Middle Name (optional — no validator)
      _buildLabel(tr('MIDDLE NAME (OPTIONAL)')),
      _buildNeoTextField(
        controller: _middleNameController,
        hint: tr('Enter middle name'),
      ),
      const SizedBox(height: 20),

      // Phone Number
      _buildLabel(tr('MOBILE NUMBER')),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NeoCountryCodePicker(
            onChanged: (country) => setState(() => _countryCode = country.dialCode!),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildNeoTextField(
              controller: _phoneController,
              hint: tr('Enter phone number'),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty == true ? tr('Required') : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Email (NO send code button)
      _buildLabel(tr('EMAIL ADDRESS')),
      _buildNeoTextField(
        controller: _emailController,
        hint: 'name@example.com',
        keyboardType: TextInputType.emailAddress,
        validator: _validateEmail,
      ),
      const SizedBox(height: 20),

      // Password
      _buildLabel(tr('PASSWORD')),
      _NeoPasswordField(
        controller: _passwordController,
        hint: tr('Create a password'),
        validator: _validatePassword,
      ),
    ];
  }

  // ═══════════════════════════════════════════════════════
  // ─── UI HELPERS ───────────────────────────────────────
  // ═══════════════════════════════════════════════════════

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.sp(8)),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: Responsive.sp(11),
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  /// Neo-Brutalist text field with error messages displayed BELOW the input
  Widget _buildNeoTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Per-field only
      style: TextStyle(
        fontSize: Responsive.sp(14),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary(context),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textPrimary(context).withOpacity(0.4)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Responsive.sp(16),
          vertical: Responsive.sp(14),
        ),
        // Neo-Brutalist: sharp corners, thick borders
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider(context), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider(context), width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider(context).withOpacity(0.5), width: 2),
        ),
        errorStyle: TextStyle(
          color: AppColors.danger,
          fontSize: Responsive.sp(11),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════
// ─── NEO-BRUTALIST PASSWORD FIELD ─────────────────────
// ═══════════════════════════════════════════════════════

class _NeoPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _NeoPasswordField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  State<_NeoPasswordField> createState() => _NeoPasswordFieldState();
}

class _NeoPasswordFieldState extends State<_NeoPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(
        fontSize: Responsive.sp(14),
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary(context),
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: AppColors.textPrimary(context).withOpacity(0.4)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: Responsive.sp(16),
          vertical: Responsive.sp(14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider(context), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider(context), width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        errorStyle: TextStyle(
          color: AppColors.danger,
          fontSize: Responsive.sp(11),
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscureText = !_obscureText),
          child: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textSecondary(context),
            size: 20,
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════
// ─── NEO-BRUTALIST COUNTRY CODE PICKER ────────────────
// ═══════════════════════════════════════════════════════

class _NeoCountryCodePicker extends StatefulWidget {
  final ValueChanged<CountryCode> onChanged;
  const _NeoCountryCodePicker({required this.onChanged});

  @override
  State<_NeoCountryCodePicker> createState() => _NeoCountryCodePickerState();
}

class _NeoCountryCodePickerState extends State<_NeoCountryCodePicker> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        height: Responsive.h(52),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isHovering ? AppColors.primary : AppColors.divider(context),
            width: 2,
          ),
        ),
        child: CountryCodePicker(
          onChanged: widget.onChanged,
          initialSelection: 'IN',
          favorite: const ['+91', 'US'],
          textStyle: TextStyle(color: AppColors.textPrimary(context)),
          dialogTextStyle: TextStyle(color: AppColors.textPrimary(context)),
          dialogBackgroundColor: AppColors.surfaceDark,
          searchStyle: TextStyle(color: AppColors.textPrimary(context)),
          barrierColor: Colors.black.withOpacity(0.8),
          closeIcon: Icon(Icons.close, color: AppColors.textPrimary(context)),
          searchDecoration: InputDecoration(
            hintText: tr('Search country'),
            hintStyle: TextStyle(color: AppColors.textSecondary(context)),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.divider(context), width: 2),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.search, color: AppColors.textPrimary(context)),
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
