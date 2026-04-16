import 'package:flutter/material.dart';
import '../components/neo_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../components/tr.dart';
import '../providers.dart';
import '../../services/ml/sms_translator.dart';
import '../../services/ml/state_language_map.dart';
import '../components/settings_widgets.dart';

class LanguageManagerScreen extends ConsumerStatefulWidget {
  const LanguageManagerScreen({super.key});

  @override
  ConsumerState<LanguageManagerScreen> createState() =>
      _LanguageManagerScreenState();
}

class _LanguageManagerScreenState extends ConsumerState<LanguageManagerScreen> {
  final SmsTranslator _translator = SmsTranslator();
  final Map<String, _ModelStatus> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    await _translator.initialize();
    for (final code in _translator.supportedDetectionLanguages) {
      final downloaded = await _translator.isModelReady(code);
      _statuses[code] = downloaded ? _ModelStatus.downloaded : _ModelStatus.notDownloaded;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildBrutalistHeader(context, tr('Detection Language')),
              
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeroBlock(context, 
                              icon: Icons.translate, 
                              title: tr('SMS Detection'), 
                              subtitle: tr('Manage offline scam detection packs.'),
                            ),
                            const SizedBox(height: 16),
                            buildInfoBox(context, 'Download language models to enable SMS analysis on your device without an active internet connection.'),
                            const SizedBox(height: 24),

                            buildSectionLabel(context, tr('Downloaded')),
                            _buildLanguageList(downloaded: true),
                            const SizedBox(height: 32),

                            buildSectionLabel(context, tr('Available for Download')),
                            _buildLanguageList(downloaded: false),
                          ],
                        ),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageList({required bool downloaded}) {
    final items = _statuses.entries
        .where((e) => downloaded
            ? e.value == _ModelStatus.downloaded
            : e.value != _ModelStatus.downloaded)
        .toList();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.divider(context), style: BorderStyle.solid),
        ),
        child: Tr(
          downloaded ? 'No language packs installed yet' : 'All available packs are installed!',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      );
    }

    return buildSettingsCard(context, children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildLanguageTile(items[i].key, items[i].value, i == items.length - 1),
        ],
    ]);
  }

  Widget _buildLanguageTile(String code, _ModelStatus status, bool isLast) {
    final name = languageDisplayName(code);
    final isDownloaded = status == _ModelStatus.downloaded;
    
    return buildSettingsRow(context,
      leading: buildLangBadge(context, languageNativeSymbol(code), isDownloaded),
      title: name,
      titleColor: isDownloaded ? AppColors.textPrimary(context) : AppColors.textPrimary(context),
      trailing: _buildActionTrailing(code, status),
      isLast: isLast,
      onTap: isDownloaded ? null : () => _downloadModel(code),
    );
  }

  Widget _buildActionTrailing(String code, _ModelStatus status) {
    switch (status) {
      case _ModelStatus.downloaded:
        // Plain: size text + trash icon (no box)
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('30 MB'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _deleteModel(code),
            child: Icon(Icons.delete, size: 18, color: AppColors.textSecondary(context)),
          ),
        ]);
      case _ModelStatus.downloading:
        return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
      case _ModelStatus.notDownloaded:
        // Plain: size text + cloud icon (no box)
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('30 MB'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
          const SizedBox(width: 6),
          Icon(Icons.cloud_download, size: 18, color: AppColors.textSecondary(context)),
        ]);
    }
  }

  Future<void> _downloadModel(String code) async {
    final success = await showDownloadDialog(context, langCode: code, langName: languageDisplayName(code));
    if (success && mounted) {
      setState(() => _statuses[code] = _ModelStatus.downloaded);
    }
  }

  Future<void> _deleteModel(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: AppColors.divider(context), width: 2)),
        title: Tr('Delete Pack?', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 16, color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        content: Tr('This will remove the ${languageDisplayName(code)} pack. You can re-download it later.', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4)),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.background(ctx), border: Border.all(color: AppColors.divider(ctx)), borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(tr('CANCEL'), style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(ctx)))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(tr('DELETE'), style: const TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm == true) {
      await _translator.deleteModel(code);
      if (mounted) {
        setState(() => _statuses[code] = _ModelStatus.notDownloaded);
        NeoSnackBar.show(context, message: '${languageDisplayName(code)} pack removed', type: NeoSnackbarType.info, position: NeoSnackbarPosition.bottom);
      }
    }
  }
}

enum _ModelStatus { downloaded, downloading, notDownloaded }
