import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Service for connecting to Detooz Backend
/// Created by Backend Team for Stitch
class ApiService {
  // Change this to your backend URL
  // Emulator: http://10.0.2.2:8000
  // Real Device: http://<YOUR_PC_IP>:8000
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
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

  // ============ AUTH ============

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
      }),
    );
    
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['access_token'] != null) {
      await saveToken(data['access_token']);
    }
    return data;
  }

  /// Login user (returns token)
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'username=$email&password=$password',
    );
    
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['access_token'] != null) {
      await saveToken(data['access_token']);
    }
    return data;
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
    );
    
    return jsonDecode(response.body);
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
      Uri.parse('$baseUrl/sms/history?limit=$limit'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
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
      Uri.parse('$baseUrl/guardian/list'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
  }
}

/// Global API service instance
final apiService = ApiService();
