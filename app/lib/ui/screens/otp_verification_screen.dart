import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'dart:async';

/// OTP Verification Screen
/// Supports both Email OTP and Phone OTP (Firebase)
class OTPVerificationScreen extends StatefulWidget {
  final String identifier; // Email or phone number
  final bool isPhone;
  final Future<void> Function()? onResendOTP;
  final Future<bool> Function(String otp) onVerifyOTP;
  
  const OTPVerificationScreen({
    required this.identifier,
    required this.isPhone,
    required this.onVerifyOTP,
    this.onResendOTP,
    super.key,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendTimer = 30;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus on OTP input
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 30);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }
  
  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter 6-digit OTP');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await widget.onVerifyOTP(otp);
      
      if (success && mounted) {
        // Success - pop with true result
        Navigator.of(context).pop(true);
        return;
      }
      
      if (!success && mounted) {
        setState(() => _errorMessage = 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        // Clean up "Exception: " prefix if present
        String message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.substring(11);
        }
        setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _resendOTP() async {
    if (_resendTimer > 0 || widget.onResendOTP == null) return;
    
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    
    try {
      await widget.onResendOTP!();
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to resend OTP');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isPhone ? Icons.phone_android : Icons.email_outlined,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Verification Code',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Enter the 6-digit code sent to',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Identifier (email/phone)
              Text(
                _maskIdentifier(widget.identifier),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // OTP Input
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                animationType: AnimationType.fade,
                animationDuration: const Duration(milliseconds: 200),
                enableActiveFill: true,
                autoFocus: true,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: colorScheme.surface,
                  inactiveFillColor: colorScheme.surfaceContainerHighest,
                  selectedFillColor: colorScheme.primaryContainer,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.outline,
                  selectedColor: colorScheme.primary,
                  errorBorderColor: colorScheme.error,
                ),
                onCompleted: (_) => _verifyOTP(),
                onChanged: (value) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Verify button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_resendTimer > 0)
                    Text(
                      'Resend in ${_resendTimer}s',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _resendOTP,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Resend'),
                    ),
                ],
              ),
              
              const Spacer(),
              
              // Security note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Never share your OTP with anyone. Detooz will never ask for your OTP.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Mask identifier for privacy (show only first 3 and last 2 chars)
  String _maskIdentifier(String identifier) {
    if (widget.isPhone) {
      // Phone: +91 XXXXX 67890
      if (identifier.length > 6) {
        return '${identifier.substring(0, 4)} XXXXX ${identifier.substring(identifier.length - 5)}';
      }
    } else {
      // Email: tes***@gmail.com
      final atIndex = identifier.indexOf('@');
      if (atIndex > 3) {
        return '${identifier.substring(0, 3)}***${identifier.substring(atIndex)}';
      }
    }
    return identifier;
  }
}
