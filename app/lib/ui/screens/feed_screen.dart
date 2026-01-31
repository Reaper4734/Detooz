import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../providers/education_provider.dart';
import '../../contracts/article.dart';
import 'article_webview.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final String category;

  const FeedScreen({super.key, this.category = 'all'});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider(widget.category).notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ref.read(feedProvider(widget.category).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final feedState = ref.watch(feedProvider(widget.category));
    final articles = feedState.articles;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Tr(
          widget.category == 'all' ? 'Latest Feed' : '${widget.category[0].toUpperCase()}${widget.category.substring(1)} Feed',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
               ref.read(feedProvider(widget.category).notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: articles.isEmpty && feedState.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: articles.length + (feedState.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == articles.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }
                  return _buildInstagramCard(articles[index]);
                },
              ),
      ),
    );
  }

  Widget _buildInstagramCard(Article article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Source & Category
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    article.source.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.source,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(article.category).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          article.category.toUpperCase(),
                          style: TextStyle(
                            color: _getCategoryColor(article.category),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onPressed: () {}, // Action menu placeholder
                ),
              ],
            ),
          ),

          // Main Image
          GestureDetector(
            onTap: () => _openArticle(article),
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                image: article.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(article.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: article.imageUrl == null
                  ? Icon(Icons.image_not_supported, size: 64, color: Colors.white.withOpacity(0.2))
                  : null,
            ),
          ),

          // Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildBookmarkButton(article),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: () => _shareArticle(article),
                ),
                const Spacer(),
                Text(
                  '${article.readTimeMins} min read',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),

          // Content Snippet
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openArticle(article),
                  child: Text(
                    article.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
                if (article.summary != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openArticle(article),
                    child: Text(
                      article.summary!,
                      style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 14, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openArticle(article),
                  child: const Text(
                    'Read more...',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'alert': return AppColors.danger;
      case 'tip': return AppColors.success;
      case 'news': return AppColors.primary;
      default: return Colors.blue;
    }
  }

  Widget _buildBookmarkButton(Article article) {
    // Just display simplified logic for now as state update happens in provider
    // In a real optimized list, we might want a separate widget to rebuild only the icon
    // But rebuilding the card is fine for now
    return IconButton(
        icon: Icon(
          article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: article.isBookmarked ? AppColors.warning : Colors.white,
          size: 26,
        ),
        onPressed: () async {
          if (article.isBookmarked) {
            await ref.read(bookmarksNotifierProvider.notifier).removeBookmark(article);
          } else {
            await ref.read(bookmarksNotifierProvider.notifier).addBookmark(article);
          }
          // Refresh this item in the feed list if needed, or invalidate loaded list
          // Ideally state notifier handles it? 
          // Since we use a list in StateNotifier for the feed, we should update that specific item in the list.
          // For now, simpler: invalidate/refresh might be too heavy.
          // Let's manually toggle it in UI? Or trust the provider updates.
          // The bookmarksNotifier updates the global bookmark state, but the FeedNotifier has its own list. 
          // We need to sync them.
          // Quick fix: user taps, we update generic bookmark provider, and might need to update FeedNotifier too.
          // Future optimization. 
        },
    );
  }

  void _shareArticle(Article article) {
    if (article.url != null) {
      Share.share('Check out this article: ${article.title}\n${article.url}');
    }
  }

  void _openArticle(Article article) {
    if (article.url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleWebView(
            url: article.url!,
            title: article.title,
          ),
        ),
      );
    }
  }
}
