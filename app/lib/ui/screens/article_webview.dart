import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../components/tr.dart';
import 'main_screen.dart';

/// In-app browser for reading articles
class ArticleWebView extends StatefulWidget {
  final String url;
  final String title;

  const ArticleWebView({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<ArticleWebView> createState() => _ArticleWebViewState();
}



class _ArticleWebViewState extends State<ArticleWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!_isDisposing && mounted) {
              setState(() {
                _progress = progress / 100;
                _isLoading = progress < 100;
              });
            }
          },
          onPageFinished: (String url) {
            if (!_isDisposing && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _isDisposing = true;
    try {
      // Clear webview to prevent surface crash
      _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        // Checklist 1: Internal History
        final canGoBack = await _controller.canGoBack();
        if (canGoBack) {
          await _controller.goBack();
          return;
        }

        // Checklist 2: App Navigation
        if (context.mounted) {
            if (Navigator.canPop(context)) {
                Navigator.pop(context);
            } else {
                // Fallback: Redirect to Dashboard if no history (Deep Link / Notification)
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScreen())
                );
            }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
               // Manual close button logic same as Back Button
               if (Navigator.canPop(context)) {
                 Navigator.pop(context);
               } else {
                 Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainScreen())
                 );
               }
            },
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              onPressed: () async {
                // Open in external browser if user prefers
                final uri = Uri.parse(widget.url);
                // Using url_launcher would require import, keeping simple for now
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('URL: ${widget.url}'),
                    action: SnackBarAction(label: 'Copy', onPressed: () {}),
                  ),
                );
              },
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
