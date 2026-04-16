import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_colors.dart';
import '../../services/connectivity_service.dart';
import '../../services/translation/translation_service.dart';

// ════════════════════════════════════════════════════════════
//  SHARED HELPERS — Neo-Brutalist Design System Components
// ════════════════════════════════════════════════════════════

/// Brutalist header row with back button
Widget buildBrutalistHeader(BuildContext context, String title, {bool showBackButton = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (showBackButton && Navigator.canPop(context))
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios, size: 16, color: AppColors.textPrimary(context)),
                const SizedBox(width: 2),
                Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
              ]),
            ),
          ),
        if (title.isNotEmpty)
          Builder(builder: (context) {
            final scale = MediaQuery.of(context).size.width / 375.0;
            if (title.toUpperCase().contains('&')) {
              final parts = title.toUpperCase().split('&');
              return RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'IntegralCF', fontSize: 20 * scale, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary(context), letterSpacing: 0.5,
                  ),
                  children: [
                    TextSpan(text: parts[0]),
                    TextSpan(
                      text: ' & ',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 24 * scale),
                    ),
                    TextSpan(text: parts.length > 1 ? parts[1].trimLeft() : ''),
                  ],
                ),
              );
            }
            return Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'IntegralCF', fontSize: 20 * scale, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context), letterSpacing: 0.5,
              ),
            );
          }),
      ],
    ),
  );
}

/// Section label
Widget buildSectionLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'IntegralCF', fontSize: 14, fontWeight: FontWeight.w900,
        color: AppColors.textSecondary(context), letterSpacing: 1.5,
      ),
    ),
  );
}

/// Settings card container
Widget buildSettingsCard(BuildContext context, {required List<Widget> children, Color? borderColor}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      border: Border.all(color: borderColor ?? AppColors.divider(context)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(children: children),
  );
}

/// Settings row
Widget buildSettingsRow(BuildContext context, {
  required Widget leading,
  required String title,
  String? subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  bool isLast = false,
  Color? titleColor,
  Color? backgroundColor,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.divider(context))),
      ),
      child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary(context)),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    ),
  );
}

/// Round icon container
Widget buildRowIcon(BuildContext context, IconData icon, {Color? iconColor, Color? bgColor, Color? borderColor}) {
  return Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: bgColor ?? AppColors.surface(context),
      border: Border.all(color: borderColor ?? AppColors.divider(context)),
      shape: BoxShape.circle,
    ),
    child: Center(child: Icon(icon, size: 18, color: iconColor ?? AppColors.textPrimary(context))),
  );
}

/// Brutalist toggle switch
class BrutalToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const BrutalToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40, height: 22,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: value ? AppColors.primary : AppColors.textSecondary(context).withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(34),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16, height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.primary : AppColors.textSecondary(context).withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary button
Widget buildPrimaryButton(BuildContext context, {required String label, IconData? icon, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
        ],
        Text(label.toUpperCase(), style: const TextStyle(
          fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
        )),
      ]),
    ),
  );
}

/// Danger outline button
Widget buildDangerButton(BuildContext context, {required String label, IconData? icon, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label.toUpperCase(), style: TextStyle(
          fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger,
        )),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════
//  LANGUAGE SCREEN AUXILIARY COMPONENTS
// ════════════════════════════════════════════════════════════

/// Hero block with icon + title + subtitle
Widget buildHeroBlock(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
  final primary = AppColors.primary;
  return Row(children: [
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        border: Border.all(color: primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, size: 28, color: primary)),
    ),
    const SizedBox(width: 16),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(
          fontFamily: 'IntegralCF', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context),
        )),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4)),
      ]),
    ),
  ]);
}

/// Info box
Widget buildInfoBox(BuildContext context, String text) {
  final primary = AppColors.primary;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: primary.withOpacity(0.05),
      border: Border.all(color: primary.withOpacity(0.2)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info, size: 20, color: primary),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.5))),
    ]),
  );
}

/// Language badge
Widget buildLangBadge(BuildContext context, String symbol, bool isActive) {
  final primary = AppColors.primary;
  return Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(isActive ? 8 : 2),
      color: isActive ? primary.withOpacity(0.1) : AppColors.background(context),
      border: Border.all(color: isActive ? primary.withOpacity(0.3) : AppColors.divider(context)),
    ),
    child: Center(child: Text(symbol, style: TextStyle(
      fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700,
      color: isActive ? primary : AppColors.textSecondary(context).withOpacity(0.3),
    ))),
  );
}

// ════════════════════════════════════════════════════════════
//  INLINE DOWNLOAD DIALOG — Replaces full-page ModelDownloadScreen
// ════════════════════════════════════════════════════════════

