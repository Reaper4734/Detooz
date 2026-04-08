import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';
import '../components/tr.dart';

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
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendTimer = 30;
  Timer? _timer;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          setState(() => _focusedIndex = i);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var node in _focusNodes) node.dispose();
    for (var controller in _controllers) controller.dispose();
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

  String _getOtpValue() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOtpValue();

    if (otp.length != 6) {
      setState(() => _errorMessage = tr('Please enter 6-digit OTP'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onVerifyOTP(otp);

      if (success && mounted) {
        Navigator.of(context).pop(true);
        return;
      }

      if (!success && mounted) {
        setState(() => _errorMessage = tr('Invalid OTP. Please try again.'));
      }
    } catch (e) {
      if (mounted) {
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
          SnackBar(
            content: Text(tr('OTP sent successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = tr('Failed to resend OTP'));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  /// Mask identifier for privacy
  String _maskIdentifier(String identifier) {
    if (widget.isPhone) {
      if (identifier.length > 6) {
        return '${identifier.substring(0, 4)} XXXXX ${identifier.substring(identifier.length - 5)}';
      }
    } else {
      final atIndex = identifier.indexOf('@');
      if (atIndex > 3) {
        return '${identifier.substring(0, 3)}***${identifier.substring(atIndex)}';
      }
    }
    return identifier;
  }

  // ═══════════════════════════════════════════════════════
  // ─── BUILD — Neo-Brutalist UI ─────────────────────────
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      resizeToAvoidBottomInset: false,
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
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
                              child: Icon(Icons.arrow_back, color: AppColors.textPrimary(context), size: Responsive.sp(20)),
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.sp(28)),

                        // ─── Icon Box ───
                        Container(
                          width: Responsive.sp(50),
                          height: Responsive.sp(50),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                          ),
                          child: Center(
                            child: Icon(
                              widget.isPhone ? Icons.phone_android : Icons.mail_outline,
                              color: Colors.white,
                              size: Responsive.sp(28),
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.sp(28)),

                        // ─── Title ───
                        Text(
                          'VERIFICATION\nCODE',
                          style: TextStyle(
                            fontFamily: 'IntegralCF',
                            fontSize: Responsive.sp(40),
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            letterSpacing: -1,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        SizedBox(height: Responsive.sp(10)),

                        // ─── Subtitle with masked identifier ───
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: Responsive.sp(15),
                              color: AppColors.textSecondary(context),
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: tr('Enter the 6-digit code sent to\n')),
                              TextSpan(
                                text: _maskIdentifier(widget.identifier),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.sp(32)),

                        // ─── OTP Inputs ───
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final totalGaps = 5 * Responsive.sp(8);
                            final boxWidth = (constraints.maxWidth - totalGaps) / 6;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: List.generate(6, (index) {
                                return Padding(
                                  padding: EdgeInsets.only(right: index < 5 ? Responsive.sp(8) : 0),
                                  child: _buildOtpBox(context, index, boxWidth),
                                );
                              }),
                            );
                          },
                        ),

                        // ─── Error Message ───
                        if (_errorMessage != null) ...[
                          SizedBox(height: Responsive.sp(12)),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: Responsive.sp(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        SizedBox(height: Responsive.sp(32)),

                        // ─── Verify Button ───
                        GestureDetector(
                          onTap: _isLoading ? null : _verifyOTP,
                          child: Container(
                            width: double.infinity,
                            height: Responsive.h(56),
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
                                    'VERIFY',
                                    style: TextStyle(
                                      fontFamily: 'IntegralCF',
                                      fontSize: Responsive.sp(18),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.sp(20)),

                        // ─── Resend Timer / Button ───
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _resendTimer > 0
                            ? RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: Responsive.sp(14),
                                    color: AppColors.textSecondary(context),
                                  ),
                                  children: [
                                    TextSpan(text: tr("Didn't receive the code? ")),
                                    TextSpan(
                                      text: '${tr("Resend in")} ${_resendTimer}s',
                                      style: TextStyle(
                                        color: AppColors.textPrimary(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GestureDetector(
                                onTap: _isResending ? null : _resendOTP,
                                child: _isResending
                                  ? SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      tr('RESEND OTP'),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: Responsive.sp(14),
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Security Tip (fixed at bottom) ───
                Padding(
                  padding: EdgeInsets.fromLTRB(Responsive.sp(24), 0, Responsive.sp(24), Responsive.sp(24)),
                  child: Container(
                    padding: EdgeInsets.all(Responsive.sp(14)),
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      border: Border.all(color: AppColors.textPrimary(context)),
                      boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, color: AppColors.textSecondary(context), size: Responsive.sp(18)),
                        SizedBox(width: Responsive.sp(8)),
                        Expanded(
                          child: Tr(
                            'Never share your OTP with anyone. Detooz will never ask for your OTP.',
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
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── OTP BOX ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════

  Widget _buildOtpBox(BuildContext context, int index, double boxWidth) {
    final isDark = AppColors.isDark(context);
    final isCurrentlyFocused = _focusedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: isCurrentlyFocused
        ? Matrix4.translationValues(-2, -2, 0)
        : Matrix4.identity(),
      width: boxWidth,
      height: boxWidth * 1.2,
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border.all(
          color: isCurrentlyFocused ? AppColors.primary : AppColors.textPrimary(context),
        ),
        boxShadow: [
          BoxShadow(
            offset: isCurrentlyFocused ? const Offset(4, 4) : const Offset(2, 2),
            color: isCurrentlyFocused
              ? (isDark ? AppColors.primary : Colors.black)
              : Colors.black,
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 1,
          cursorColor: AppColors.primary,
          style: TextStyle(
            fontSize: Responsive.sp(22),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.only(top: 6),
            isDense: true,
          ),
          onChanged: (value) {
            if (_errorMessage != null) {
              setState(() => _errorMessage = null);
            }
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            // Auto-submit when all 6 digits entered
            if (_getOtpValue().length == 6) {
              _verifyOTP();
            }
          },
        ),
      ),
    );
  }
}
