/// Setup Offline Protection Screen — Onboarding flow for language selection.
///
/// Shows after permissions wizard on first launch. User selects their
/// State/UT, and the app auto-downloads the corresponding language pack
/// in the background.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';
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
    Responsive.init(context);
    ref.watch(languageProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.sp(24), vertical: Responsive.sp(20)),
          child: Column(
            children: [
              // ─── Scrollable content ───
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: Responsive.sp(20)),

                      // Header icon box
                      Container(
                        width: Responsive.sp(64),
                        height: Responsive.sp(64),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                          border: Border.all(color: AppColors.textPrimary(context), width: 2),
                        ),
                        child: Center(
                          child: Icon(Icons.translate, color: Colors.white, size: Responsive.sp(32)),
                        ),
                      ),
                      SizedBox(height: Responsive.sp(32)),

                      // Title
                      Text(
                        'OFFLINE',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: Responsive.sp(36),
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -1,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        'PROTECTION',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: Responsive.sp(36),
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: -1,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: Responsive.sp(12)),
                      
                      Tr(
                        'Select your state so Detooz can protect you from scams in your local language.',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: Responsive.sp(14),
                            height: 1.5),
                      ),

                      SizedBox(height: Responsive.sp(32)),

                      // ─── Explanation card ───
                      Container(
                        padding: EdgeInsets.all(Responsive.sp(16)),
                        decoration: BoxDecoration(
                          color: AppColors.background(context),
                          border: Border.all(color: AppColors.textPrimary(context), width: 2),
                          boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined, color: AppColors.textPrimary(context), size: Responsive.sp(18)),
                                SizedBox(width: Responsive.sp(8)),
                                Tr('WHY THIS MATTERS',
                                    style: TextStyle(
                                        fontFamily: 'IntegralCF',
                                        color: AppColors.textPrimary(context),
                                        fontSize: Responsive.sp(14),
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            SizedBox(height: Responsive.sp(12)),
                            Tr(
                              'Scammers target people in their local language. By selecting your state, Detooz downloads a small language pack (~30 MB) so it can detect scams in your regional language — even without internet.',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: Responsive.sp(12),
                                  height: 1.5),
                            ),
                            SizedBox(height: Responsive.sp(12)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.sp(8), vertical: Responsive.sp(4)),
                              color: AppColors.success,
                              child: Tr(
                                'All processing stays on your device. Nothing is sent to any server.',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: Responsive.sp(11),
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.sp(32)),

                      // ─── State dropdown ───
                      Text(
                        'SELECT YOUR STATE',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: Responsive.sp(12),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      SizedBox(height: Responsive.sp(8)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.sp(16)),
                        height: Responsive.h(52),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          border: Border.all(color: AppColors.divider(context), width: 2),
                        ),
                        child: Center(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedState,
                              hint: Tr('Choose from list',
                                  style: TextStyle(
                                      color: AppColors.textPrimary(context).withOpacity(0.5),
                                      fontSize: Responsive.sp(14),
                                      fontWeight: FontWeight.w500)),
                              isExpanded: true,
                              dropdownColor: AppColors.surface(context),
                              icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary(context)),
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
                                            color: AppColors.textPrimary(context),
                                            fontSize: Responsive.sp(14),
                                            fontWeight: FontWeight.w600,
                                          )),
                                      Text(langName,
                                          style: TextStyle(
                                              color: AppColors.textSecondary(context),
                                              fontSize: Responsive.sp(12))),
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
                      ),

                      // ─── Selected language info ───
                      if (_selectedState != null) ...[
                        SizedBox(height: Responsive.sp(16)),
                        _buildLanguageInfoCard(),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── Continue button ───
              SizedBox(height: Responsive.sp(12)),
              GestureDetector(
                onTap: _selectedState != null ? _onContinue : null,
                child: Container(
                  width: double.infinity,
                  height: Responsive.h(56),
                  decoration: BoxDecoration(
                    color: _selectedState != null ? AppColors.primary : AppColors.divider(context),
                    boxShadow: _selectedState != null 
                        ? const [BoxShadow(offset: Offset(4, 4), color: Colors.black)]
                        : [],
                    border: Border.all(
                      color: _selectedState != null ? Colors.transparent : AppColors.textSecondary(context).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _selectedState == null
                          ? 'MANDATORY SELECTION'
                          : 'CONTINUE TO DASHBOARD',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(15),
                        fontWeight: FontWeight.w700,
                        color: _selectedState != null ? Colors.black : AppColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.sp(12)),
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
      padding: EdgeInsets.all(Responsive.sp(12)),
      decoration: BoxDecoration(
        color: needsDownload ? AppColors.success.withOpacity(0.1) : AppColors.surface(context),
        border: Border.all(
          color: needsDownload ? AppColors.success : AppColors.divider(context),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            needsDownload ? Icons.cloud_download_outlined : Icons.check_circle_outline,
            color: needsDownload ? AppColors.success : AppColors.textPrimary(context),
            size: Responsive.sp(24),
          ),
          SizedBox(width: Responsive.sp(12)),
          Expanded(
            child: Text(
              needsDownload
                  ? '$langName setup will begin automatically (~30 MB).'
                  : 'English detection is built-in. No download needed.',
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: Responsive.sp(13),
                  fontWeight: FontWeight.w600,
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

    // Call the parent's callback or navigate to dashboard directly
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }
}
