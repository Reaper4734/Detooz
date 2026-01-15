import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class GuardiansScreen extends StatelessWidget {
  const GuardiansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Guardians'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Edit', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Guardians receive notifications when high-risk scams are detected on your device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Guardians List
            _buildGuardianTile(
              context,
              name: 'Mom',
              status: 'Active Protection',
              statusColor: AppColors.primary,
              icon: Icons.verified_user,
              imageUrl: 'https://i.pravatar.cc/150?u=mom', // Placeholder
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildGuardianTile(
              context,
              name: 'John Doe',
              status: 'Request Pending',
              statusColor: AppColors.warning,
              icon: Icons.pending,
              imageUrl: 'https://i.pravatar.cc/150?u=john', // Placeholder
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildGuardianTile(
              context,
              name: 'Sarah Smith',
              status: 'Alerted 2m ago',
              statusColor: AppColors.danger,
              icon: Icons.notifications_active,
              imageUrl: 'https://i.pravatar.cc/150?u=sarah', // Placeholder
              isAlerted: true,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            Text(
              'You can add up to 5 guardians to your network.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGuardianTile(
    BuildContext context, {
    required String name,
    required String status,
    required Color statusColor,
    required IconData icon,
    required String imageUrl,
    bool isAlerted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isAlerted ? AppColors.danger.withOpacity(0.3) : Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isAlerted ? AppColors.danger.withOpacity(0.5) : Theme.of(context).dividerColor),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isAlerted)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.priority_high, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(icon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
