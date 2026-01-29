import 'package:flutter/material.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'risk_badge.dart';
import 'platform_icon.dart';

class ScanCard extends StatelessWidget {
  final ScanViewModel scan;
  final VoidCallback onTap;
  
  const ScanCard({
    super.key,
    required this.scan,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: Color(0xFFE2E8F0)), // Light border
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              RiskBadge(level: scan.riskLevel),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PlatformIcon(platform: scan.platform, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          scan.senderNumber, 
                          style: AppTypography.bodySmall.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      scan.messagePreview, 
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
            ],
          ),
        ),
      ),
    );
  }
}
