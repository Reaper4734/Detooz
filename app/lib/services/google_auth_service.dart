import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Google Sign-In Service using Firebase
/// Auto-verifies email - no OTP needed
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // ════════════════════════════════════════════════════════════════
    // IMPORTANT: This serverClientId MUST be the **Web client ID** (type 3)
    // from Firebase project detooz-4734 (project_number: 497423501955).
    // This MUST match the project used by the backend's Firebase Admin SDK.
    // ════════════════════════════════════════════════════════════════
    await _googleSignIn.initialize(
      serverClientId: '497423501955-bbt1anbjmgf1nhobj7sueaa4g8bcl1m7.apps.googleusercontent.com',
    );
    _initialized = true;
    debugPrint('GoogleAuth: Initialized with serverClientId');
  }
  
  /// Sign in with Google
  /// Returns Firebase ID token to send to backend
  Future<GoogleSignInResult> signIn() async {
    try {
      await _ensureInitialized();
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );
      
      if (googleUser == null) {
        // User cancelled
        return GoogleSignInResult(
          success: false,
          error: 'Sign-in cancelled',
        );
      }
      
      // Get auth details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // Create credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Get Firebase ID token for backend (Force refresh to avoid expiration issues)
      final idToken = await userCredential.user?.getIdToken(true);
      
      if (idToken == null) {
        return GoogleSignInResult(
          success: false,
          error: 'Failed to get authentication token',
        );
      }
      
      debugPrint('GoogleAuth: Sign-in successful for ${googleUser.email}');
      
      return GoogleSignInResult(
        success: true,
        idToken: idToken,
        email: googleUser.email,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
      );
    } catch (e, stackTrace) {
      debugPrint('GoogleAuth: Error - $e');
      debugPrint('GoogleAuth: Stack - $stackTrace');
      return GoogleSignInResult(
        success: false,
        error: _getErrorMessage(e),
      );
    }
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  
  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;
  
  /// Get current user email
  String? get currentEmail => _auth.currentUser?.email;
  
  /// Disconnect Google account (revokes access)
  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    await _auth.signOut();
  }
  
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    // Check for specific Google API error codes
    if (errorStr.contains('ApiException: 10') || errorStr.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In config error (code 10). SHA-1 fingerprint may not be registered in Firebase Console.';
    }
    if (errorStr.contains('ApiException: 12500')) {
      return 'Google Sign-In temporarily unavailable. Please update Google Play Services.';
    }
    if (errorStr.contains('ApiException: 7')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorStr.contains('network') || errorStr.contains('SocketException')) {
      return 'Network error. Please check your connection.';
    }
    if (errorStr.contains('canceled') || errorStr.contains('cancelled')) {
      return 'Sign-in cancelled';
    }
    // Show actual error for debugging
    return 'Sign-in failed: $errorStr';
  }
}

/// Result of Google Sign-In attempt
class GoogleSignInResult {
  final bool success;
  final String? idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;
  
  GoogleSignInResult({
    required this.success,
    this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });
}
