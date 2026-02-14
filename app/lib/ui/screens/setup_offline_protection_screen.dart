/// Setup Offline Protection Screen — Onboarding flow for language selection.
///
/// Shows after permissions wizard on first launch. User selects their
/// State/UT, and the app auto-downloads the corresponding language pack
/// in the background.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../components/tr.dart';
import '../providers.dart';
import '../../services/ml/sms_translator.dart';
import '../../services/ml/state_language_map.dart';

class SetupOfflineProtectionScreen extends ConsumerStatefulWidget {
  /// Optional callback when setup is complete.
  final VoidCallback? onComplete;

  const SetupOfflineProtectionScreen({super.key, this.onComplete});

  @override
  ConsumerState<SetupOfflineProtectionScreen> createState() =>
      _SetupOfflineProtectionScreenState();
}

class _SetupOfflineProtectionScreenState
    extends ConsumerState<SetupOfflineProtectionScreen> {
  final SmsTranslator _translator = SmsTranslator();

  String? _selectedState;
  String _selectedLangCode = 'en';

  @override
  void initState() {
    super.initState();
    _translator.initialize();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        child: const Icon(Icons.translate, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Tr('Setup Offline Protection',
                          style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 8),
                      Tr(
                        'Select your state so Detooz can protect you from scams in your local language.',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 15,
                            height: 1.5),
                      ),

                      const SizedBox(height: 16),

                      // Explanation card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shield_outlined,
                                    color: Color(0xFF6366F1), size: 18),
                                const SizedBox(width: 8),
                                Tr('Why this matters',
                                    style: TextStyle(
                                        color: AppColors.textPrimary(context),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Tr(
                              'Scammers target people in their local language. By selecting your state, Detooz downloads a small language pack (~30 MB) so it can detect scams in your regional language — even without internet.',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 13,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 6),
                            Tr(
                              'All processing stays on your device. Nothing is sent to any server.',
                              style: TextStyle(
                                  color: const Color(0xFF22C55E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // State dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedState,
                            hint: Tr('Select your State',
                                style: TextStyle(color: AppColors.textSecondary(context))),
                            isExpanded: true,
                            dropdownColor: AppColors.surface(context),
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textSecondary(context)),
                            items: sortedStateNames.map((state) {
                              final langCode = languageForState(state);
                              final langName = languageDisplayName(langCode);
                              return DropdownMenuItem(
                                value: state,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(state,
                                        style: TextStyle(
                                            color: AppColors.textPrimary(context))),
                                    Text(langName,
                                        style: TextStyle(
                                            color: AppColors.textSecondary(context),
                                            fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedState = value;
                                _selectedLangCode = languageForState(value);
                              });
                            },
                          ),
                        ),
                      ),

                      // Selected language info
                      if (_selectedState != null) ...[
                        const SizedBox(height: 16),
                        _buildLanguageInfoCard(),
                      ],
                    ],
                  ),
                ),
              ),

              // Continue button — pinned at bottom, disabled until state is selected
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedState != null ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Tr(
                      _selectedState == null
                          ? 'Select your state to continue'
                          : 'Continue to Dashboard',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageInfoCard() {
    final langName = languageDisplayName(_selectedLangCode);
    final needsDownload = _selectedLangCode != 'en';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            needsDownload ? Icons.cloud_download_outlined : Icons.check_circle,
            color: const Color(0xFF22C55E),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              needsDownload
                  ? '$langName detection will be downloaded (~30 MB).\nAll processing stays on your device.'
                  : 'English detection is built-in. No download needed.',
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedState != null && _selectedLangCode != 'en') {
      // Save the user's language preference
      await _translator.setUserLanguage(_selectedLangCode);

      // Fire-and-forget: download model in background
      _translator.downloadModel(_selectedLangCode).then((_) {
        debugPrint('✅ ${languageDisplayName(_selectedLangCode)} model downloaded in background');
      }).catchError((e) {
        debugPrint('⚠️ Background download failed: $e');
      });
    }

    // Navigate back to dashboard
    if (mounted) Navigator.of(context).pop();
  }
}
