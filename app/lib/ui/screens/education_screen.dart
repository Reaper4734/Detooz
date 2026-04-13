import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'article_webview.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../providers/education_provider.dart';
import '../../contracts/article.dart';

class EducationScreen extends ConsumerStatefulWidget {
  const EducationScreen({super.key});

  @override
  ConsumerState<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends ConsumerState<EducationScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final feedState = ref.watch(feedProvider('all'));
    final articles = feedState.articles;

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedState.isLoading && articles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: articles.length + (feedState.hasMore ? 1 : 0),
              onPageChanged: (index) {
                if (index >= articles.length - 2 && feedState.hasMore) {
                  ref.read(feedProvider('all').notifier).loadMore();
                }
              },
              itemBuilder: (context, index) {
                if (index == articles.length) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                return _ReelItem(article: articles[index]);
              },
            ),
    );
  }
}

class _ReelItem extends ConsumerStatefulWidget {
  final Article article;

  const _ReelItem({required this.article});

  @override
  ConsumerState<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends ConsumerState<_ReelItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isPlaying = true;
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;
  late bool _isBookmarked;
  bool _isLiked = false; // Local state for likes since Article doesn't map likes yet

  // Track double tap vs triple tap
  Timer? _tapTimer;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _likeScaleAnim = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _likeAnimController, curve: Curves.elasticOut),
    );
    _isBookmarked = widget.article.isBookmarked;
    _isLiked = false;

    _initializeMedia();
  }

  void _initializeMedia() {
    if (widget.article.mediaType == 'video' && widget.article.imageUrl != null) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.article.imageUrl!),
      )..initialize().then((_) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _videoController?.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_tapCount == 1) {
        // Single tap -> Toggle Play/Pause
        if (_videoController != null && _videoController!.value.isInitialized) {
          setState(() {
            _isPlaying = !_isPlaying;
            _isPlaying ? _videoController!.play() : _videoController!.pause();
          });
        }
      } else if (_tapCount == 2) {
        // Double tap -> Like
        _handleDoubleTapLike();
      } else if (_tapCount >= 3) {
        // Triple tap -> Open Article
        _openArticle();
      }
      _tapCount = 0;
    });
  }

  void _handleDoubleTapLike() async {
    setState(() => _showLikeAnimation = true);
    _likeAnimController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _likeAnimController.reverse();
          setState(() => _showLikeAnimation = false);
        }
      });
    });

    if (!_isLiked) {
      _toggleLike();
    }
  }

  void _toggleLike() {
    setState(() => _isLiked = !_isLiked);
    // Future backend implementation for liking an article
  }

  void _toggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (_isBookmarked) {
        await ref.read(bookmarksNotifierProvider.notifier).addBookmark(widget.article);
      } else {
        await ref.read(bookmarksNotifierProvider.notifier).removeBookmark(widget.article); // Passing full Article instead of URL string
      }
      // Note: We deliberately avoid calling ref.read(feedProvider('all').notifier).refresh() 
      // because refreshing resets pagination and forces the user to the top of the feed!
    } catch (_) {
      // Revert if failed
      if (mounted) setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  void _openArticle() {
    if (widget.article.url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleWebView(
            url: widget.article.url,
            title: widget.article.title,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131A13), // Match screenshot dark olive
      body: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Safe Background
            _buildForegroundMedia(),

            // Paused Indicator Overlays
            if (!_isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
                ),
              ),

            // Like Animation
            if (_showLikeAnimation)
              Center(
                child: ScaleTransition(
                  scale: _likeScaleAnim,
                  child: const Icon(Icons.favorite, size: 100, color: Colors.red),
                ),
              ),

            // Content Overlay (Title, Actions)
            Positioned(
              left: 16,
              right: 16,
              bottom: 110, // Increased bottom clearance to avoid colliding with main navbar
              child: _buildOverlays(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForegroundMedia() {
    if (widget.article.imageUrl == null) {
      return Center(child: Icon(Icons.article, size: 100, color: Colors.white.withOpacity(0.1)));
    }

    if (widget.article.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    } else {
      return Center(
        child: CachedNetworkImage(
          imageUrl: widget.article.imageUrl!,
          fit: BoxFit.contain, // Keep ratios perfect
          placeholder: (context, url) => const CircularProgressIndicator(color: AppColors.primary),
          errorWidget: (context, url, error) {
            return Center(
              child: Icon(Icons.article, size: 100, color: Colors.white.withOpacity(0.1)),
            );
          },
        ),
      );
    }
  }

  Widget _buildOverlays() {
    String formattedDate = '';
    if (widget.article.publishedAt != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final d = widget.article.publishedAt!;
      formattedDate = '${months[d.month - 1]} ${d.day}, ${d.year}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left Side Content
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category/Source
              Text(
                widget.article.source,
                style: const TextStyle(
                  color: Color(0xFF00E5FF), // Cyan matching the screenshot
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                widget.article.title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Summary
              if (widget.article.summary != null)
                Text(
                  widget.article.summary!,
                  style: const TextStyle(
                    color: Colors.white70, 
                    fontSize: 14, 
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
              const SizedBox(height: 8),

              // Date
              if (formattedDate.isNotEmpty)
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Right Side Actions Stack
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildActionBtn(
              icon: Icons.favorite_border,
              activeIcon: Icons.favorite,
              isActive: _isLiked, // Now independent!
              activeColor: Colors.red,
              onTap: _toggleLike, // Toggles like state only
            ),
            const SizedBox(height: 24),
            _buildActionBtn(
              icon: Icons.bookmark_border,
              activeIcon: Icons.bookmark,
              isActive: _isBookmarked,
              activeColor: Colors.white,
              onTap: _toggleBookmark, 
            ),
            const SizedBox(height: 24),
            _buildActionBtn(
              icon: Icons.share,
              activeIcon: Icons.share,
              isActive: false,
              activeColor: Colors.white,
              onTap: () => Share.share('Check out: ${widget.article.title} ${widget.article.url}'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon, 
    required IconData activeIcon,
    required bool isActive,
    required Color activeColor, 
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isActive ? activeIcon : icon, 
          color: isActive ? activeColor : Colors.white, 
          size: 26,
        ),
      ),
    );
  }
}
