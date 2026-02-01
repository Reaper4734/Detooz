import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Google Sign-In Service using Firebase
/// Auto-verifies email - no OTP needed
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Sign in with Google
  /// Returns Firebase ID token to send to backend
  Future<GoogleSignInResult> signIn() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled
        return GoogleSignInResult(
          success: false,
          error: 'Sign-in cancelled',
        );
      }
      
      // Get auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
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
    } catch (e) {
      debugPrint('GoogleAuth: Error - $e');
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
    if (error.toString().contains('network')) {
      return 'Network error. Please check your connection.';
    }
    if (error.toString().contains('canceled')) {
      return 'Sign-in cancelled';
    }
    return 'Sign-in failed. Please try again.';
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
