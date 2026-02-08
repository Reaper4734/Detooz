/// Article model for education feed (Live Feed Architecture)
class Article {
  final String url;  // Primary identifier for bookmarks
  final String title;
  final String? summary;
  final String? imageUrl;
  final String source;
  final String category;
  final int readTimeMins;
  final DateTime? publishedAt;
  final bool isExclusive;  // True if Detooz Exclusive
  final bool isBookmarked;

  Article({
    required this.url,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.source,
    required this.category,
    required this.readTimeMins,
    this.publishedAt,
    this.isExclusive = false,
    this.isBookmarked = false,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? json['content'],  // Exclusive uses 'content'
      imageUrl: json['image_url'],
      source: json['source'] ?? 'Unknown',
      category: json['category'] ?? 'news',
      readTimeMins: json['read_time_mins'] ?? 3,
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at']) 
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null),
      isExclusive: json['is_exclusive'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
    );
  }

  /// Create from bookmark response
  factory Article.fromBookmarkJson(Map<String, dynamic> json) {
    return Article(
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      summary: null,
      imageUrl: json['image_url'],
      source: json['source'] ?? 'Unknown',
      category: 'bookmark',
      readTimeMins: 3,
      publishedAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      isExclusive: json['is_exclusive'] ?? false,
      isBookmarked: true,
    );
  }

  Article copyWith({bool? isBookmarked}) {
    return Article(
      url: url,
      title: title,
      summary: summary,
      imageUrl: imageUrl,
      source: source,
      category: category,
      readTimeMins: readTimeMins,
      publishedAt: publishedAt,
      isExclusive: isExclusive,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  Map<String, dynamic> toBookmarkJson() {
    return {
      'url': url,
      'title': title,
      'source': source,
      'image_url': imageUrl,
      'is_exclusive': isExclusive,
    };
  }
}

/// Detooz Exclusive content model
class ExclusiveArticle {
  final int id;
  final String title;
  final String content;
  final String? imageUrl;
  final String category;
  final int readTimeMins;
  final DateTime createdAt;

  ExclusiveArticle({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.category,
    required this.readTimeMins,
    required this.createdAt,
  });

  factory ExclusiveArticle.fromJson(Map<String, dynamic> json) {
    return ExclusiveArticle(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
      category: json['category'] ?? 'tip',
      readTimeMins: json['read_time_mins'] ?? 3,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  /// Convert to Article for unified display
  Article toArticle() {
    return Article(
      url: 'detooz://exclusive/$id',  // Internal URL for exclusive content
      title: title,
      summary: content,
      imageUrl: imageUrl,
      source: 'Detooz Exclusive',
      category: category,
      readTimeMins: readTimeMins,
      publishedAt: createdAt,
      isExclusive: true,
      isBookmarked: false,
    );
  }
}

/// Feed response from API
class FeedResponse {
  final List<Article> articles;
  final int total;
  final List<ExclusiveArticle> exclusive;

  FeedResponse({
    required this.articles,
    required this.total,
    required this.exclusive,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      articles: (json['articles'] as List? ?? [])
          .map((j) => Article.fromJson(j))
          .toList(),
      total: json['total'] ?? 0,
      exclusive: (json['exclusive'] as List? ?? [])
          .map((j) => ExclusiveArticle.fromJson(j))
          .toList(),
    );
  }
}
