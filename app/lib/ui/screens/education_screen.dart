import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'article_webview.dart';
import '../components/tr.dart';
import 'feed_screen.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../providers/education_provider.dart';
import '../../contracts/article.dart';
import '../../services/education_service.dart';

class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen> {
  String _selectedCategory = 'all';
  final List<String> _categories = ['all', 'alert', 'tip', 'news'];
  final _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    ref.invalidate(educationFeedProvider(_selectedCategory));
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final feedAsync = ref.watch(educationFeedProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 16),
                _buildCategoryChips(),
                const SizedBox(height: 24),
                
                // Dynamic content
                feedAsync.when(
                  loading: () => _buildLoadingState(),
                  error: (e, _) => _buildErrorState(e.toString()),
                  data: (feed) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Alert (first article)
                      if (feed.articles.isNotEmpty)
                        _buildFeaturedAlert(feed.articles.first),
                      
                      // Detooz Picks (curated)
                      if (feed.curated.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('⭐ Detooz Picks'),
                        const SizedBox(height: 12),
                        _buildHorizontalList(feed.curated),
                      ],
                      
                      // Latest Articles
                      if (feed.articles.length > 1) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle(
                          '📰 Latest Articles',
                          actionText: 'View All',
                          onAction: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FeedScreen(category: _selectedCategory)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalList(feed.articles.skip(1).take(10).toList()),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                _buildGoldenRules(),
                const SizedBox(height: 32),
                _buildQuickCheck(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr(
            'Learn to Protect Yourself',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('Search scams, tips...'),
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final labels = {
      'all': 'All',
      'alert': '🚨 Alerts',
      'tip': '💡 Tips',
      'news': '📰 News',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : const Color(0xFF18181B).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  labels[category] ?? category,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFFE5E7EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          const Tr('Failed to load content', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? actionText, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedAlert(Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          color: const Color(0xFF18181B).withOpacity(0.75),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Image
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  image: article.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(article.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                    ),
                    // Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          article.category.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    // Bookmark button
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildBookmarkButton(article),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            article.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${article.source} • ${article.readTimeMins} min read',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (article.summary != null)
                      Text(
                        article.summary!,
                        style: GoogleFonts.inter(color: const Color(0xFFD4D4D8), fontSize: 14, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _openArticle(article),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Tr('Read Full Article', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<Article> articles) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: InkWell(
              onTap: () => _openArticle(article),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      image: article.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(article.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildBookmarkButton(article, small: true),
                        ),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                article.source,
                                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                              ),
                              const Spacer(),
                              Text(
                                '${article.readTimeMins} min',
                                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookmarkButton(Article article, {bool small = false}) {
    return GestureDetector(
      onTap: () async {
        try {
          if (article.isBookmarked) {
            await ref.read(bookmarksNotifierProvider.notifier).removeBookmark(article);
          } else {
            await ref.read(bookmarksNotifierProvider.notifier).addBookmark(article);
          }
          ref.invalidate(educationFeedProvider(_selectedCategory));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
            );
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(small ? 4 : 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: article.isBookmarked ? AppColors.warning : Colors.white,
          size: small ? 16 : 20,
        ),
      ),
    );
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

  // Static sections (keeping Golden Rules and Quick Check)
  Widget _buildGoldenRules() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Golden Rules', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              children: [
                _buildRuleItem(Icons.shield, 'Never share OTPs', 'Banks will never ask for your One-Time Password.'),
                Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                _buildRuleItem(Icons.link_off, 'Verify before clicking', 'Check sender\'s address for misspellings.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.green.shade400, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tr(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 4),
                Tr(desc, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCheck() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tr('Quick Check: Bank Calls', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Tr('DO', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 8),
                      const Tr('Hang up and call the number on the back of your card.', style: TextStyle(color: Color(0xFFD4D4D8), fontSize: 13)),
                    ],
                  ),
                ),
                Container(width: 1, height: 80, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.cancel, color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        const Tr('DON\'T', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 8),
                      const Tr('Trust caller ID or press numbers to "speak to an agent".', style: TextStyle(color: Color(0xFFD4D4D8), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
