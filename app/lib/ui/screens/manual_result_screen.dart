import 'dart:ui';
import 'package:flutter/material.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../../services/api_service.dart';

class ManualResultScreen extends StatelessWidget {
  final ScanViewModel scan;
  final bool isCloudAnalysis;

  const ManualResultScreen({
    super.key, 
    required this.scan,
    this.isCloudAnalysis = false, // Default to local
  });

  @override
  Widget build(BuildContext context) {
    // 🎨 UI Constants & Logic
    // final bool isCloudAnalysis = false; // Removed placeholder

    Color riskColor;
    String riskLabel;
    String riskTitle;
    int score;
    IconData riskIcon; // For the meter
    IconData summaryIcon; // For the card (e.g. hook vs shield)
    String riskBadgeText;

    // Calculate score from confidence if available (0.0 - 1.0)
    // We treat confidence as "Risk Score" (Probability of being a scam)
    if (scan.confidence != null) {
      score = (scan.confidence! * 100).toInt();
    } else {
       // Fallback defaults
       if (scan.riskLevel == RiskLevel.high) score = 85;
       else if (scan.riskLevel == RiskLevel.medium) score = 65; // User mentioned "moderate (btw 45)"
       else score = 10; // Low risk score
    }

    switch (scan.riskLevel) {
      case RiskLevel.high:
        riskColor = const Color(0xFFF87171); // Red
        riskLabel = 'HIGH RISK';
        riskTitle = 'Threat Detected'; 
        riskIcon = Icons.gpp_bad_outlined;
        summaryIcon = Icons.phishing; // Hook for high risk
        riskBadgeText = 'Critical Threat';
        break;
      case RiskLevel.medium:
        riskColor = const Color(0xFFFBBF24); // Amber/Yellow
        riskLabel = 'SUSPICIOUS';
        riskTitle = 'Potential Risk';
        riskIcon = Icons.warning_amber_rounded;
        summaryIcon = Icons.warning_amber; // Warning triangle for suspicious
        riskBadgeText = 'Caution Advised';
        break;
      case RiskLevel.low:
        riskColor = const Color(0xFF34D399); // Emerald/Green
        riskLabel = 'SAFE';
        riskTitle = 'Safe Content';
        riskIcon = Icons.verified_user_outlined;
        summaryIcon = Icons.check_circle_outline; // Shield/Check for safe
        riskBadgeText = 'Safe';
        
        // CORRECTION: If Logic says Safe but Score is high (e.g. 40% might be treated as Safe in backend but looks risky visually)
        // We should ensure visual consistency. If Safe, score should probably be low (Risk Score) or we invert it?
        // Usually, Confidence = Scam Confidence. So 0% = Safe. 
        // If the backend returns 40% confidence but marks it Safe (threshold might be 50%), 
        // then showing 40% Red/Yellow might be wrong if the label is Safe.
        // Let's trust the RiskLevel for Color/Icon, and just show the raw Score. 
        // But if score > 30 and <= 50, it might be confusing if colored Green. 
        // Let's ensure Color follows RiskLevel strictly.
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
                  const Text(
                    'Scan Results',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the back button
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
                                child: Icon(summaryIcon, color: riskColor, size: 28), // Dynamic Icon
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
                                      scan.riskReason ?? 'No details available.',
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
                                  Text(
                                    'Scanned just now',
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

                    // 4️⃣ Secondary Info Card (Source & Location replacement)
                    _buildGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SOURCE',
                                  style: TextStyle(
                                    color: Color(0xFF71717A), // Zinc-500
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manual Input', // Fixed as per ManualResultScreen context
                                  style: const TextStyle(
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
                              crossAxisAlignment: CrossAxisAlignment.end, // Right aligned
                              children: [
                                const Text(
                                  'ANALYSIS SOURCE',
                                  style: TextStyle(
                                    color: Color(0xFF71717A), // Zinc-500
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 5️⃣ Bottom Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _buildPrimaryButton(context, 'View Details', () {
                    // Navigate to details or handle preview logic
                    // Current logic just pops, but prompt says "View Details"
                    // If no details screen exists for manual, maybe show modal?
                    // For now, let's keep it harmless or print. 
                    // Or keep the original "Back to Dashboard" behavior on Dismiss.
                  }),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Dismiss Results',
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

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
          // Background Circle
          SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 20,
              color: const Color(0xFF27272A), // Zinc-800
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress Circle
          SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 20,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Text Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                '$score%',
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
              const SizedBox(height: 4), // extra spacing to center visually
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
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withOpacity(0.8), // Zinc-glass
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x407C3AED), // Primary shadow
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED), // Primary Purple
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
