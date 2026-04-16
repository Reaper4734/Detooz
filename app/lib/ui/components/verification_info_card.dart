import 'package:flutter/material.dart';
import '../components/tr.dart';
import '../theme/app_colors.dart';

/// Dismissible verification info card
/// Shows once on dashboard for new users who haven't verified
class VerificationInfoCard extends StatelessWidget {
  final bool emailVerified;
  final bool phoneVerified;
  final int? daysRemaining;
  final VoidCallback onVerifyNow;
  final VoidCallback onDismiss;
  
  const VerificationInfoCard({
    super.key,
    required this.emailVerified,
    required this.phoneVerified,
    this.daysRemaining,
    required this.onVerifyNow,
    required this.onDismiss,
  });
  
  @override
  Widget build(BuildContext context) {
    // Don't show if fully verified
    if (emailVerified) {
      return const SizedBox.shrink();
    }
    
    final primaryColor = AppColors.primary;
    final warningColor = AppColors.warning;
    
    return Dismissible(
      key: const ValueKey('verification_info_card'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.15),
              warningColor.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: warningColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Tr(
                    'Complete Your Protection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Dismiss hint
                Icon(
                  Icons.swipe,
                  color: Colors.grey[500],
                  size: 16,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Tr(
              'Verify your account to unlock full protection. This helps prevent bots and fake accounts.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onDismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Tr('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onVerifyNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Tr(
                      'Verify Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Trust score hint
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrustBadge('Email', emailVerified),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrustBadge(String label, bool verified) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.check_circle : Icons.radio_button_unchecked,
          color: verified ? Colors.green : Colors.grey[600],
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: verified ? Colors.green : Colors.grey[500],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
