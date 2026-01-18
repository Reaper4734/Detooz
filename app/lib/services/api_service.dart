import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

/// API Service for connecting to Detooz Backend
/// Created by Backend Team for Stitch
class ApiService {
  // Smart URL detection
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000/api';
    // Android Emulator requires special IP
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    // iOS and Desktop (Windows/Mac) use localhost
    return 'http://127.0.0.1:8000/api';
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

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }
    if (response.statusCode >= 400) {
      throw Exception('API Error: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body);
  }

  // ============ AUTH ============

  /// Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 45));
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
  }) async {
    print('Registering user: $email');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'phone': phone,
          'country_code': countryCode ?? '+91',
        }),
      ).timeout(const Duration(seconds: 45));
      
      print('Register URL: $baseUrl/auth/register');
      print('Register Response: ${response.statusCode} ${response.body}');
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['access_token'] != null) {
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
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      ).timeout(const Duration(seconds: 45));
      
      print('Login URL: $baseUrl/auth/login');
      print('Login Response: ${response.statusCode} ${response.body}');
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      print('Login Error: $e');
      rethrow;
    }

  }

  // ============ SMS DETECTION ============

  /// Analyze SMS message for scam detection
  /// Returns: {risk_level, reason, confidence, scam_type, is_blocked, guardian_alerted}
  Future<Map<String, dynamic>> analyzeSms({
    required String sender,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sms/analyze'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'sender': sender,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 30));
    
    return _processResponse(response);
  }

  /// Block a sender
  Future<bool> blockSender(String sender) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sms/block/$sender'),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  /// Get scan history
  Future<List<dynamic>> getHistory({int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/scan/history?limit=$limit'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));
    
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
    final response = await http.post(
      Uri.parse('$baseUrl/guardian/add'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        if (telegramChatId != null) 'telegram_chat_id': telegramChatId,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Get all guardians
  Future<List<dynamic>> getGuardians() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guardian-link/my-guardians'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));
    final dynamic res = _processResponse(response);
    return res is List ? res : [];
  }

  // ============ TRUSTED SENDERS ============

  /// Mark a sender as trusted
  Future<Map<String, dynamic>> markTrusted({
    required String sender,
    String? name,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trusted/add'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'sender': sender,
        if (name != null) 'name': name,
        if (reason != null) 'reason': reason,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Remove trusted status from a sender
  Future<bool> removeTrusted(String sender) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/trusted/$sender'),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  /// Get list of trusted senders
  Future<List<dynamic>> getTrustedSenders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trusted/list'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Check if sender is trusted
  Future<Map<String, dynamic>> checkTrusted(String sender) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trusted/check/$sender'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ============ USER STATS & SETTINGS ============

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/stats'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));
    
    print('User Stats Response: ${response.statusCode}');
    return _processResponse(response);
  }

  /// Get user settings
  Future<Map<String, dynamic>> getUserSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/settings'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Update user settings
  Future<Map<String, dynamic>> updateUserSettings({
    String? language,
    bool? autoBlockHighRisk,
    String? alertGuardiansThreshold,
    bool? receiveTips,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/settings'),
      headers: await _getHeaders(),
      body: jsonEncode({
        if (language != null) 'language': language,
        if (autoBlockHighRisk != null) 'auto_block_high_risk': autoBlockHighRisk,
        if (alertGuardiansThreshold != null) 'alert_guardians_threshold': alertGuardiansThreshold,
        if (receiveTips != null) 'receive_tips': receiveTips,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Set language preference
  Future<bool> setLanguage(String lang) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user/language/$lang'),
      headers: await _getHeaders(),
    );
    return response.statusCode == 200;
  }

  // ============ FEEDBACK ============

  /// Submit feedback on a scan result
  Future<Map<String, dynamic>> submitFeedback({
    required int scanId,
    required String userVerdict, // "safe", "scam", "unsure"
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/feedback/scan/$scanId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'user_verdict': userVerdict,
        if (comment != null) 'comment': comment,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Get user's feedback history
  Future<List<dynamic>> getMyFeedback({int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/feedback/my-feedback?limit=$limit'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/feedback/stats'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ============ REPUTATION DATABASE ============

  /// Check reputation of a URL
  Future<Map<String, dynamic>> checkUrlReputation(String url) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reputation/check?url=${Uri.encodeComponent(url)}'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Check reputation of a phone number
  Future<Map<String, dynamic>> checkPhoneReputation(String phone) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reputation/check?phone=${Uri.encodeComponent(phone)}'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Report a scam URL/phone/domain
  Future<Map<String, dynamic>> reportScam({
    required String value,
    required String type, // "url", "phone", "domain"
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reputation/report'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'value': value,
        'type': type,
        if (reason != null) 'reason': reason,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Get recently reported scams
  Future<List<dynamic>> getRecentReports({int limit = 20, String? type}) async {
    String url = '$baseUrl/reputation/recent?limit=$limit';
    if (type != null) url += '&type=$type';
    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ============ MANUAL SCAN ============

  /// Unified manual scan - analyzes text, URL, or phone number
  Future<Map<String, dynamic>> manualScan({
    required String content,
    String contentType = 'auto', // "text", "url", "phone", "auto"
  }) async {
    print('Manual Scan: $content');
    final response = await http.post(
      Uri.parse('$baseUrl/manual/analyze'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'content_type': contentType,
      }),
    ).timeout(const Duration(seconds: 45));
    
    return _processResponse(response);
  }

  /// Analyze URL specifically
  Future<Map<String, dynamic>> analyzeUrl(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/manual/analyze-url?url=${Uri.encodeComponent(url)}'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Analyze image for scam detection
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    print('Analyzing image: ${imageFile.path}');
    try {
      final uri = Uri.parse('$baseUrl/scan/analyze-image');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll(await _getHeaders());
      request.fields['sender'] = 'Manual Check';
      request.fields['platform'] = 'WHATSAPP';

      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        imageFile.path,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 60));
      
      print('Image Analysis Response: ${response.statusCode}');
      
      return _processResponse(response);
    } catch (e) {
      print('Image Analysis Error: $e');
      rethrow;
    }
  }

  /// Check phone number specifically
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/manual/check-phone?phone=${Uri.encodeComponent(phone)}'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  /// Get "Why Should I Care?" explanation
  Future<Map<String, dynamic>> getExplanation({
    required String riskLevel,
    String? scamType,
    String language = 'en',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/manual/explain'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'risk_level': riskLevel,
        if (scamType != null) 'scam_type': scamType,
        'language': language,
      }),
    );
    return jsonDecode(response.body);
  }

  /// Get list of all known scam types
  Future<List<dynamic>> getScamTypes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/manual/scam-types'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ============ GUARDIAN ALERTS ============

  /// Get pending alerts for guardian
  Future<List<dynamic>> getGuardianAlerts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guardian-alerts/pending'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode >= 400) {
      throw Exception('Failed to get alerts: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Mark alert as seen
  Future<void> markAlertSeen(int alertId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/guardian-alerts/$alertId/seen'),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to mark seen: ${response.body}');
    }
  }

  /// Take action on alert
  Future<void> takeAlertAction(int alertId, String action, {String? notes}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/guardian-alerts/$alertId/action'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': action,
        'notes': notes,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to take action: ${response.body}');
    }
  }

  // ============ GUARDIAN LINKING ============

  /// Get protected users (for guardian)
  Future<List<dynamic>> getProtectedUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guardian-link/my-protected-users'),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to get users: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  /// Generate OTP for linking (user side)
  Future<Map<String, dynamic>> generateGuardianOtp() async {
    final response = await http.post(
      Uri.parse('$baseUrl/guardian-link/generate-otp'),
      headers: await _getHeaders(),
    );
    return _processResponse(response);
  }

  /// Verify OTP and link (guardian side)
  Future<Map<String, dynamic>> verifyGuardianOtp(String userEmail, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/guardian-link/verify-otp'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'user_email': userEmail,
        'otp_code': otp,
      }),
    );
    return _processResponse(response);
  }

  /// Get my guardians (user side)
  Future<List<dynamic>> getMyGuardians() async {
    final response = await http.get(
      Uri.parse('$baseUrl/guardian-link/my-guardians'),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to get guardians: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  // ============ ADMIN DASHBOARD ============

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/stats'));
    if (response.statusCode >= 400) throw Exception('Failed to load stats');
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getAdminUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/users'));
    if (response.statusCode >= 400) throw Exception('Failed to load users');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getAdminGuardians() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/guardians'));
    if (response.statusCode >= 400) throw Exception('Failed to load guardians');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getAdminAlerts() async {
    final response = await http.get(Uri.parse('$baseUrl/admin/alerts'));
    if (response.statusCode >= 400) throw Exception('Failed to load alerts');
    return jsonDecode(response.body);
  }

  Future<void> deleteUser(int userId) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/users/$userId'));
    if (response.statusCode >= 400) throw Exception('Failed to delete user');
  }


  Future<void> updateUser(int userId, String name, String phone) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    if (response.statusCode >= 400) throw Exception('Failed to update user');
  }

  Future<void> deleteGuardian(int guardianId) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/guardians/$guardianId'));
    if (response.statusCode >= 400) throw Exception('Failed to delete guardian');
  }

  Future<void> deleteAlert(int alertId) async {
    final response = await http.delete(Uri.parse('$baseUrl/admin/alerts/$alertId'));
    if (response.statusCode >= 400) throw Exception('Failed to delete alert');
  }
}

/// Global API service instance
final apiService = ApiService();

