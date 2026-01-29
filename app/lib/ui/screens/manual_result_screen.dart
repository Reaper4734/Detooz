import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../components/tr.dart';
import '../../utils/datetime_utils.dart'; // Added for time formatting

class ManualResultScreen extends StatelessWidget {
  final ScanViewModel scan;
  final bool isCloudAnalysis;

  const ManualResultScreen({
    super.key, 
    required this.scan,
    this.isCloudAnalysis = false, 
  });

  @override
  Widget build(BuildContext context) {
    // 🎨 UI Constants & Logic
    Color riskColor;
    String riskLabel;
    String riskTitle;
    int score;
    IconData riskIcon;
    IconData summaryIcon;
    String riskBadgeText;

    // Calculate score (Simulated for manual or used from AI)
    if (scan.confidence != null) {
      score = (scan.confidence! * 100).toInt();
    } else {
       if (scan.riskLevel == RiskLevel.high) score = 95;
       else if (scan.riskLevel == RiskLevel.medium) score = 65;
       else score = 10;
    }

    switch (scan.riskLevel) {
      case RiskLevel.high:
        riskColor = const Color(0xFFF87171); // Red
        riskLabel = 'HIGH RISK';
        riskTitle = 'Threat Detected'; 
        riskIcon = Icons.gpp_bad_outlined;
        summaryIcon = Icons.phishing;
        riskBadgeText = 'Critical Threat';
        break;
      case RiskLevel.medium:
        riskColor = const Color(0xFFFBBF24); // Amber
        riskLabel = 'SUSPICIOUS';
        riskTitle = 'Potential Risk';
        riskIcon = Icons.warning_amber_rounded;
        summaryIcon = Icons.warning_amber;
        riskBadgeText = 'Caution Advised';
        break;
      case RiskLevel.low:
        riskColor = const Color(0xFF34D399); // Emerald
        riskLabel = 'SAFE';
        riskTitle = 'Safe Content';
        riskIcon = Icons.verified_user_outlined;
        summaryIcon = Icons.check_circle_outline;
        riskBadgeText = 'Safe';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True Black
      body: SafeArea(
        child: Column(
          children: [
            // 1️⃣ Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBackButton(context),
                  Tr('Manual Check',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 40), // Balance
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    
                    // 2️⃣ Circular Confidence Meter
                    _buildConfidenceMeter(score, riskColor, riskLabel, riskIcon),
                    
                    const SizedBox(height: 40),

                    // 3️⃣ Risk Summary Card
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: riskColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(summaryIcon, color: riskColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      riskTitle, 
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      scan.riskReason ?? 'Analysis completed based on content provided.',
                                      style: const TextStyle(
                                        color: Color(0xFFA1A1AA), // Zinc-400
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Tr('Scanned ${DateTimeUtils.formatSmartDate(scan.scannedAt)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: riskColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: riskColor.withOpacity(0.5), blurRadius: 6)],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    riskBadgeText,
                                    style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4️⃣ Source & Logic Card
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tr('SOURCE',
                                  style: TextStyle(
                                    color: Color(0xFF71717A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Tr('Manual Input',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Tr('ANALYSIS SOURCE',
                                  style: TextStyle(
                                    color: Color(0xFF71717A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCloudAnalysis ? 'Cloud Model' : 'Local Model',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    
                    // Message Preview (Since it's manual, user typed it or pasted it)
                    if (scan.messagePreview.isNotEmpty)
                      _buildGlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tr('CONTENT ANALYZED', style: TextStyle(color: Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text(
                              scan.messagePreview,
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Bottom Action
             Container(
              padding: const EdgeInsets.all(24),
              child: _buildPrimaryButton(context, 'Close', Theme.of(context).primaryColor, () {
                  Navigator.pop(context);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable Builders (Ideally moved to a shared widget, but kept here for speed) ---

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        onPressed: () => Navigator.pop(context),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildConfidenceMeter(int score, Color color, String label, IconData icon) {
    return Container(
      width: 260, height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
           SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 20,
              color: const Color(0xFF27272A),
              strokeCap: StrokeCap.round,
            ),
          ),
          SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 20,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Tr('$score%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withOpacity(0.8), 
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String label, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
