import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';
import '../components/tr.dart';
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── BACKEND LOGIC ──────────────────────────────────

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _message = tr('Please enter your email'); _isError = true; });
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      final result = await apiService.forgotPassword(email);
      setState(() {
        _otpSent = true;
        _message = result['message'] ?? tr('OTP sent to your email');
        _isError = !(result['success'] ?? true);
      });
    } catch (e) {
      setState(() { _message = 'Error: $e'; _isError = true; });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (otp.isEmpty || password.isEmpty) {
      setState(() { _message = tr('Please fill all fields'); _isError = true; });
      return;
    }

    if (password != confirm) {
      setState(() { _message = tr('Passwords do not match'); _isError = true; });
      return;
    }

    if (password.length < 8) {
      setState(() { _message = tr('Password must be at least 8 characters'); _isError = true; });
      return;
    }

    setState(() { _isLoading = true; _message = null; });

    try {
      final result = await apiService.resetPassword(
        email: email,
        otp: otp,
        newPassword: password,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? tr('Password reset successfully!')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _message = '$e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.sp(24),
                          vertical: Responsive.sp(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ─── Back Button ───
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: Responsive.sp(40),
                                height: Responsive.sp(40),
                                decoration: BoxDecoration(
                                  color: AppColors.background(context),
                                  border: Border.all(color: AppColors.textPrimary(context)),
                                  boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.sp(28)),

                            // ─── Icon Box ───
                            Container(
                              width: Responsive.sp(48),
                              height: Responsive.sp(48),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                boxShadow: [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                              ),
                              child: Center(
                                child: Icon(Icons.lock_reset, color: Colors.white, size: Responsive.sp(28)),
                              ),
                            ),
                            SizedBox(height: Responsive.sp(22)),

                            // ─── Title ───
                            Text(
                              _otpSent ? 'RESET\nPASSWORD' : 'FORGOT\nPASSWORD',
                              style: TextStyle(
                                fontFamily: 'IntegralCF',
                                fontSize: Responsive.sp(36),
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                                letterSpacing: -1,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            SizedBox(height: Responsive.sp(10)),

                            // ─── Subtitle ───
                            Tr(
                              _otpSent
                                  ? 'Enter the OTP sent to your email and create a new password.'
                                  : 'Enter your email address and we will send you an OTP to reset your password.',
                              style: TextStyle(
                                fontSize: Responsive.sp(14),
                                color: AppColors.textSecondary(context),
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: Responsive.sp(32)),

                            // ─── Messages ───
                            if (_message != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _isError ? AppColors.danger : AppColors.success,
                                    width: 2,
                                  ),
                                  color: (_isError ? AppColors.danger : AppColors.success).withOpacity(0.1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isError ? Icons.error_outline : Icons.check_circle_outline,
                                      color: _isError ? AppColors.danger : AppColors.success,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _message!,
                                        style: TextStyle(
                                          color: AppColors.textPrimary(context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.sp(24)),
                            ],

                            // ─── Forms ───
                            if (!_otpSent) ...[
                              _buildLabel('EMAIL ADDRESS'),
                              _buildTextField(
                                controller: _emailController,
                                hint: 'user@protection.io',
                                isEmail: true,
                              ),
                            ] else ...[
                              _buildLabel('OTP CODE'),
                              _buildTextField(
                                controller: _otpController,
                                hint: '6-digit code',
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: Responsive.sp(20)),
                              _buildLabel('NEW PASSWORD'),
                              _buildTextField(
                                controller: _passwordController,
                                hint: 'New password',
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              SizedBox(height: Responsive.sp(20)),
                              _buildLabel('CONFIRM PASSWORD'),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                hint: 'Repeat password',
                                isPassword: true,
                                obscureText: _obscureConfirm,
                                onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ],

                            const Spacer(),

                            // ─── Submit Button ───
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : (_otpSent ? _resetPassword : _sendOtp),
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
                                          _otpSent ? 'RESET PASSWORD' : 'SEND OTP',
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── UTILS ────────────────────────────────────────────
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool isEmail = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: Responsive.h(48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider(context), width: 2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType ?? (isEmail ? TextInputType.emailAddress : TextInputType.text),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: Responsive.sp(14),
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context)
        ),
        decoration: InputDecoration(
          hintText: tr(hint),
          hintStyle: TextStyle(
            color: AppColors.textPrimary(context).withOpacity(0.4),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.sp(16),
            vertical: Responsive.sp(14),
          ),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
