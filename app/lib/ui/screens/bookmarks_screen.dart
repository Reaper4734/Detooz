import 'package:flutter/material.dart';
import '../components/neo_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'article_webview.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers/education_provider.dart';
import '../../contracts/article.dart';

import '../components/settings_widgets.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 24),
              child: buildBrutalistHeader(context, tr('My Bookmarks')),
            ),
            Expanded(
              child: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Tr('Error: $e', style: TextStyle(color: AppColors.textPrimary(context))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(bookmarksNotifierProvider.notifier).loadBookmarks(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(tr('Retry')),
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
                  Icon(Icons.bookmark_border, size: 64, color: AppColors.textSecondary(context)),
                  const SizedBox(height: 16),
                  Tr('No bookmarks yet', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Tr('Save articles to read later', style: TextStyle(color: AppColors.textSecondary(context))),
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
    ),
  ],
),
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
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppColors.cardShadow(context),
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
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                   if (article.imageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                      ),
                    ),
                  if (article.imageUrl == null)
                    Center(child: Icon(Icons.article, color: AppColors.primary.withOpacity(0.5), size: 32)),
                ],
              ),
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
                      style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          article.source,
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
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
                  NeoSnackBar.show(context, message: tr('Bookmark removed'), type: NeoSnackbarType.success, position: NeoSnackbarPosition.bottom);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openArticle(BuildContext context, Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleWebView(
          url: article.url,
          title: article.title,
        ),
      ),
    );
    }
}
