import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _message = 'Please enter your email'; _isError = true; });
      return;
    }
    
    setState(() { _isLoading = true; _message = null; });
    
    try {
      final result = await apiService.forgotPassword(email);
      setState(() {
        _otpSent = true;
        _message = result['message'] ?? 'OTP sent to your email';
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
      setState(() { _message = 'Please fill all fields'; _isError = true; });
      return;
    }
    
    if (password != confirm) {
      setState(() { _message = 'Passwords do not match'; _isError = true; });
      return;
    }
    
    if (password.length < 8) {
      setState(() { _message = 'Password must be at least 8 characters'; _isError = true; });
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
            content: Text(result['message'] ?? 'Password reset successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Back to login
      }
    } catch (e) {
      setState(() { _message = '$e'; _isError = true; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        ),
        title: Tr('Reset Password', style: TextStyle(
          color: AppColors.textPrimary(context),
          fontWeight: FontWeight.bold,
        )),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Icon(
              Icons.lock_reset_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            
            // Description
            Tr(
              _otpSent
                ? 'Enter the OTP sent to your email and set a new password.'
                : 'Enter your email address and we will send you an OTP to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            // Message banner
            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? AppColors.danger.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isError ? AppColors.danger : AppColors.success, width: 0.5),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(color: _isError ? AppColors.danger : AppColors.success, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Email field (always visible)
            _buildField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !_otpSent,
            ),
            const SizedBox(height: 16),
            
            if (!_otpSent) ...[
              // Send OTP button
              _buildButton('Send OTP', _sendOtp),
            ] else ...[
              // OTP field
              _buildField(
                controller: _otpController,
                label: 'Enter OTP',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // New password field
              _buildField(
                controller: _passwordController,
                label: 'New Password',
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),
              
              // Confirm password field
              _buildField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                icon: Icons.lock_outline,
                obscure: _obscureConfirm,
                toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 24),
              
              // Reset button
              _buildButton('Reset Password', _resetPassword),
              
              const SizedBox(height: 12),
              
              // Resend OTP
              TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: Tr('Resend OTP', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? toggleObscure,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      style: TextStyle(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: tr(label),
        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
        prefixIcon: Icon(icon, color: AppColors.textSecondary(context)),
        suffixIcon: toggleObscure != null
          ? IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary(context)),
              onPressed: toggleObscure,
            )
          : null,
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context).withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
          ? const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Tr(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
