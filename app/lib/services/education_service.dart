import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../contracts/article.dart';
import 'api_service.dart';

/// Service for education feed API calls (Live Feed Architecture)
class EducationService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get educational feed articles (LIVE from RSS with caching)
  Future<FeedResponse> getFeed({
    String category = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _getHeaders();
    final url = '${ApiService.baseUrl}/education/feed?category=$category&limit=$limit&offset=$offset';
    print('DEBUG: Fetching feed from: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      
      if (response.statusCode >= 400) {
        throw Exception('Failed to load feed: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      print('DEBUG: Parsed JSON keys: ${data.keys}');
      return FeedResponse.fromJson(data);
    } catch (e, stackTrace) {
      print('DEBUG: Feed error: $e');
      print('DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get user's bookmarked articles (URL-based, never expires)
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
    return bookmarks.map((j) => Article.fromBookmarkJson(j)).toList();
  }

  /// Add a bookmark (URL-based)
  Future<void> addBookmark(Article article) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/education/bookmark'),
      headers: headers,
      body: jsonEncode(article.toBookmarkJson()),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception('Failed to bookmark: ${response.statusCode}');
    }
  }

  /// Remove a bookmark by URL
  Future<void> removeBookmark(String url) async {
    final headers = await _getHeaders();
    final encodedUrl = Uri.encodeComponent(url);
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/education/bookmark?url=$encodedUrl'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 400) {
      throw Exception('Failed to remove bookmark: ${response.statusCode}');
    }
  }

  /// Get Detooz Exclusive content
  Future<List<ExclusiveArticle>> getExclusive({int limit = 10}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/education/exclusive?limit=$limit'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Failed to load exclusive: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> articles = data['exclusive'] ?? [];
    return articles.map((j) => ExclusiveArticle.fromJson(j)).toList();
  }

  /// Generate new Detooz Exclusive content (Admin)
  Future<ExclusiveArticle?> generateExclusive() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/education/generate-exclusive'),
      headers: headers,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode >= 400) {
      throw Exception('Failed to generate exclusive: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['exclusive'] != null) {
      return ExclusiveArticle.fromJson(data['exclusive']);
    }
    return null;
  }

  /// Force refresh RSS feed cache (debug)
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
    return data['articles_cached'] ?? 0;
  }
}

/// Singleton instance
final educationService = EducationService();
