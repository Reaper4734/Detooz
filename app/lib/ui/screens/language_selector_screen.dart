import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/translation/translation_service.dart';
import '../../services/translation/language_config.dart';
import '../../services/connectivity_service.dart';
import '../providers.dart';

/// Shows a bottom sheet with language options
/// Returns the selected language code or null if dismissed
Future<void> showLanguageSelector(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _LanguageBottomSheet(ref: ref),
  );
}

class _LanguageBottomSheet extends StatefulWidget {
  final WidgetRef ref;
  
  const _LanguageBottomSheet({required this.ref});

  @override
  State<_LanguageBottomSheet> createState() => _LanguageBottomSheetState();
}

class _LanguageBottomSheetState extends State<_LanguageBottomSheet> {
  Map<String, bool> _downloadedModels = {};
  String? _downloadingLang;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModelStatuses();
  }

  Future<void> _loadModelStatuses() async {
    final statuses = <String, bool>{};
    for (final lang in supportedLanguages) {
      statuses[lang.code] = await TranslationService().isModelDownloaded(lang.code);
    }
    if (mounted) {
      setState(() {
        _downloadedModels = statuses;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = widget.ref.watch(languageProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Zinc-900
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF3F3F46), width: 1), // Zinc-700
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Language',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),
          
          // Language list
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              : Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: supportedLanguages.length,
                    itemBuilder: (context, index) {
                      final lang = supportedLanguages[index];
                      final isDownloaded = _downloadedModels[lang.code] ?? false;
                      final isDownloading = _downloadingLang == lang.code;
                      final isSelected = currentLang == lang.code;

                      return _LanguageTile(
                        language: lang,
                        isSelected: isSelected,
                        isDownloaded: isDownloaded,
                        isDownloading: isDownloading,
                        onTap: () => _onLanguageTap(lang, isDownloaded),
                      );
                    },
                  ),
                ),
          
          // Bottom padding for safety
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Future<void> _onLanguageTap(SupportedLanguage lang, bool isDownloaded) async {
    if (_downloadingLang != null) return;

    if (lang.isEnglish) {
      await _setLanguage(lang.code);
      return;
    }

    if (!isDownloaded) {
      final isOnline = await connectivityService.hasInternet();
      
      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet. Connect to download language.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show quick confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF3F3F46)),
          ),
          title: Text(
            'Download ${lang.englishName}?',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Text(
            '~30MB download. Best on Wi-Fi.',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _downloadAndSetLanguage(lang);
      }
    } else {
      await _setLanguage(lang.code);
    }
  }

  Future<void> _downloadAndSetLanguage(SupportedLanguage lang) async {
    debugPrint('🌐 UI: _downloadAndSetLanguage called for ${lang.code}');
    setState(() => _downloadingLang = lang.code);

    try {
      debugPrint('🌐 UI: Calling TranslationService().downloadModel(${lang.code})');
      await TranslationService().downloadModel(lang.code);
      debugPrint('🌐 UI: Download completed, updating state');
      
      // Mark as downloaded and clear loading BEFORE setting language
      if (mounted) {
        setState(() {
          _downloadedModels[lang.code] = true;
          _downloadingLang = null; // Clear loading indicator
        });
      }
      
      // Now set language and close
      await _setLanguage(lang.code);
    } catch (e, stack) {
      debugPrint('🌐 UI: Download error: $e');
      debugPrint('🌐 UI: Stack: $stack');
      if (mounted) {
        setState(() => _downloadingLang = null); // Clear loading on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    // Removed finally block - loading state is now cleared explicitly above
  }

  Future<void> _setLanguage(String code) async {
    debugPrint('🌐 UI: _setLanguage called with: $code');
    
    // First set language in TranslationService (saves to SharedPreferences)
    await TranslationService().setLanguage(code);
    debugPrint('🌐 UI: TranslationService.setLanguage completed');
    
    // Update the provider state (this triggers UI rebuilds)
    await widget.ref.read(languageProvider.notifier).setLanguage(code);
    debugPrint('🌐 UI: languageProvider.setLanguage completed');
    
    // Close the bottom sheet first
    if (mounted) {
      Navigator.pop(context);
      debugPrint('🌐 UI: Navigator.pop called');
    }
    
    // Show restart required dialog (after a brief delay for navigation to complete)
    await Future.delayed(const Duration(milliseconds: 200));
    
    final langName = supportedLanguages.firstWhere((l) => l.code == code).englishName;
    
    if (mounted) {
      _showRestartDialog(langName);
    }
  }
  
  void _showRestartDialog(String langName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
            side: const BorderSide(color: Color(0xFF3F3F46)),
        ),
        icon: const Icon(Icons.refresh, color: Colors.orange, size: 48),
        title: Text(
          'Restart Required',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Language changed to $langName.\n\nPlease restart the app for all translations to take effect.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Close the app - user will need to reopen
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Restart Now', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final SupportedLanguage language;
  final bool isSelected;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDownloading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            // Native name (first letter as icon)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  language.nativeName.substring(0, 1),
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            
            // Names
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.englishName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    language.nativeName,
                    style: GoogleFonts.notoSans(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status indicator
            _buildTrailing(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing() {
    if (language.isEnglish) {
      return isSelected
          ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
          : const SizedBox(width: 24);
    }

    if (isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
      );
    }

    if (isSelected) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }

    if (isDownloaded) {
      return const Icon(Icons.download_done, color: Colors.grey, size: 22);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('30MB', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
        const SizedBox(width: 6),
        const Icon(Icons.download_outlined, color: Colors.blue, size: 22),
      ],
    );
  }
}
