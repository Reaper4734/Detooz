/// Article model for education feed
class Article {
  final int id;
  final String title;
  final String? summary;
  final String? imageUrl;
  final String source;
  final String category;
  final int readTimeMins;
  final String? url;
  final DateTime? publishedAt;
  final bool isCurated;
  final bool isBookmarked;

  Article({
    required this.id,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.source,
    required this.category,
    required this.readTimeMins,
    this.url,
    this.publishedAt,
    this.isCurated = false,
    this.isBookmarked = false,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'] ?? '',
      summary: json['summary'],
      imageUrl: json['image_url'],
      source: json['source'] ?? 'Unknown',
      category: json['category'] ?? 'news',
      readTimeMins: json['read_time_mins'] ?? 3,
      url: json['url'],
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at']) 
          : null,
      isCurated: json['is_curated'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
    );
  }

  Article copyWith({bool? isBookmarked}) {
    return Article(
      id: id,
      title: title,
      summary: summary,
      imageUrl: imageUrl,
      source: source,
      category: category,
      readTimeMins: readTimeMins,
      url: url,
      publishedAt: publishedAt,
      isCurated: isCurated,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}

/// Feed response from API
class FeedResponse {
  final List<Article> articles;
  final int total;
  final List<Article> curated;

  FeedResponse({
    required this.articles,
    required this.total,
    required this.curated,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    return FeedResponse(
      articles: (json['articles'] as List? ?? [])
          .map((j) => Article.fromJson(j))
          .toList(),
      total: json['total'] ?? 0,
      curated: (json['curated'] as List? ?? [])
          .map((j) => Article.fromJson(j))
          .toList(),
    );
  }
}
