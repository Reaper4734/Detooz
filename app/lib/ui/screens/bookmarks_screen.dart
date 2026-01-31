import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'article_webview.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers/education_provider.dart';
import '../../contracts/article.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Tr('My Bookmarks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Tr('Error: $e', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(bookmarksNotifierProvider.notifier).loadBookmarks(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Tr('No bookmarks yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Tr('Save articles to read later', style: TextStyle(color: Color(0xFF9CA3AF))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final article = bookmarks[index];
              return _BookmarkCard(article: article);
            },
          );
        },
      ),
    );
  }
}

class _BookmarkCard extends ConsumerWidget {
  final Article article;
  
  const _BookmarkCard({required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: InkWell(
        onTap: () => _openArticle(context, article),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                image: article.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(article.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: article.imageUrl == null
                  ? Icon(Icons.article, color: AppColors.primary.withOpacity(0.5), size: 32)
                  : null,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          article.source,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${article.readTimeMins} min',
                            style: TextStyle(color: AppColors.primary, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.bookmark_remove, color: AppColors.warning),
              onPressed: () async {
                await ref.read(bookmarksNotifierProvider.notifier).removeBookmark(article);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark removed'), backgroundColor: AppColors.success),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openArticle(BuildContext context, Article article) {
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
