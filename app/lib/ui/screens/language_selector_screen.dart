import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/translation/translation_service.dart';
import '../../services/translation/language_config.dart';
import '../../services/ml/sms_translator.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../components/settings_widgets.dart';
import '../components/tr.dart';
import '../components/tr_strings.dart';
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

    final downloadedLangs = supportedLanguages.where((l) => l.isEnglish || (_downloadedModels[l.code] ?? false)).toList();
    final availableLangs = supportedLanguages.where((l) => !l.isEnglish && !(_downloadedModels[l.code] ?? false)).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              buildBrutalistHeader(context, tr('Languages')),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeroBlock(context,
                              icon: Icons.language,
                              title: tr('App Language'),
                              subtitle: tr('Manage the language Detooz uses for menus, buttons, and notifications.'),
                            ),
                            const SizedBox(height: 24),

                            // ─── Downloaded Languages ───
                            buildSectionLabel(context, tr('Downloaded')),
                            buildSettingsCard(context, children: [
                              for (int i = 0; i < downloadedLangs.length; i++)
                                Builder(builder: (context) {
                                  final lang = downloadedLangs[i];
                                  final isSelected = currentLang == lang.code;

                                  return buildSettingsRow(context,
                                    leading: buildLangBadge(context, lang.nativeName.substring(0, 1), isSelected),
                                    title: lang.englishName,
                                    subtitle: isSelected ? 'Default' : lang.nativeName,
                                    backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
                                    titleColor: isSelected ? AppColors.primary : null,
                                    isLast: i == downloadedLangs.length - 1,
                                    trailing: _buildDownloadedTrailing(lang, isSelected),
                                    onTap: () => _onLanguageTap(lang, true),
                                  );
                                }),
                            ]),
                            const SizedBox(height: 32),

                            // ─── Available for Download ───
                            buildSectionLabel(context, tr('Available for Download')),
                            if (availableLangs.isNotEmpty)
                              buildSettingsCard(context, children: [
                                for (int i = 0; i < availableLangs.length; i++)
                                  Builder(builder: (context) {
                                    final lang = availableLangs[i];
                                    return buildSettingsRow(context,
                                      leading: buildLangBadge(context, lang.nativeName.substring(0, 1), false),
                                      title: lang.englishName,
                                      titleColor: AppColors.textPrimary(context),
                                      isLast: i == availableLangs.length - 1,
                                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text(tr('30 MB'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
                                        const SizedBox(width: 6),
                                        Icon(Icons.cloud_download, size: 18, color: AppColors.textSecondary(context)),
                                      ]),
                                      onTap: () => _onLanguageTap(lang, false),
                                    );
                                  }),
                              ])
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.divider(context)),
                                ),
                                child: Text(
                                  'All available packs are installed!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
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

  /// Trailing for downloaded languages — checkmark for active, plain trash for others
  Widget _buildDownloadedTrailing(SupportedLanguage lang, bool isSelected) {
    if (isSelected) {
      return Icon(Icons.check_circle, color: AppColors.primary, size: 22);
    }
    if (lang.isEnglish) return const SizedBox(width: 22);

    // Downloaded non-active: size + delete icon (plain, no box)
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('30 MB'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () => _deleteLanguage(lang),
        child: Icon(Icons.delete, size: 18, color: AppColors.textSecondary(context)),
      ),
    ]);
  }

  Future<void> _deleteLanguage(SupportedLanguage lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: AppColors.divider(context), width: 2)),
        title: Text(tr('Delete Pack?'), style: TextStyle(fontFamily: 'IntegralCF', fontSize: 16, color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        content: Text(
          'This will remove the ${lang.englishName} language pack. You can re-download it later.',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: AppColors.background(ctx), border: Border.all(color: AppColors.divider(ctx)), borderRadius: BorderRadius.circular(4)),
                child: Center(child: Text('CANCEL', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(ctx)))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(4)),
                child: const Center(child: Text('DELETE', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            )),
          ]),
        ],
      ),
    );

    if (confirm == true) {
      await TranslationService().deleteModel(lang.code);
      if (mounted) {
        setState(() => _downloadedModels[lang.code] = false);
      }
    }
  }

  Future<void> _onLanguageTap(SupportedLanguage lang, bool isDownloaded) async {
    if (lang.isEnglish) {
      await _setLanguage(lang.code);
      return;
    }
    if (!isDownloaded) {
      // Inline download dialog
      final success = await showDownloadDialog(context, langCode: lang.code, langName: lang.englishName);
      if (success && mounted) {
        setState(() => _downloadedModels[lang.code] = true);
        await _setLanguage(lang.code);
      }
    } else {
      await _setLanguage(lang.code);
    }
  }

  Future<void> _setLanguage(String code) async {
    if (code != 'en') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) {
          final size = MediaQuery.of(ctx).size;
          return Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: size.width * 0.6,
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.05, 
                  vertical: size.height * 0.02
                ),
                decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: size.height * 0.02),
                    Text(
                      tr('Applying Language...'), 
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary(context), 
                        fontFamily: 'IntegralCF', 
                        fontSize: size.width * 0.035, // Dynamic indexing (responsive text)
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none, // Ensure no yellow lines
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    await TranslationService().setLanguage(code);
    await SmsTranslator().setUserLanguage(code);
    
    if (code != 'en') {
      await TranslationService().preloadTranslations(allAppStrings);
      if (mounted) Navigator.pop(context); // Close loading dialog
    }
    
    await widget.ref.read(languageProvider.notifier).setLanguage(code);

    if (mounted) Navigator.pop(context); // Close language selector screen completely
  }
}
