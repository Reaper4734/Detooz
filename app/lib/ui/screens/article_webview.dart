import 'package:flutter/material.dart';
import '../components/neo_snackbar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../components/tr.dart';
import 'main_screen.dart';
import '../../services/translation/translation_service.dart';

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

  /// Wraps the URL with Google Translate for non-English users
  String _getTranslatedUrl(String url) {
    final lang = TranslationService().currentLanguage;
    if (lang == 'en' || url.startsWith('detooz://')) return url;
    return 'https://translate.google.com/translate?sl=en&tl=$lang&u=${Uri.encodeComponent(url)}';
  }

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
      ..loadRequest(Uri.parse(_getTranslatedUrl(widget.url)));
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
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: AppColors.textPrimary(context)),
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
          title: Tr(
            widget.title,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: Icon(Icons.open_in_browser, color: AppColors.textPrimary(context)),
              onPressed: () async {
                // Open in external browser if user prefers
                final uri = Uri.parse(widget.url);
                // Using url_launcher would require import, keeping simple for now
                NeoSnackBar.show(context, message: 'URL: ${widget.url}', type: NeoSnackbarType.info, position: NeoSnackbarPosition.bottom);
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
