import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../contracts/risk_level.dart';

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  
  const RiskBadge({super.key, required this.level});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        _getLabel(), 
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 12, 
          fontWeight: FontWeight.w600
        )
      ),
    );
  }
  
  Color _getColor() {
    switch (level) {
      case RiskLevel.high: return AppColors.riskHigh;
      case RiskLevel.medium: return AppColors.riskMedium;
      case RiskLevel.low: return AppColors.riskLow;
    }
  }
  
  String _getLabel() {
    switch (level) {
      case RiskLevel.high: return 'HIGH';
      case RiskLevel.medium: return 'MEDIUM';
      case RiskLevel.low: return 'LOW';
    }
  }
}
