import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/article.dart';
import '../../services/education_service.dart';

/// Provider for main education dashboard (non-paginated, initial load)
final educationFeedProvider = FutureProvider.family<FeedResponse, String>((ref, category) async {
  return await educationService.getFeed(category: category);
});

/// State for infinite scroll feed
class FeedState {
  final List<Article> articles;
  final bool isLoading;
  final bool hasMore;
  final int offset;

  const FeedState({
    required this.articles,
    required this.isLoading,
    required this.hasMore,
    required this.offset,
  });

  factory FeedState.initial() => const FeedState(
        articles: [],
        isLoading: false,
        hasMore: true,
        offset: 0,
      );

  FeedState copyWith({
    List<Article>? articles,
    bool? isLoading,
    bool? hasMore,
    int? offset,
  }) {
    return FeedState(
      articles: articles ?? this.articles,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }
}

/// Notifier for infinite scroll feed
class FeedNotifier extends StateNotifier<FeedState> {
  final String category;
  
  FeedNotifier(this.category) : super(FeedState.initial()) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await educationService.getFeed(
        category: category,
        offset: state.offset,
        limit: 10,
      );

      // Combine articles: first curated (if strictly separate logic needed, handle here) 
      // but education_service returns FeedResponse with separated lists.
      // For infinite feed, we will merge them or primarily show feed articles.
      // Let's assume we interleave or just show feed articles for now, 
      // as curated are usually featured at top.
      // Actually, let's just use the articles list for the infinite feed.
      
      final newArticles = response.articles;
      
      state = state.copyWith(
        articles: [...state.articles, ...newArticles],
        isLoading: false,
        hasMore: newArticles.length >= 10, // If less than limit, no more
        offset: state.offset + newArticles.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      // Handle error cleanly?
    }
  }

  Future<void> refresh() async {
    state = FeedState.initial();
    await loadMore();
  }
}

/// Provider for infinite scroll feed
final feedProvider = StateNotifierProvider.family<FeedNotifier, FeedState, String>((ref, category) {
  return FeedNotifier(category);
});

/// Provider for user bookmarks
final bookmarksProvider = FutureProvider<List<Article>>((ref) async {
  return await educationService.getBookmarks();
});

/// Notifier for managing bookmarks state
class BookmarksNotifier extends StateNotifier<AsyncValue<List<Article>>> {
  BookmarksNotifier() : super(const AsyncValue.loading()) {
    loadBookmarks();
  }

  Future<void> loadBookmarks() async {
    state = const AsyncValue.loading();
    try {
      final bookmarks = await educationService.getBookmarks();
      state = AsyncValue.data(bookmarks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBookmark(Article article) async {
    try {
      await educationService.addBookmark(article.id, isCurated: article.isCurated);
      state.whenData((bookmarks) {
        state = AsyncValue.data([article.copyWith(isBookmarked: true), ...bookmarks]);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeBookmark(Article article) async {
    try {
      await educationService.removeBookmark(article.id, isCurated: article.isCurated);
      state.whenData((bookmarks) {
        state = AsyncValue.data(bookmarks.where((b) => b.id != article.id || b.isCurated != article.isCurated).toList());
      });
    } catch (e) {
      rethrow;
    }
  }
}

final bookmarksNotifierProvider = StateNotifierProvider<BookmarksNotifier, AsyncValue<List<Article>>>((ref) {
  return BookmarksNotifier();
});