/// Shows an inline download progress dialog. Returns true if download succeeded.
Future<bool> showDownloadDialog(
  BuildContext context, {
  required String langCode,
  required String langName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(langCode: langCode, langName: langName),
  );
  return result ?? false;
}

class _DownloadDialog extends StatefulWidget {
  final String langCode;
  final String langName;
  const _DownloadDialog({required this.langCode, required this.langName});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

enum _DlState { checking, confirmMobile, downloading, success, error }

class _DownloadDialogState extends State<_DownloadDialog> {
  _DlState _state = _DlState.checking;
  double _progress = 0.0;
  String _errorMsg = '';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _state = _DlState.checking);

    final hasInternet = await connectivityService.hasInternet();
    if (!hasInternet) {
      if (mounted) setState(() { _state = _DlState.error; _errorMsg = 'No internet connection.'; });
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (isWifi) {
      _startDownload();
    } else {
      if (mounted) setState(() => _state = _DlState.confirmMobile);
    }
  }

  Future<void> _startDownload() async {
    if (mounted) setState(() { _state = _DlState.downloading; _progress = 0.0; });

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_progress < 0.9) _progress += (0.9 - _progress) * 0.04;
      });
    });

    try {
      await TranslationService().downloadModel(
        widget.langCode,
        allowCellular: true,
        onProgress: (p) {
          if (p >= 1.0 && mounted) {
            _progressTimer?.cancel();
            setState(() => _progress = 1.0);
          }
        },
      );
      _progressTimer?.cancel();
      if (mounted) setState(() { _progress = 1.0; _state = _DlState.success; });
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) setState(() { _state = _DlState.error; _errorMsg = 'Download failed. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border.all(color: AppColors.divider(context), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              _state == _DlState.success
                  ? 'DOWNLOAD COMPLETE'
                  : _state == _DlState.error
                      ? 'DOWNLOAD FAILED'
                      : 'DOWNLOADING ${widget.langName.toUpperCase()}',
              style: TextStyle(
                fontFamily: 'IntegralCF', fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            if (_state == _DlState.downloading || _state == _DlState.checking)
              Text(
                'Please wait while we install the language pack.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 24),

            // Content
            _buildContent(context),

            const SizedBox(height: 24),

            // Bottom button
            _buildButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final primary = AppColors.primary;

    switch (_state) {
      case _DlState.checking:
        return Column(children: [
          // Linear indeterminate bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 12),
          Text('Checking connection...', style: TextStyle(
            fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          )),
        ]);

      case _DlState.confirmMobile:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.wifi_off, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'No WiFi detected. This download is ~30 MB. Continue on mobile data?',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
            )),
          ]),
        );

      case _DlState.downloading:
        final percent = (_progress * 100).toInt();
        return Column(children: [
          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: primary.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$percent%',
            style: TextStyle(
              fontFamily: 'IntegralCF', fontSize: 16,
              fontWeight: FontWeight.w700, color: primary,
            ),
          ),
        ]);

      case _DlState.success:
        return Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.check, color: AppColors.success, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.langName} is ready for use.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
          ),
        ]);

      case _DlState.error:
        return Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.error_outline, color: AppColors.danger, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), height: 1.4),
          ),
        ]);
    }
  }

  Widget _buildButton(BuildContext context) {
    if (_state == _DlState.checking || _state == _DlState.downloading) {
      return GestureDetector(
        onTap: () => Navigator.pop(context, false),
        child: Container(
          width: double.infinity, height: 40,
          decoration: BoxDecoration(
            color: AppColors.background(context),
            border: Border.all(color: AppColors.divider(context)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(child: Text(
            'CANCEL DOWNLOAD',
            style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
          )),
        ),
      );
    }

    if (_state == _DlState.confirmMobile) {
      return Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.background(context), border: Border.all(color: AppColors.divider(context)), borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text('CANCEL', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)))),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: _startDownload,
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('USE DATA', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        )),
      ]);
    }

    if (_state == _DlState.success) {
      return GestureDetector(
        onTap: () => Navigator.pop(context, true),
        child: Container(
          width: double.infinity, height: 40,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
          child: const Center(child: Text('DONE', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
      );
    }

    // Error
    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => Navigator.pop(context, false),
        child: Container(
          height: 40,
          decoration: BoxDecoration(color: AppColors.background(context), border: Border.all(color: AppColors.divider(context)), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text('CLOSE', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)))),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(child: GestureDetector(
        onTap: _checkConnection,
        child: Container(
          height: 40,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
          child: const Center(child: Text('RETRY', style: TextStyle(fontFamily: 'IntegralCF', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
      )),
    ]);
  }
}
