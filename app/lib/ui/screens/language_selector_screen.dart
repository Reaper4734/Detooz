import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/translation/translation_service.dart';
import '../../services/translation/language_config.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../components/tr.dart';
import 'model_download_screen.dart';
import '../components/settings_widgets.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              buildBrutalistHeader(context, 'Languages'),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeroBlock(context, 
                              icon: Icons.language, 
                              title: 'App Language', 
                              subtitle: 'Change the language Detooz uses for menus, buttons, and notifications. ~30 MB download required for non-English.',
                            ),
                            const SizedBox(height: 16),
                            buildInfoBox(context, 'Changing language requires an app restart to apply everywhere.'),
                            const SizedBox(height: 24),

                            buildSettingsCard(context, children: [
                              for (int i = 0; i < supportedLanguages.length; i++) ...[
                                Builder(builder: (context) {
                                  final lang = supportedLanguages[i];
                                  final isDownloaded = _downloadedModels[lang.code] ?? false;
                                  final isDownloading = _downloadingLang == lang.code;
                                  final isSelected = currentLang == lang.code;
                                  
                                  return buildSettingsRow(context,
                                    leading: buildLangBadge(context, lang.nativeName.substring(0, 1), isSelected),
                                    title: lang.englishName,
                                    subtitle: lang.nativeName,
                                    backgroundColor: isSelected ? const Color(0xFF7C3AED).withOpacity(0.08) : null,
                                    titleColor: isSelected ? const Color(0xFF7C3AED) : null,
                                    isLast: i == supportedLanguages.length - 1,
                                    trailing: _buildTrailing(lang, isSelected, isDownloaded, isDownloading),
                                    onTap: isDownloading ? null : () => _onLanguageTap(lang, isDownloaded),
                                  );
                                }),
                              ],
                            ]),
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

  Widget _buildTrailing(SupportedLanguage lang, bool isSelected, bool isDownloaded, bool isDownloading) {
    const primary = Color(0xFF7C3AED);
    if (isDownloading) {
      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primary));
    }
    if (isSelected) {
      return Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    }
    if (lang.isEnglish) return const SizedBox(width: 24);
    if (isDownloaded) {
      return Icon(Icons.check_circle_outline, color: AppColors.textSecondary(context), size: 20);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('30MB', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        const Icon(Icons.cloud_download_outlined, color: primary, size: 20),
      ],
    );
  }

  Future<void> _onLanguageTap(SupportedLanguage lang, bool isDownloaded) async {
    if (_downloadingLang != null) return;
    if (lang.isEnglish) {
      await _setLanguage(lang.code);
      return;
    }
    if (!isDownloaded) {
      final success = await showModelDownload(context, widget.ref, langCode: lang.code, langName: lang.englishName);
      if (success && mounted) {
        setState(() => _downloadedModels[lang.code] = true);
        await _setLanguage(lang.code);
      }
    } else {
      await _setLanguage(lang.code);
    }
  }

  Future<void> _setLanguage(String code) async {
    await TranslationService().setLanguage(code);
    await widget.ref.read(languageProvider.notifier).setLanguage(code);

    if (mounted) Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 200));

    final langName = supportedLanguages.firstWhere((l) => l.code == code).englishName;
    if (mounted) _showRestartDialog(langName);
  }

  void _showRestartDialog(String langName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: AppColors.divider(ctx), width: 2)),
        icon: const Icon(Icons.refresh, color: Color(0xFF7C3AED), size: 40),
        title: Tr('Restart Required', style: TextStyle(color: AppColors.textPrimary(ctx), fontWeight: FontWeight.w700, fontFamily: 'IntegralCF', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tr('Language changed to $langName.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Tr('Please restart the app for all translations to take effect.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(ctx), height: 1.4, fontSize: 12)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.background(ctx), border: Border.all(color: AppColors.divider(ctx)), borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(tr('LATER'), style: TextStyle(fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(ctx)))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () { Navigator.pop(ctx); SystemNavigator.pop(); },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(tr('RESTART'), style: const TextStyle(fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
