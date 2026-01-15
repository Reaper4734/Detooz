import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../providers.dart';
import '../../contracts/guardian_view_model.dart';

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  
  @override
  Widget build(BuildContext context) {
    final guardiansAsync = ref.watch(guardiansProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Guardians'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(guardiansProvider.notifier).loadGuardians(),
          ),
        ],
      ),
      body: guardiansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Failed to load guardians', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(guardiansProvider.notifier).loadGuardians(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (guardians) => SingleChildScrollView(
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
                        'Guardians receive Telegram notifications when high-risk scams are detected.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              if (guardians.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No guardians yet', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('Tap + to add a guardian', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )
              else
                ...guardians.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildGuardianTile(context, guardian: g),
                )),
              
              const SizedBox(height: AppSpacing.lg),
              Text(
                'You can add up to 5 guardians to your network.',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGuardianDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGuardianTile(BuildContext context, {required GuardianViewModel guardian}) {
    final isAlerted = guardian.lastAlertSent != null &&
        DateTime.now().difference(guardian.lastAlertSent!).inHours < 24;
    final statusColor = isAlerted 
        ? AppColors.danger 
        : (guardian.isVerified ? AppColors.primary : AppColors.warning);
    
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.1),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                guardian.name.isNotEmpty ? guardian.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guardian.name, style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      guardian.isVerified ? Icons.verified_user : Icons.pending,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(guardian.statusText, style: TextStyle(color: statusColor, fontSize: 13)),
                  ],
                ),
                Text(guardian.phone, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGuardianDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final telegramController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Guardian'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: telegramController,
                decoration: const InputDecoration(
                  labelText: 'Telegram Chat ID (optional)',
                  helperText: 'Get from @userinfobot on Telegram',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                final success = await ref.read(guardiansProvider.notifier).addGuardian(
                  name: nameController.text,
                  phone: phoneController.text,
                  telegramChatId: telegramController.text.isNotEmpty ? telegramController.text : null,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Guardian added successfully!')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
