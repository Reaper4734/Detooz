import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../services/api_service.dart';
import '../components/tr.dart';

class ScanDetailScreen extends StatelessWidget {
  final ScanViewModel scan;

  const ScanDetailScreen({super.key, required this.scan});

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
        riskDesc = 'AI analysis indicates highly suspicious patterns.';
        score = 95;
        badgeIcon = Icons.warning;
        badgeText = 'THREAT DETECTED';
        break;
      case RiskLevel.medium:
        riskColor = AppColors.warning;
        riskLabel = 'MEDIUM RISK';
        riskDesc = 'Potential scam detected. Proceed with caution.';
        score = 65;
        badgeIcon = Icons.info_outline;
        badgeText = 'CAUTION ADVISED';
        break;
      case RiskLevel.low:
        riskColor = AppColors.success;
        riskLabel = 'SAFE';
        riskDesc = 'No suspicious patterns detected.';
        score = 0;
        badgeIcon = Icons.check_circle;
        badgeText = 'VERIFIED SAFE';
        break;
    }

    final isManual = scan.sender.startsWith('Manual');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Tr('Scan Result', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md, 
              AppSpacing.sm, 
              AppSpacing.md, 
              isManual ? AppSpacing.xl : 120
            ),
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
                      // Gauge Visual (Simplified with Stack)
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
                            Tr('$score%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: AppSpacing.lg),
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
                                  SizedBox(width: 4),
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
                            SizedBox(height: 8),
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
                
                SizedBox(height: AppSpacing.lg),
                
                // Metadata Card
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _buildMetadataRow(
                        context,
                        icon: Icons.person,
                        label: tr('Sender'),
                        value: isManual ? 'Manual Check' : scan.sender,
                        isFirst: true,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildMetadataRow(
                        context,
                        icon: Icons.chat, // Should dynamic based on platform
                        label: tr('Platform'),
                        value: scan.platform.name.toUpperCase(),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(isManual ? 'Manual' : 'Business', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildMetadataRow(
                        context,
                        icon: Icons.schedule,
                        label: tr('Received'),
                        value: DateFormat('h:mm a').format(scan.scannedAt),
                        trailing: Tr('Today', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: AppSpacing.lg),
                
                // Message Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tr('Message Preview', style: AppTypography.h3.copyWith(fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Tr('Text Match', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scan.message.startsWith('/api/uploads/'))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            '${ApiService.baseUrl.replaceAll('/api', '')}${scan.message}',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.grey.withOpacity(0.1),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Tr('Failed to load image preview', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Tr('"${scan.messagePreview}"',
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(height: 1.5),
                        ),
                      SizedBox(height: AppSpacing.md),
                      if (scan.riskLevel != RiskLevel.low)
                        Row(
                          children: [
                            const Icon(Icons.link_off, size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Tr('Links Automatically Disabled', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                    ],
                  ),
                ),
                
                 SizedBox(height: AppSpacing.lg),
                 
                 // Analysis Box
                 Container(
                   padding: const EdgeInsets.all(AppSpacing.md),
                   decoration: BoxDecoration(
                     color: isManual ? Colors.orange.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: isManual ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                   ),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: isManual ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                           shape: BoxShape.circle,
                         ),
                         child: Icon(Icons.smart_toy, color: isManual ? Colors.orange : Colors.blue, size: 20),
                       ),
                       SizedBox(width: AppSpacing.md),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Tr('Guardian Analysis', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                             SizedBox(height: 4),
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
          
          // Bottom Actions - Only show if NOT manual
          if (!isManual)
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Call block API
                          final success = await apiService.blockSender(scan.sender);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Sender blocked successfully' : 'Failed to block sender'),
                                backgroundColor: success ? AppColors.success : AppColors.danger,
                              )
                            );
                            if (success) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.block),
                        label: Tr('Block this Sender'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () async {
                        // Report safe / trusted
                        final success = await apiService.markTrusted(sender: scan.sender, reason: "User reported safe");
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success['id'] != null ? 'Marked as Safe/Trusted' : 'Failed to mark safe'),
                                backgroundColor: AppColors.success,
                              )
                            );
                        }
                      },
                      child: Tr('Report as Safe', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
