/// Language Manager Screen — View, download, and delete offline language packs.
///
/// Accessible from Settings. Shows installed language models and allows
/// users to download additional ones for offline scam detection.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../components/tr.dart';
import '../providers.dart';
import '../../services/ml/sms_translator.dart';
import '../../services/ml/state_language_map.dart';
import 'model_download_screen.dart';

class LanguageManagerScreen extends ConsumerStatefulWidget {
  const LanguageManagerScreen({super.key});

  @override
  ConsumerState<LanguageManagerScreen> createState() =>
      _LanguageManagerScreenState();
}

class _LanguageManagerScreenState extends ConsumerState<LanguageManagerScreen> {
  final SmsTranslator _translator = SmsTranslator();

  /// Map of language code → download status
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
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Tr('SMS Detection Language',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Installed models
                  _buildSectionTitle('Installed'),
                  _buildLanguageList(downloaded: true),
                  const SizedBox(height: 24),

                  // Available models
                  _buildSectionTitle('Available to Download'),
                  _buildLanguageList(downloaded: false),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Tr(
              'These language packs allow Detooz to detect scams in your local language, even offline. All processing stays on your device.',
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tr(title,
          style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildLanguageList({required bool downloaded}) {
    final items = _statuses.entries
        .where((e) => downloaded
            ? e.value == _ModelStatus.downloaded
            : e.value != _ModelStatus.downloaded) // Show both 'notDownloaded' AND 'downloading'
        .toList();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        width: double.infinity,
        child: Tr(
          downloaded ? 'No language packs installed yet' : 'All available packs are installed!',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildLanguageTile(items[i].key, items[i].value),
            if (i < items.length - 1)
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.border(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageTile(String code, _ModelStatus status) {
    final name = languageDisplayName(code);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: status == _ModelStatus.downloaded
              ? const Color(0xFF22C55E).withValues(alpha: 0.15)
              : const Color(0xFF6366F1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            code.toUpperCase(),
            style: TextStyle(
              color: status == _ModelStatus.downloaded
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      title: Text(name,
          style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w500)),
      subtitle: Text(
        status == _ModelStatus.downloaded ? 'Installed (~30 MB)' : '~30 MB download',
        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
      ),
      trailing: _buildActionButton(code, status),
    );
  }

  Widget _buildActionButton(String code, _ModelStatus status) {
    switch (status) {
      case _ModelStatus.downloaded:
        return IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
          onPressed: () => _deleteModel(code),
          tooltip: tr('Delete'),
        );
      case _ModelStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
        );
      case _ModelStatus.notDownloaded:
        return IconButton(
          icon: const Icon(Icons.cloud_download_outlined, color: Color(0xFF6366F1)),
          onPressed: () => _downloadModel(code),
          tooltip: tr('Download'),
        );
    }
  }

  Future<void> _downloadModel(String code) async {
    final success = await showModelDownload(
      context,
      ref,
      langCode: code,
      langName: languageDisplayName(code),
    );

    if (success && mounted) {
      setState(() => _statuses[code] = _ModelStatus.downloaded);
    }
  }

  Future<void> _deleteModel(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Tr('Delete Language Pack?',
            style: TextStyle(color: AppColors.textPrimary(context))),
        content: Tr(
            'This will remove the ${languageDisplayName(code)} pack. You can re-download it later.',
            style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Tr('Cancel',
                style: const TextStyle(color: Color(0xFFA1A1AA))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Tr('Delete',
                style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _translator.deleteModel(code);
      if (mounted) {
        setState(() => _statuses[code] = _ModelStatus.notDownloaded);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${languageDisplayName(code)} pack removed'),
            backgroundColor: const Color(0xFF52525B),
          ),
        );
      }
    }
  }
}

enum _ModelStatus { downloaded, downloading, notDownloaded }
