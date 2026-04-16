import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/neo_snackbar.dart';
import '../components/settings_widgets.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';
import '../providers.dart';
import 'otp_verification_screen.dart';

// ════════════════════════════════════════════════════════════════
// CHANGE EMAIL — Neo-Brutalist Design
// ════════════════════════════════════════════════════════════════

class ChangeEmailScreen extends ConsumerStatefulWidget {
  final String currentEmail;

  const ChangeEmailScreen({required this.currentEmail, super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _passwordError;
  String? _emailError;

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _passwordFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$').hasMatch(email);
  }

  bool _validate() {
    bool valid = true;

    final password = _passwordController.text.trim();
    final newEmail = _newEmailController.text.trim();

    // Password validation
    if (password.isEmpty) {
      setState(() => _passwordError = tr('Password is required'));
      valid = false;
    } else if (password.length < 6) {
      setState(() => _passwordError = tr('Password must be at least 6 characters'));
      valid = false;
    } else {
      setState(() => _passwordError = null);
    }

    // Email validation
    if (newEmail.isEmpty) {
      setState(() => _emailError = tr('Email is required'));
      valid = false;
    } else if (!_isValidEmail(newEmail)) {
      setState(() => _emailError = tr('Enter a valid email address'));
      valid = false;
    } else if (newEmail.toLowerCase() == widget.currentEmail.toLowerCase()) {
      setState(() => _emailError = tr('New email must be different'));
      valid = false;
    } else {
      setState(() => _emailError = null);
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // ── Mock: Simulate password verification delay ──
      // When backend is wired, this will call the real API:
      //   final result = await apiService.verifyPasswordAndSendEmailOTP(
      //     password: _passwordController.text.trim(),
      //     newEmail: _newEmailController.text.trim(),
      //   );
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      // Navigate to OTP verification for the new email
      final newEmail = _newEmailController.text.trim();
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            identifier: newEmail,
            isPhone: false,
            onVerifyOTP: (otp) async {
              // ── Mock: Simulate OTP verification ──
              // When backend is wired:
              //   return await apiService.verifyEmailChangeOTP(email: newEmail, otp: otp);
              await Future.delayed(const Duration(milliseconds: 800));
              return otp == '123456';
            },
            onResendOTP: () async {
              // ── Mock: Simulate resend ──
              await Future.delayed(const Duration(milliseconds: 500));
            },
          ),
        ),
      );

      if (verified == true && mounted) {
        // Refresh the user profile to show updated email
        ref.read(userProfileProvider.notifier).loadProfile();
        NeoSnackBar.show(
          context,
          message: tr('Email updated successfully!'),
          type: NeoSnackbarType.success,
          position: NeoSnackbarPosition.bottom,
        );
        Navigator.pop(context, true); // Return true to profile screen
      }
    } catch (e) {
      if (mounted) {
        NeoSnackBar.show(
          context,
          message: 'Failed: $e',
          type: NeoSnackbarType.error,
          position: NeoSnackbarPosition.bottom,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: Responsive.sp(20), vertical: Responsive.sp(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildBrutalistHeader(context, tr('Change Email')),

                    // ── Icon + Title Block ──
                    Container(
                      width: Responsive.sp(48),
                      height: Responsive.sp(48),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        boxShadow: [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
                      ),
                      child: Center(
                        child: Icon(Icons.mail_outline, color: Colors.white, size: Responsive.sp(24)),
                      ),
                    ),
                    SizedBox(height: Responsive.sp(20)),
                    Text(
                      'UPDATE YOUR\nEMAIL',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(28),
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    SizedBox(height: Responsive.sp(8)),
                    Text(
                      tr('Enter your password and new email address to continue.'),
                      style: TextStyle(
                        fontSize: Responsive.sp(14),
                        color: AppColors.textSecondary(context),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: Responsive.sp(32)),

                    // ── Password Section ──
                    buildSectionLabel(context, tr('Password')),
                    SizedBox(height: Responsive.sp(4)),
                    _buildPasswordField(),
                    if (_passwordError != null) ...[
                      SizedBox(height: Responsive.sp(6)),
                      Text(
                        _passwordError!,
                        style: TextStyle(
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    SizedBox(height: Responsive.sp(24)),

                    // ── New Email Section ──
                    buildSectionLabel(context, tr('New Email Address')),
                    SizedBox(height: Responsive.sp(4)),
                    _buildEmailField(),
                    if (_emailError != null) ...[
                      SizedBox(height: Responsive.sp(6)),
                      Text(
                        _emailError!,
                        style: TextStyle(
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    SizedBox(height: Responsive.sp(32)),

                    // ── Continue Button ──
                    GestureDetector(
                      onTap: _isSubmitting ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        height: Responsive.h(52),
                        decoration: BoxDecoration(
                          color: _isSubmitting
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : AppColors.primary,
                          boxShadow: _isSubmitting
                              ? []
                              : const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? SizedBox(
                                  width: Responsive.sp(22),
                                  height: Responsive.sp(22),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  tr('CONTINUE'),
                                  style: TextStyle(
                                    fontFamily: 'IntegralCF',
                                    fontSize: Responsive.sp(16),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.sp(24)),
                  ],
                ),
              ),
            ),

            // ── Security Tip (pinned at bottom) ──
            Padding(
              padding: EdgeInsets.fromLTRB(Responsive.sp(20), 0, Responsive.sp(20), Responsive.sp(20)),
              child: Container(
                padding: EdgeInsets.all(Responsive.sp(14)),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: Responsive.sp(18), color: AppColors.textSecondary(context)),
                    SizedBox(width: Responsive.sp(10)),
                    Expanded(
                      child: Text(
                        tr('A 6-digit verification code will be sent to your new email address.'),
                        style: TextStyle(
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── INPUT FIELDS ─────────────────────────────────────
  // ═══════════════════════════════════════════════════════

  Widget _buildPasswordField() {
    final hasError = _passwordError != null;
    return Container(
      height: Responsive.h(52),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border.all(
          color: hasError ? AppColors.danger : AppColors.divider(context),
          width: hasError ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        obscureText: _obscurePassword,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: Responsive.sp(14),
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(left: Responsive.sp(12), right: Responsive.sp(12), bottom: Responsive.sp(4)),
          border: InputBorder.none,
          isDense: true,
          hintText: tr('Enter your password'),
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.lock_outline, size: Responsive.sp(20), color: AppColors.textSecondary(context)),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: Responsive.sp(20),
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        onChanged: (_) {
          if (_passwordError != null) setState(() => _passwordError = null);
        },
        onSubmitted: (_) => _emailFocusNode.requestFocus(),
      ),
    );
  }

  Widget _buildEmailField() {
    final hasError = _emailError != null;
    return Container(
      height: Responsive.h(52),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border.all(
          color: hasError ? AppColors.danger : AppColors.divider(context),
          width: hasError ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: _newEmailController,
        focusNode: _emailFocusNode,
        keyboardType: TextInputType.emailAddress,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: Responsive.sp(14),
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(left: Responsive.sp(12), right: Responsive.sp(12), bottom: Responsive.sp(4)),
          border: InputBorder.none,
          isDense: true,
          hintText: tr('Enter new email address'),
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context).withValues(alpha: 0.5),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.mail_outline, size: Responsive.sp(20), color: AppColors.textSecondary(context)),
        ),
        onChanged: (_) {
          if (_emailError != null) setState(() => _emailError = null);
        },
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
