import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:flutter/foundation.dart';

/// Thrown when a network call fails due to no internet / timeout.
/// Screens should catch this and show a friendly message instead of crashing.
class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'No internet connection. Please check your network and try again.']);
  @override
  String toString() => message;
}

/// API Service for connecting to Detooz Backend
/// Created by Backend Team for Stitch
class ApiService {
  // --------------------------------------------------------------------------
  // ENVIRONMENT TOGGLE: 
  // Set to TRUE to connect to a local running backend (e.g. localhost:8000)
  // Set to FALSE to connect to the AWS Cloud backend
  // --------------------------------------------------------------------------
  static const bool useLocalBackend = false;

  // AWS EC2 Production Backend
  static const String _prodUrl = 'http://13.235.80.86:8000/api';
  
  // Smart URL detection
  static String get baseUrl {
    if (!useLocalBackend) return _prodUrl;
    
    // Auto-detect local backend IP based on emulator/physical device
    if (kIsWeb) return 'http://localhost:8000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api'; // iOS Simulator or Desktop
  }
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;

  /// Get stored auth token
  Future<String?> get token async {
    _token ??= await _storage.read(key: 'auth_token');
    return _token;
  }

  /// Save auth token after login
  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  /// Clear token on logout
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
  }

  /// Get auth headers
  Future<Map<String, String>> _getHeaders() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// Auto-refresh token on 401
  Future<bool> _tryRefreshToken() async {
    try {
      final t = await token;
      if (t == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        debugPrint('🔄 Token refreshed successfully');
        return true;
      }
    } catch (e) {
      debugPrint('🔄 Token refresh failed: $e');
    }
    return false;
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (response.statusCode >= 400) {
      // Try to extract a user-friendly message from the response
      String userMessage;
      try {
        final body = jsonDecode(response.body);
        // FastAPI returns errors in 'detail' field
        final detail = body['detail'] ?? body['message'] ?? body['error'];
        if (detail != null && detail is String && detail.length < 200) {
          userMessage = detail;
        } else {
          userMessage = _defaultErrorMessage(response.statusCode);
        }
      } catch (_) {
        userMessage = _defaultErrorMessage(response.statusCode);
      }
      throw Exception(userMessage);
    }
    return jsonDecode(response.body);
  }

  String _defaultErrorMessage(int statusCode) {
    if (statusCode == 403) return 'You don\'t have permission to do this.';
    if (statusCode == 404) return 'The requested resource was not found.';
    if (statusCode == 409) return 'This action conflicts with existing data.';
    if (statusCode == 422) return 'Please check your input and try again.';
    if (statusCode == 429) return 'Too many requests. Please wait a moment.';
    if (statusCode >= 500) return 'Server error. Please try again later.';
    return 'Something went wrong. Please try again.';
  }

  /// Authenticated GET with auto-retry on 401
  Future<http.Response> _authGet(String path) async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 45));
      
      if (response.statusCode == 401) {
        if (await _tryRefreshToken()) {
          response = await http.get(
            Uri.parse('$baseUrl$path'),
            headers: await _getHeaders(),
          ).timeout(const Duration(seconds: 45));
        }
      }
      return response;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const OfflineException();
    }
  }

  /// Authenticated POST with auto-retry on 401
  Future<http.Response> _authPost(String path, {Object? body}) async {
    try {
      final headers = await _getHeaders();
      // Use form-urlencoded content type for string bodies (e.g., login form)
      if (body is String) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
      }
      final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
      
      var response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: encodedBody,
      ).timeout(const Duration(seconds: 45));
      
      if (response.statusCode == 401) {
        if (await _tryRefreshToken()) {
          final retryHeaders = await _getHeaders();
          if (body is String) {
            retryHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
          }
          response = await http.post(
            Uri.parse('$baseUrl$path'),
            headers: retryHeaders,
            body: encodedBody,
          ).timeout(const Duration(seconds: 45));
        }
      }
      return response;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const OfflineException();
    }
  }

  /// Authenticated POST wrapper (used for extensions like APK scanner)
  Future<http.Response> post(String path, Object? body) async {
    return _authPost(path, body: body);
  }

  /// Authenticated PUT with auto-retry on 401
  Future<http.Response> _authPut(String path, {Object? body}) async {
    try {
      var response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
        body: body is String ? body : (body != null ? jsonEncode(body) : null),
      ).timeout(const Duration(seconds: 45));
      
      if (response.statusCode == 401) {
        if (await _tryRefreshToken()) {
          response = await http.put(
            Uri.parse('$baseUrl$path'),
            headers: await _getHeaders(),
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          ).timeout(const Duration(seconds: 45));
        }
      }
      return response;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const OfflineException();
    }
  }

  /// Authenticated DELETE with auto-retry on 401
  Future<http.Response> _authDelete(String path) async {
    try {
      var response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 45));
      
      if (response.statusCode == 401) {
        if (await _tryRefreshToken()) {
          response = await http.delete(
            Uri.parse('$baseUrl$path'),
            headers: await _getHeaders(),
          ).timeout(const Duration(seconds: 45));
        }
      }
      return response;
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const OfflineException();
    }
  }

  // ============ AUTH ============

  /// Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _authGet('/auth/me');
    return _processResponse(response);
  }

  /// Update user profile (name, phone)
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? phone,
  }) async {
    final body = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
    };
    if (middleName != null && middleName.isNotEmpty) {
      body['middle_name'] = middleName;
    }
    if (phone != null) {
      body['phone'] = phone;
    }
    
    final response = await _authPut('/user/profile', body: body);
    return _processResponse(response);
  }

  /// Upload profile picture (base64-encoded)
  Future<Map<String, dynamic>> uploadProfilePicture(String base64Image) async {
    final response = await _authPost('/user/profile-picture', body: {'image_data': base64Image});
    return _processResponse(response);
  }

  /// Request forgot password OTP
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _authPost('/auth/forgot-password', body: {'email': email});
    return _processResponse(response);
  }

  /// Reset password with OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _authPost('/auth/reset-password', body: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });
    return _processResponse(response);
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    required String phone,
    String? countryCode,
    String? emailToken,
    String? phoneToken,
  }) async {
    print('Registering user: $email');
    try {
      final response = await _authPost('/auth/register', body: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'phone': phone,
          'country_code': countryCode ?? '+91',
          if (emailToken != null) 'email_verification_token': emailToken,
          if (phoneToken != null) 'firebase_phone_token': phoneToken,
        });
      
      print('Register URL: $baseUrl/auth/register');
      print('Register Response: ${response.statusCode} ${response.body}');
      
      final data = jsonDecode(response.body);
      
      // Handle error status codes
      if (response.statusCode >= 400) {
        throw Exception(data['detail'] ?? 'Registration failed (${response.statusCode})');
      }
      
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      print('Register Error: $e');
      rethrow;
    }

  }

  /// Login user (returns token)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    print('Logging in user: $email');
    try {
      final response = await _authPost('/auth/login', body: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}');
      
      print('Login URL: $baseUrl/auth/login');
      print('Login Response: ${response.statusCode} ${response.body}');
      
      final data = jsonDecode(response.body);
      
      // Handle error status codes
      if (response.statusCode >= 400) {
        throw Exception(data['detail'] ?? 'Login failed (${response.statusCode})');
      }
      
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      print('Login Error: $e');
      rethrow;
    }

  }

  /// Google Sign-In - send Firebase ID token
  Future<Map<String, dynamic>> googleSignIn({required String idToken}) async {
    print('Google Sign-In with token...');
    try {
      final response = await _authPost('/auth/google-signin', body: {'id_token': idToken});
      
      final data = jsonDecode(response.body);
      
      // Handle error status codes
      if (response.statusCode >= 400) {
        throw Exception(data['detail'] ?? 'Google Sign-In failed (${response.statusCode})');
      }
      
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }



  /// Send Email OTP for verification
  Future<Map<String, dynamic>> sendEmailOTP({required String email}) async {
    try {
      final response = await _authPost('/auth/send-email-otp', body: {'email': email});
      
      final data = jsonDecode(response.body);
      
      // Handle HTTP error status codes
      if (response.statusCode >= 400) {
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to send OTP (${response.statusCode})',
        };
      }
      
      return data;
    } catch (e) {
      print('Send Email OTP Error: $e');
      rethrow;
    }
  }

  /// Verify Email OTP (Login/Auth)
  Future<Map<String, dynamic>> verifyEmailOTP({required String email, required String otp}) async {
    try {
      final response = await _authPost('/auth/verify-email-otp', body: {'email': email, 'otp': otp});
      
      final data = jsonDecode(response.body);
      
      // Handle error status codes
      if (response.statusCode >= 400) {
        throw Exception(data['detail'] ?? 'Verification failed (${response.statusCode})');
      }
      
      // If verification returns a new token, save it
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      print('Verify Email OTP Error: $e');
      rethrow;
    }
  }

  /// Verify Email OTP Only (Registration - does not create user/token)
  /// Verify Email OTP Only (Registration - does not create user/token)
  /// Returns verification token if successful
  Future<String?> verifyEmailOnly({required String email, required String otp}) async {
    try {
      final response = await _authPost('/auth/verify-email-only', body: {'email': email, 'otp': otp});
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode >= 400) {
        throw Exception(data['message'] ?? data['detail'] ?? 'Verification failed');
      }
      
      if (data['success'] == true) {
        return data['verification_token'] as String?;
      }
      return null;
    } catch (e) {
      print('Verify Email Only Error: $e');
      rethrow;
    }
  }

  // ============ FCM TOKEN ============

  /// Register FCM token for push notifications
  Future<bool> registerFcmToken(String fcmToken) async {
    try {
      final response = await _authPost('/user/fcm-token', body: {'fcm_token': fcmToken});
      
      return response.statusCode == 200;
    } catch (e) {
      print('FCM token registration failed: $e');
      return false;
    }
  }

  /// Remove FCM token (on logout)
  Future<bool> removeFcmToken() async {
    try {
      final response = await _authDelete('/user/fcm-token');
      
      return response.statusCode == 200;
    } catch (e) {
      print('FCM token removal failed: $e');
      return false;
    }
  }

  // ============ SMS DETECTION ============

  /// Analyze SMS message for scam detection
  /// Returns: {risk_level, reason, confidence, scam_type, is_blocked, guardian_alerted}
  Future<Map<String, dynamic>> analyzeSms({
    required String sender,
    required String message,
  }) async {
    final response = await _authPost('/sms/analyze', body: {
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    
    return _processResponse(response);
  }

  /// Block a sender
  Future<bool> blockSender(String sender) async {
    final response = await _authPost('/sms/block/$sender');
    return response.statusCode == 200;
  }

  /// Get scan history
  Future<List<dynamic>> getHistory({int limit = 50}) async {
    final response = await _authGet('/scan/history?limit=$limit');
    
    final dynamic res = _processResponse(response);
    if (res is List) return res;
    if (res is Map && res.containsKey('scans')) return res['scans'] as List<dynamic>;
    return [];
  }

  // ============ GUARDIAN ============

  /// Add a guardian
  Future<Map<String, dynamic>> addGuardian({
    required String name,
    required String phone,
    String? telegramChatId,
  }) async {
    final response = await _authPost('/guardian/add', body: {
        'name': name,
        'phone': phone,
        if (telegramChatId != null) 'telegram_chat_id': telegramChatId,
      });
    return jsonDecode(response.body);
  }

  /// Get all guardians
  Future<List<dynamic>> getGuardians() async {
    final response = await _authGet('/guardian-link/my-guardians');
    final dynamic res = _processResponse(response);
    return res is List ? res : [];
  }

  /// Send alert to guardian (triggers FCM push notification)
  Future<Map<String, dynamic>> sendGuardianAlert({
    required String sender,
    required String scamType,
  }) async {
    final response = await _authPost('/guardian-alerts/send', body: {
        'sender': sender,
        'scam_type': scamType,
      });
    return _processResponse(response);
  }

  // ============ TRUSTED SENDERS ============

  /// Mark a sender as trusted
  Future<Map<String, dynamic>> markTrusted({
    required String sender,
    String? name,
    String? reason,
  }) async {
    final response = await _authPost('/trusted/add', body: {
        'sender': sender,
        if (name != null) 'name': name,
        if (reason != null) 'reason': reason,
      });
    return jsonDecode(response.body);
  }

  /// Remove trusted status from a sender
  Future<bool> removeTrusted(String sender) async {
    final response = await _authDelete('/trusted/$sender');
    return response.statusCode == 200;
  }

  /// Get list of trusted senders
  Future<List<dynamic>> getTrustedSenders() async {
    final response = await _authGet('/trusted/list');
    return jsonDecode(response.body);
  }

  /// Check if sender is trusted
  Future<Map<String, dynamic>> checkTrusted(String sender) async {
    final response = await _authGet('/trusted/check/$sender');
    return jsonDecode(response.body);
  }

  // ============ USER STATS & SETTINGS ============

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final response = await _authGet('/user/stats');
    
    print('User Stats Response: ${response.statusCode}');
    return _processResponse(response);
  }

  /// Get user settings
  Future<Map<String, dynamic>> getUserSettings() async {
    final response = await _authGet('/user/settings');
    return jsonDecode(response.body);
  }

  /// Update user settings
  Future<Map<String, dynamic>> updateUserSettings({
    String? language,
    bool? autoBlockHighRisk,
    String? alertGuardiansThreshold,
    bool? receiveTips,
  }) async {
    final response = await _authPut('/user/settings', body: {
        if (language != null) 'language': language,
        if (autoBlockHighRisk != null) 'auto_block_high_risk': autoBlockHighRisk,
        if (alertGuardiansThreshold != null) 'alert_guardians_threshold': alertGuardiansThreshold,
        if (receiveTips != null) 'receive_tips': receiveTips,
      });
    return jsonDecode(response.body);
  }

  /// Set language preference
  Future<bool> setLanguage(String lang) async {
    final response = await _authPut('/user/language/$lang');
    return response.statusCode == 200;
  }

  // ============ FEEDBACK ============

  /// Submit feedback on a scan result
  Future<Map<String, dynamic>> submitFeedback({
    required int scanId,
    required String userVerdict, // "safe", "scam", "unsure"
    String? comment,
  }) async {
    final response = await _authPost('/feedback/scan/$scanId', body: {
        'user_verdict': userVerdict,
        if (comment != null) 'comment': comment,
      });
    return jsonDecode(response.body);
  }

  /// Get user's feedback history
  Future<List<dynamic>> getMyFeedback({int limit = 50}) async {
    final response = await _authGet('/feedback/my-feedback?limit=$limit');
    return jsonDecode(response.body);
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    final response = await _authGet('/feedback/stats');
    return jsonDecode(response.body);
  }

  // ============ REPUTATION DATABASE ============

  /// Check reputation of a URL
  Future<Map<String, dynamic>> checkUrlReputation(String url) async {
    final response = await _authGet('/reputation/check?url=${Uri.encodeComponent(url)}');
    return jsonDecode(response.body);
  }

  /// Check reputation of a phone number
  Future<Map<String, dynamic>> checkPhoneReputation(String phone) async {
    final response = await _authGet('/reputation/check?phone=${Uri.encodeComponent(phone)}');
    return jsonDecode(response.body);
  }

  /// Report a scam URL/phone/domain
  Future<Map<String, dynamic>> reportScam({
    required String value,
    required String type,
    String? reason,
  }) async {
    final response = await _authPost('/reputation/report', body: {
        'value': value,
        'type': type,
        if (reason != null) 'reason': reason,
      });
    return jsonDecode(response.body);
  }

  /// Get recently reported scams
  Future<List<dynamic>> getRecentReports({int limit = 20, String? type}) async {
    String path = '/reputation/recent?limit=$limit';
    if (type != null) path += '&type=$type';
    final response = await _authGet(path);
    return jsonDecode(response.body);
  }

  // ============ MANUAL SCAN ============

  /// Unified manual scan - analyzes text, URL, or phone number
  Future<Map<String, dynamic>> manualScan({
    required String content,
    String contentType = 'auto', // "text", "url", "phone", "auto"
  }) async {
    print('Manual Scan: $content');
    final response = await _authPost('/manual/analyze', body: {
        'content': content,
        'content_type': contentType,
      });
    
    return _processResponse(response);
  }

  /// Analyze URL specifically
  Future<Map<String, dynamic>> analyzeUrl(String url) async {
    final response = await _authPost('/manual/analyze-url?url=${Uri.encodeComponent(url)}');
    return jsonDecode(response.body);
  }

  /// Analyze image for scam detection
  Future<Map<String, dynamic>> analyzeImage(XFile imageFile) async {
    print('Analyzing image: ${imageFile.path}');
    try {
      final uri = Uri.parse('$baseUrl/scan/analyze-image');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll(await _getHeaders());
      request.fields['sender'] = 'Manual Check';
      request.fields['platform'] = 'WHATSAPP';

      final extension = imageFile.name.split('.').last.toLowerCase();
      MediaType contentType;
      if (['jpg', 'jpeg'].contains(extension)) {
        contentType = MediaType('image', 'jpeg');
      } else if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (extension == 'gif') {
        contentType = MediaType('image', 'gif');
      } else if (extension == 'webp') {
        contentType = MediaType('image', 'webp');
      } else {
        contentType = MediaType('application', 'octet-stream');
      }

      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        await imageFile.readAsBytes(),
        filename: imageFile.name,
        contentType: contentType,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));
      
      print('Image Analysis Response: ${response.statusCode}');
      
      return _processResponse(response);
    } on SocketException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException('Connection timed out. Please try again.');
    } catch (e) {
      print('Image Analysis Error: $e');
      rethrow;
    }
  }

  /// Check phone number specifically
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    final response = await _authPost('/manual/check-phone?phone=${Uri.encodeComponent(phone)}');
    return jsonDecode(response.body);
  }

  /// Get "Why Should I Care?" explanation
  Future<Map<String, dynamic>> getExplanation({
    required String riskLevel,
    String? scamType,
    String language = 'en',
  }) async {
    final response = await _authPost('/manual/explain', body: {
        'risk_level': riskLevel,
        if (scamType != null) 'scam_type': scamType,
        'language': language,
      });
    return jsonDecode(response.body);
  }

  /// Get list of all known scam types
  Future<List<dynamic>> getScamTypes() async {
    final response = await _authGet('/manual/scam-types');
    return jsonDecode(response.body);
  }

  // ============ GUARDIAN ALERTS ============

  /// Get pending alerts for guardian
  Future<List<dynamic>> getGuardianAlerts() async {
    final response = await _authGet('/guardian-alerts/pending');
    
    if (response.statusCode >= 400) {
      throw Exception('Failed to get alerts: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Mark alert as seen
  Future<void> markAlertSeen(int alertId) async {
    final response = await _authPost('/guardian-alerts/$alertId/seen');
    if (response.statusCode >= 400) {
      throw Exception('Failed to mark seen: ${response.body}');
    }
  }

  /// Take action on alert
  Future<void> takeAlertAction(int alertId, String action, {String? notes}) async {
    final response = await _authPost('/guardian-alerts/$alertId/action', body: {
        'action': action,
        'notes': notes,
      });
    if (response.statusCode >= 400) {
      throw Exception('Failed to take action: ${response.body}');
    }
  }

  // ============ GUARDIAN LINKING ============

  /// Get protected users (for guardian)
  Future<List<dynamic>> getProtectedUsers() async {
    final response = await _authGet('/guardian-link/my-protected-users');
    if (response.statusCode >= 400) {
      throw Exception('Failed to get users: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Generate OTP for linking (user side)
  Future<Map<String, dynamic>> generateGuardianOtp() async {
    final response = await _authPost('/guardian-link/generate-otp');
    return _processResponse(response);
  }

  /// Verify OTP and link (guardian side)
  Future<Map<String, dynamic>> verifyGuardianOtp(String userEmail, String otp) async {
    final response = await _authPost('/guardian-link/verify-otp', body: {
        'user_email': userEmail,
        'otp_code': otp,
      });
    return _processResponse(response);
  }

  /// Get my guardians (user side)
  Future<List<dynamic>> getMyGuardians() async {
    final response = await _authGet('/guardian-link/my-guardians');
    if (response.statusCode >= 400) {
      throw Exception('Failed to get guardians: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  // ============ ADMIN DASHBOARD ============

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _authGet('/admin/stats');
    if (response.statusCode >= 400) throw Exception('Failed to load stats');
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getAdminUsers() async {
    final response = await _authGet('/admin/users');
    if (response.statusCode >= 400) throw Exception('Failed to load users');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getAdminGuardians() async {
    final response = await _authGet('/admin/guardians');
    if (response.statusCode >= 400) throw Exception('Failed to load guardians');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getAdminAlerts() async {
    final response = await _authGet('/admin/alerts');
    if (response.statusCode >= 400) throw Exception('Failed to load alerts');
    return jsonDecode(response.body);
  }

  Future<void> deleteUser(int userId) async {
    final response = await _authDelete('/admin/users/$userId');
    if (response.statusCode >= 400) throw Exception('Failed to delete user');
  }


  Future<void> updateUser(int userId, String name, String phone) async {
    final response = await _authPut('/admin/users/$userId', body: {'name': name, 'phone': phone});
    if (response.statusCode >= 400) throw Exception('Failed to update user');
  }

  Future<void> deleteGuardian(int guardianId) async {
    final response = await _authDelete('/admin/guardians/$guardianId');
    if (response.statusCode >= 400) throw Exception('Failed to delete guardian');
  }

  Future<void> deleteAlert(int alertId) async {
    final response = await _authDelete('/admin/alerts/$alertId');
    if (response.statusCode >= 400) throw Exception('Failed to delete alert');
  }

  // ============== Security & Privacy ==============

  /// Change password (requires current password for verification)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _authPost('/user/change-password', body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    
    if (response.statusCode == 400) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Invalid current password');
    }
    if (response.statusCode >= 400) {
      throw Exception('Failed to change password');
    }
  }

  /// Export all user data as formatted TXT
  Future<String> exportData() async {
    final response = await _authGet('/user/export-data');
    
    if (response.statusCode >= 400) {
      throw Exception('Failed to export data');
    }
    return response.body; // Returns plain text
  }

  /// Delete account permanently (requires password confirmation)
  Future<void> deleteAccount({required String password}) async {
    final response = await _authDelete('/user/delete-account');
    
    if (response.statusCode == 400) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Invalid password');
    }
    if (response.statusCode >= 400) {
      throw Exception('Failed to delete account');
    }
    // Clear local token after successful deletion
    await clearToken();
  }
}

/// Global API service instance
final apiService = ApiService();

