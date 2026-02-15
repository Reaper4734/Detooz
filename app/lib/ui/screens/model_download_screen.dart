/// Model Download Screen — Shows download progress with WiFi/mobile data check.
///
/// Navigated to when a user initiates a language model download.
/// Checks connectivity type and prompts for mobile data confirmation if needed.
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/connectivity_service.dart';
import '../../services/translation/translation_service.dart';
import '../../services/translation/language_config.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import '../components/tr.dart';

enum _DownloadState { checkingConnection, confirmMobileData, downloading, success, error }

/// Navigate to download screen and return true if download succeeded.
Future<bool> showModelDownload(
  BuildContext context,
  WidgetRef ref, {
  required String langCode,
  required String langName,
  bool setAsAppLanguage = false,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ModelDownloadScreen(
        ref: ref,
        langCode: langCode,
        langName: langName,
        setAsAppLanguage: setAsAppLanguage,
      ),
    ),
  );
  return result ?? false;
}

class ModelDownloadScreen extends StatefulWidget {
  final WidgetRef ref;
  final String langCode;
  final String langName;
  final bool setAsAppLanguage;

  const ModelDownloadScreen({
    super.key,
    required this.ref,
    required this.langCode,
    required this.langName,
    this.setAsAppLanguage = false,
  });

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen>
    with SingleTickerProviderStateMixin {
  _DownloadState _state = _DownloadState.checkingConnection;
  double _progress = 0.0;
  String _errorMessage = '';
  bool _isWifi = true;
  Timer? _progressTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkConnection();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _state = _DownloadState.checkingConnection);

    final hasInternet = await connectivityService.hasInternet();
    if (!hasInternet) {
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = 'No internet connection. Please connect to a network and try again.';
        });
      }
      return;
    }

    // Check if WiFi
    final connectivity = await Connectivity().checkConnectivity();
    _isWifi = connectivity.contains(ConnectivityResult.wifi);

    if (_isWifi) {
      // WiFi available, start download directly
      _startDownload();
    } else {
      // Mobile data only — ask user to confirm
      if (mounted) {
        setState(() => _state = _DownloadState.confirmMobileData);
      }
    }
  }

  Future<void> _startDownload() async {
    if (mounted) {
      setState(() {
        _state = _DownloadState.downloading;
        _progress = 0.0;
      });
    }

    // ML Kit doesn't give real progress, so simulate smooth progress
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        // Slow curve that approaches 0.9 but never reaches 1.0
        if (_progress < 0.9) {
          _progress += (0.9 - _progress) * 0.04;
        }
      });
    });

    try {
      // Pass allowCellular: !_isWifi to enable download over mobile data if needed
      await TranslationService().downloadModel(
        widget.langCode,
        allowCellular: !_isWifi,
        onProgress: (p) {
          if (p >= 1.0 && mounted) {
            _progressTimer?.cancel();
            setState(() => _progress = 1.0);
          }
        },
      );

      _progressTimer?.cancel();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _state = _DownloadState.success;
        });

        // Auto-close after a moment
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = 'Download failed. Please try again.\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_ios,
                                color: AppColors.textSecondary(context), size: 18),
                            const SizedBox(width: 4),
                            Text('Cancel',
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
                        child: const Icon(Icons.cloud_download_outlined,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Downloading ${widget.langName}',
                        style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tr(
                        'Language pack (~30 MB) for offline scam detection.',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 15,
                            height: 1.5),
                      ),

                      const SizedBox(height: 40),

                      // Main content area based on state
                      _buildContent(),
                    ],
                  ),
                ),
              ),

              // Bottom action button
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _DownloadState.checkingConnection:
        return _buildCheckingConnection();
      case _DownloadState.confirmMobileData:
        return _buildMobileDataPrompt();
      case _DownloadState.downloading:
        return _buildDownloadProgress();
      case _DownloadState.success:
        return _buildSuccess();
      case _DownloadState.error:
        return _buildError();
    }
  }

  Widget _buildCheckingConnection() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Color(0xFF6366F1)),
        const SizedBox(height: 24),
        Tr('Checking connection...',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 15)),
      ],
    );
  }

  Widget _buildMobileDataPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Tr('No WiFi detected',
                    style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Tr(
            'You\'re on mobile data. This download is ~30 MB. Continue over mobile data?',
            style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border(context)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Tr('Wait for WiFi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Tr('Use Mobile Data',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    final percent = (_progress * 100).toInt();
    return Column(
      children: [
        const SizedBox(height: 20),

        // Progress circle
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                ),
              ),
              // Progress circle
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 8,
                  color: const Color(0xFF6366F1),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Percentage text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '~30 MB',
                    style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Status text
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Opacity(
            opacity: 0.5 + (_pulseController.value * 0.5),
            child: Tr('Downloading language pack...',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 15)),
          ),
        ),

        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: Color(0xFF6366F1), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Tr(
                  'All processing stays on your device. Nothing is sent to any server.',
                  style: TextStyle(
                      color: const Color(0xFF22C55E),
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0x2622C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF22C55E), size: 44),
        ),
        const SizedBox(height: 24),
        Tr('Download complete!',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Tr('${widget.langName} is ready for offline detection.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 14)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 44),
        ),
        const SizedBox(height: 24),
        Tr('Download Failed',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(_errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 14)),
      ],
    );
  }

  Widget _buildBottomButton() {
    if (_state == _DownloadState.downloading ||
        _state == _DownloadState.checkingConnection) {
      return const SizedBox.shrink();
    }

    if (_state == _DownloadState.confirmMobileData) {
      return const SizedBox.shrink(); // Buttons are inside the card
    }

    if (_state == _DownloadState.error) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _checkConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Tr('Try Again',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    // Success state
    return const SizedBox.shrink();
  }
}
