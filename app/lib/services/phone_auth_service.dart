import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Phone OTP Authentication Service using Firebase Phone Auth
/// Free tier: 10,000 verifications/month
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;
  
  /// Current verification ID (needed for manual OTP verification)
  String? get verificationId => _verificationId;
  
  /// Send OTP to phone number
  /// 
  /// [phoneNumber] - Full phone number with country code (e.g., +911234567890)
  /// [onCodeSent] - Called when OTP is sent successfully
  /// [onError] - Called when an error occurs
  /// [onAutoVerify] - Called when OTP is auto-verified (Android only)
  /// [onTimeout] - Called when auto-retrieval times out
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerify,
    Function()? onTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        
        // Auto-verification (Android only - reads SMS automatically)
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('PhoneAuth: Auto-verification completed');
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          }
        },
        
        // Verification failed
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('PhoneAuth: Verification failed - ${e.code}: ${e.message}');
          String errorMessage = _getErrorMessage(e.code);
          onError(errorMessage);
        },
        
        // Code sent successfully
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('PhoneAuth: Code sent, verificationId: ${verificationId.substring(0, 10)}...');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        
        // Auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('PhoneAuth: Auto-retrieval timeout');
          _verificationId = verificationId;
          onTimeout?.call();
        },
        
        // Use resend token for subsequent requests
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      debugPrint('PhoneAuth: Exception - $e');
      onError(e.toString());
    }
  }
  
  /// Verify the OTP manually entered by user
  /// 
  /// Returns [UserCredential] on success, throws on failure
  Future<UserCredential> verifyOTP(String otp) async {
    if (_verificationId == null) {
      throw Exception('Please request OTP first');
    }
    
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    
    return await _auth.signInWithCredential(credential);
  }
  
  /// Sign in with auto-verified credential
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }
  
  /// Get Firebase ID token to send to backend for JWT exchange
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }
  
  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;
  
  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;
  
  /// Get phone number of current user
  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;
  
  /// Sign out from Firebase
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
  }
  
  /// Reset state (call before starting a new verification)
  void reset() {
    _verificationId = null;
    _resendToken = null;
  }
  
  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'session-expired':
        return 'Session expired. Please request a new OTP.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'quota-exceeded':
        return 'Service temporarily unavailable. Please try again later.';
      case 'app-not-authorized':
        return 'App not authorized. Please contact support.';
      case 'missing-phone-number':
        return 'Please enter your phone number.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
