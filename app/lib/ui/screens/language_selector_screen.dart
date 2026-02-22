import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/translation/translation_service.dart';
import '../../services/translation/language_config.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../components/tr.dart';
import 'model_download_screen.dart';

/// Navigate to the language selector full screen
Future<void> showLanguageSelector(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LanguageSelectorScreen(ref: ref),
    ),
  );
}

class LanguageSelectorScreen extends StatefulWidget {
  final WidgetRef ref;

  const LanguageSelectorScreen({super.key, required this.ref});

  @override
  State<LanguageSelectorScreen> createState() => _LanguageSelectorScreenState();
}

class _LanguageSelectorScreenState extends State<LanguageSelectorScreen> {
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

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button row
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_back_ios,
                                      color: AppColors.textSecondary(context), size: 18),
                                  const SizedBox(width: 4),
                                  Text('Back',
                                      style: TextStyle(
                                          color: AppColors.textSecondary(context),
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Header icon
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.language,
                                  color: Colors.white, size: 32),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            Tr('App Language',
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 8),
                            Tr(
                              'Change the language Detooz uses for menus, buttons, and notifications. ~30 MB download required for non-English.',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 15,
                                  height: 1.5),
                            ),

                            const SizedBox(height: 16),

                            // Info card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Color(0xFF6366F1), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Tr(
                                      'Changing language requires an app restart to apply everywhere.',
                                      style: TextStyle(
                                          color: AppColors.textSecondary(context),
                                          fontSize: 13,
                                          height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Language list
                            ...supportedLanguages.map((lang) {
                              final isDownloaded =
                                  _downloadedModels[lang.code] ?? false;
                              final isDownloading =
                                  _downloadingLang == lang.code;
                              final isSelected = currentLang == lang.code;

                              return _buildLanguageTile(
                                lang: lang,
                                isSelected: isSelected,
                                isDownloaded: isDownloaded,
                                isDownloading: isDownloading,
                              );
                            }),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required SupportedLanguage lang,
    required bool isSelected,
    required bool isDownloaded,
    required bool isDownloading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isDownloading ? null : () => _onLanguageTap(lang, isDownloaded),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                : AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                  : AppColors.border(context),
            ),
          ),
          child: Row(
            children: [
              // Language icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                      : AppColors.background(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    lang.nativeName.substring(0, 1),
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : AppColors.textPrimary(context),
                      fontSize: 20,
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
                    Text(lang.englishName,
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 15,
                        )),
                    const SizedBox(height: 2),
                    Text(lang.nativeName,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13,
                        )),
                  ],
                ),
              ),

              // Status
              _buildTrailing(lang, isSelected, isDownloaded, isDownloading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(SupportedLanguage lang, bool isSelected,
      bool isDownloaded, bool isDownloading) {
    if (isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF6366F1)),
      );
    }

    if (isSelected) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF22C55E),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }

    if (lang.isEnglish) {
      return const SizedBox(width: 28);
    }

    if (isDownloaded) {
      return Icon(Icons.check_circle_outline,
          color: AppColors.textSecondary(context), size: 22);
    }

    // Not downloaded
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('30MB',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 11)),
        const SizedBox(width: 6),
        const Icon(Icons.cloud_download_outlined,
            color: Color(0xFF6366F1), size: 22),
      ],
    );
  }

  Future<void> _onLanguageTap(
      SupportedLanguage lang, bool isDownloaded) async {
    if (_downloadingLang != null) return;

    if (lang.isEnglish) {
      await _setLanguage(lang.code);
      return;
    }

    if (!isDownloaded) {
      // Navigate to download screen
      final success = await showModelDownload(
        context,
        widget.ref,
        langCode: lang.code,
        langName: lang.englishName,
      );

      if (success && mounted) {
        setState(() {
          _downloadedModels[lang.code] = true;
        });
        await _setLanguage(lang.code);
      }
    } else {
      await _setLanguage(lang.code);
    }
  }

  Future<void> _setLanguage(String code) async {
    debugPrint('🌐 UI: _setLanguage called with: $code');

    await TranslationService().setLanguage(code);
    debugPrint('🌐 UI: TranslationService.setLanguage completed');

    await widget.ref.read(languageProvider.notifier).setLanguage(code);
    debugPrint('🌐 UI: languageProvider.setLanguage completed');

    // Pop back to settings first
    if (mounted) {
      Navigator.pop(context);
      debugPrint('🌐 UI: Navigator.pop called');
    }

    // Show restart dialog after a brief delay
    await Future.delayed(const Duration(milliseconds: 200));

    final langName =
        supportedLanguages.firstWhere((l) => l.code == code).englishName;

    if (mounted) {
      _showRestartDialog(langName);
    }
  }

  void _showRestartDialog(String langName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border(ctx)),
        ),
        icon: const Icon(Icons.refresh, color: Color(0xFF6366F1), size: 48),
        title: Tr('Restart Required',
            style: TextStyle(
              color: AppColors.textPrimary(ctx),
              fontWeight: FontWeight.w600,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Tr(
              'Language changed to $langName.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary(ctx),
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Tr(
              'Please restart the app for all translations to take effect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(ctx), height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border(ctx)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Tr('Later',
                      style: TextStyle(color: AppColors.textSecondary(ctx))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    SystemNavigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Tr('Restart Now',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
