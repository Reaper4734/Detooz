import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../services/api_service.dart';

class ManualResultScreen extends StatelessWidget {
  final ScanViewModel scan;

  const ManualResultScreen({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    Color riskColor;
    String riskLabel;
    String riskDesc;
    int score;
    IconData badgeIcon;
    String badgeText;

    switch (scan.riskLevel) {
      case RiskLevel.high:
        riskColor = AppColors.danger;
        riskLabel = 'HIGH RISK';
        riskDesc = 'This content matches known scam patterns.';
        score = 95;
        badgeIcon = Icons.warning;
        badgeText = 'THREAT DETECTED';
        break;
      case RiskLevel.medium:
        riskColor = AppColors.warning;
        riskLabel = 'SUSPICIOUS';
        riskDesc = 'Potential scam detected. Proceed with caution.';
        score = 65;
        badgeIcon = Icons.info_outline;
        badgeText = 'CAUTION ADVISED';
        break;
      case RiskLevel.low:
        riskColor = AppColors.success;
        riskLabel = 'SAFE';
        riskDesc = 'No suspicious patterns found.';
        score = 0;
        badgeIcon = Icons.check_circle;
        badgeText = 'VERIFIED SAFE';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manual Check Result', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
            child: Column(
              children: [
                // Risk Visual Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: riskColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 6,
                              backgroundColor: Colors.black.withOpacity(0.2),
                              color: Colors.white,
                            ),
                            Text(
                              '$score%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Text(
                              riskLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              riskDesc,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Content Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECKED CONTENT',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scan.messagePreview,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Analysis Box
                 Container(
                   padding: const EdgeInsets.all(AppSpacing.md),
                   decoration: BoxDecoration(
                     color: Colors.purple.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.purple.withOpacity(0.1)),
                   ),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: Colors.purple.withOpacity(0.1),
                           shape: BoxShape.circle,
                         ),
                         child: const Icon(Icons.analytics, color: Colors.purple, size: 20),
                       ),
                       const SizedBox(width: AppSpacing.md),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('AI Assessment', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                             const SizedBox(height: 4),
                             Text(
                               scan.riskReason ?? 'Analysis complete.',
                               style: Theme.of(context).textTheme.bodySmall,
                             ),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
              ],
            ),
          ),
          
          // Action (Only Report/Feedback needed? Or maybe just Close)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, MediaQuery.of(context).padding.bottom + AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to Dashboard'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
