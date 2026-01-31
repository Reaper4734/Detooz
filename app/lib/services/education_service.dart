import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../contracts/article.dart';
import 'api_service.dart';

/// Service for education feed API calls
class EducationService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get educational feed articles
  Future<FeedResponse> getFeed({
    String category = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/education/feed?category=$category&limit=$limit&offset=$offset'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Failed to load feed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return FeedResponse.fromJson(data);
  }

  /// Get user's bookmarked articles
  Future<List<Article>> getBookmarks() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/education/bookmarks'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Failed to load bookmarks: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> bookmarks = data['bookmarks'] ?? [];
    return bookmarks.map((j) => Article.fromJson(j)).toList();
  }

  /// Add a bookmark
  Future<void> addBookmark(int articleId, {bool isCurated = false}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/education/bookmark'),
      headers: headers,
      body: jsonEncode({
        'article_id': articleId,
        'is_curated': isCurated,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception('Failed to bookmark: ${response.statusCode}');
    }
  }

  /// Remove a bookmark
  Future<void> removeBookmark(int articleId, {bool isCurated = false}) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/education/bookmark/$articleId?is_curated=$isCurated'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception('Failed to remove bookmark: ${response.statusCode}');
    }
  }

  /// Manually sync feeds (debug/admin)
  Future<int> syncFeeds() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/education/sync-feeds'),
      headers: headers,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception('Failed to sync feeds: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['articles_added'] ?? 0;
  }
}

/// Singleton instance
final educationService = EducationService();
