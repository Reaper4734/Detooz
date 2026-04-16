import 'dart:math';
import 'package:flutter/material.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../../services/api_service.dart';
import '../../utils/datetime_utils.dart';
import '../components/offline_aware_widget.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';

/// Unified Neo-Brutalist Result Screen
/// Handles both Manual Check results and SMS/WhatsApp scan details.
class ScanDetailScreen extends StatefulWidget {
  final ScanViewModel scan;
  final bool isCloudAnalysis;

  const ScanDetailScreen({
    super.key,
    required this.scan,
    this.isCloudAnalysis = false,
  });

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final targetProgress = _targetProgress;
    _animation = Tween<double>(begin: 0, end: targetProgress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    // Start animation after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  /// Maps the AI confidence into the correct dial partition:
  ///   SAFE   → 1st segment (0.00 – 0.33)
  ///   MEDIUM → 2nd segment (0.33 – 0.66)
  ///   HIGH   → 3rd segment (0.66 – 1.00)
  /// The raw confidence (0–1) positions the fill *within* the zone.
  double get _targetProgress {
    final raw = (widget.scan.confidence ?? _fallbackConfidence).clamp(0.0, 1.0);
    switch (widget.scan.riskLevel) {
      case RiskLevel.low:
        // Map into 1st partition: 0.00 → 0.33
        return raw * 0.33;
      case RiskLevel.medium:
        // Map into 2nd partition: 0.33 → 0.66
        return 0.33 + raw * 0.33;
      case RiskLevel.high:
        // Map into 3rd partition: 0.66 → 1.00
        return 0.66 + raw * 0.34;
    }
  }

  double get _fallbackConfidence {
    switch (widget.scan.riskLevel) {
      case RiskLevel.high:
        return 0.85;
      case RiskLevel.medium:
        return 0.70;
      case RiskLevel.low:
        return 0.80;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── Risk state from the backend verdict (riskLevel) ────────
  // confidence = "how sure the AI is" (e.g., 0.95 = 95% sure it's safe)
  // riskLevel  = the actual verdict   (low / medium / high)
  // They are NOT the same axis — a safe message can have 0.95 confidence.
  _DynamicRiskState _stateForRiskLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return _DynamicRiskState(
          score: 0,
          color: AppColors.danger,
          label: tr('HIGH RISK'),
          title: tr('Threat Detected'),
          icon: Icons.warning_amber_rounded,
        );
      case RiskLevel.medium:
        return _DynamicRiskState(
          score: 0,
          color: AppColors.warning,
          label: 'SUSPICIOUS',
          title: tr('Potential Risk'),
          icon: Icons.privacy_tip_outlined,
        );
      case RiskLevel.low:
        return _DynamicRiskState(
          score: 0,
          color: AppColors.success,
          label: 'SAFE',
          title: tr('Safe Content'),
          icon: Icons.verified_user_outlined,
        );
    }
  }

  // Final settled state — uses the backend riskLevel, score from confidence
  _DynamicRiskState get _finalState {
    final base = _stateForRiskLevel(widget.scan.riskLevel);
    return _DynamicRiskState(
      score: (_targetProgress * 100).round(),
      color: base.color,
      label: base.label,
      title: base.title,
      icon: base.icon,
    );
  }

  bool get _isManual => widget.scan.sender.startsWith('Manual');
  bool get _isLocalModel => widget.scan.source == 'local';

  @override
  Widget build(BuildContext context) {
    final finalState = _finalState;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Scrollable Content ─────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  children: [
                    // 1️⃣ Header
                    _buildHeader(context),
                    const SizedBox(height: 40),

                    // 2️⃣ Animated Neo-Brutalist Dial
                    _buildAnimatedDial(context),
                    const SizedBox(height: 40),

                    // 3️⃣ Risk Summary Card
                    _buildRiskSummaryCard(context, finalState),

                    // 4️⃣ Source & Engine Card (conditional)
                    _buildSourceCard(context),

                    // 5️⃣ Sender Info (only for non-manual scans)
                    if (!_isManual) _buildSenderCard(context),

                    // 6️⃣ Message Preview
                    if (widget.scan.messagePreview.isNotEmpty)
                      _buildContentCard(context),
                  ],
                ),
              ),
            ),

            // ─── Bottom Actions ─────────────────────
            _buildBottomActions(context, finalState),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border:
                  Border.all(color: AppColors.divider(context), width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(Icons.chevron_left,
                  color: AppColors.textPrimary(context), size: 24),
            ),
          ),
        ),
        const Spacer(),
        Text(
          _isManual ? 'MANUAL CHECK' : 'SCAN RESULTS',
          style: TextStyle(
            fontFamily: 'IntegralCF',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        const Spacer(),
        const SizedBox(width: 40), // Balance
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // ANIMATED DIAL
  // ════════════════════════════════════════════════════════════
  Widget _buildAnimatedDial(BuildContext context) {
    final riskState = _stateForRiskLevel(widget.scan.riskLevel);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = _animation.value;
        final displayScore = (currentValue * 100).round();

        return SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: _DialPainter(
              progress: currentValue,
              color: riskState.color,
              trackColor: AppColors.divider(context),
              bgColor: AppColors.background(context),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$displayScore',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    riskState.label,
                    style: TextStyle(
                      fontFamily: 'IntegralCF',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: riskState.color,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // RISK SUMMARY CARD
  // ════════════════════════════════════════════════════════════
  Widget _buildRiskSummaryCard(
      BuildContext context, _DynamicRiskState state) {
    return _NeoCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(state.icon, size: 24, color: state.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.scan.riskReason ??
                          'Analysis completed based on content provided.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _divider(context),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 16, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 6),
                  Tr(
                    'Scanned ${DateTimeUtils.formatSmartDate(widget.scan.scannedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                state.label == 'SAFE'
                    ? 'Safe'
                    : (state.label == 'HIGH RISK'
                        ? 'High Risk'
                        : 'Suspicious'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: state.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SOURCE CARD
  // ════════════════════════════════════════════════════════════
  Widget _buildSourceCard(BuildContext context) {
    return _NeoCard(
      child: Column(
        children: [
          _metaBlock(
            context,
            'CONTENT SOURCE',
            _isManual
                ? 'Manual Input'
                : widget.scan.platform.name.toUpperCase(),
          ),
          _divider(context),
          _metaBlock(
            context,
            'ANALYSIS ENGINE',
            _isLocalModel ? 'Local Model' : 'Cloud Model',
            icon: _isLocalModel ? Icons.memory_outlined : Icons.cloud_outlined,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SENDER CARD (non-manual only)
  // ════════════════════════════════════════════════════════════
  Widget _buildSenderCard(BuildContext context) {
    return _NeoCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.divider(context), width: 1.5),
            ),
            child: Center(
              child: Text(
                widget.scan.sender.isNotEmpty
                    ? widget.scan.sender[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'IntegralCF',
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scan.sender,
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.scan.platform.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'IntegralCF',
                    color: AppColors.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // MESSAGE PREVIEW CARD
  // ════════════════════════════════════════════════════════════
  Widget _buildContentCard(BuildContext context) {
    return _NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTENT ANALYZED',
            style: TextStyle(
              fontFamily: 'IntegralCF',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context).withOpacity(0.5),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.scan.messagePreview,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary(context),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM ACTIONS
  // ════════════════════════════════════════════════════════════
  Widget _buildBottomActions(
      BuildContext context, _DynamicRiskState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(color: AppColors.divider(context), width: 1.5),
        ),
      ),
      child: _buildNeoButton(
        label: 'CLOSE',
        color: AppColors.primary,
        textColor: Colors.black,
        onTap: () => Navigator.maybePop(context),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHARED BUILDERS
  // ════════════════════════════════════════════════════════════
  Widget _divider(BuildContext context) => Container(
        height: 1,
        color: AppColors.divider(context),
        margin: const EdgeInsets.symmetric(vertical: 12),
      );

  Widget _metaBlock(BuildContext context, String label, String value,
      {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IntegralCF',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(context).withOpacity(0.5),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textPrimary(context)),
              const SizedBox(width: 10),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNeoButton({
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IntegralCF',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DYNAMIC RISK STATE
// ════════════════════════════════════════════════════════════════
class _DynamicRiskState {
  final int score;
  final Color color;
  final String label;
  final String title;
  final IconData icon;

  const _DynamicRiskState({
    required this.score,
    required this.color,
    required this.label,
    required this.title,
    required this.icon,
  });
}

// ════════════════════════════════════════════════════════════════
// NEO CARD
// ════════════════════════════════════════════════════════════════
class _NeoCard extends StatelessWidget {
  final Widget child;
  const _NeoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border.all(color: AppColors.divider(context), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DIAL PAINTER — 3-segmented Neo-Brutalist arc with dynamic fill
// ════════════════════════════════════════════════════════════════
class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final Color bgColor;

  _DialPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // ── Track (background ring) ──
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);

    // ── Progress (colored fill) ──
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);

    // ── Gap Separators (3 evenly spaced dividers faking segmentation) ──
    final dividerPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (int i = 0; i < 3; i++) {
      final angle = -pi / 2 + (2 * pi / 3) * i;
      final inner = Offset(
        center.dx + (radius - strokeWidth) * cos(angle),
        center.dy + (radius - strokeWidth) * sin(angle),
      );
      final outer = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(inner, outer, dividerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
