import 'package:flutter/material.dart';
import '../../services/sms_receiver_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

import 'package:permission_handler/permission_handler.dart';
import '../components/tr.dart';

class PermissionWizardScreen extends StatefulWidget {
  const PermissionWizardScreen({super.key});

  @override
  State<PermissionWizardScreen> createState() => _PermissionWizardScreenState();
}

class _PermissionWizardScreenState extends State<PermissionWizardScreen> with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _autostartDone = false;
  final bool _batteryDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final sms = await Permission.sms.status;
    final contacts = await Permission.contacts.status;
    final notificationListener = await smsReceiverService.isNotificationListenerEnabled();
    
    if (mounted) {
      setState(() {
        _notificationGranted = sms.isGranted && contacts.isGranted && notificationListener;
      });
    }
  }
  
  // This logic is tricky without public access. 
  // I will rely on the user clicking "I did it" for Autostart,
  // and for Notification Access, I'll attempt to check.
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Tr('Setup Detooz Protection'),
        centerTitle: true,
        automaticallyImplyLeading: false, 
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr('To protect you 24/7, Detooz needs 3 permissions.',
              style: AppTypography.bodySmall,
            ),
            SizedBox(height: AppSpacing.xl),

            // Step 1: Notification Access (Critical)
            _buildStepCard(
              index: 1,
              title: tr("Scam Detection Access"),
              description: "Required to read incoming SMS/WhatsApp messages.",
              icon: Icons.notifications_active,
              isDone: _notificationGranted,
              actionLabel: "Grant Access",
              onAction: () async {
                 // Request Standard Permissions first (SMS & Contacts)
                 await [Permission.sms, Permission.contacts].request();
                 
                 // Then Open Notification Listener Settings
                 await smsReceiverService.openNotificationListenerSettings();
                 // Polling happens in didChangeAppLifecycleState
              },
            ),
            
            SizedBox(height: AppSpacing.md),

            // Step 2: Autostart (Xiaomi/Oppo/Vivo)
            _buildStepCard(
              index: 2,
              title: tr("Run in Background"),
              description: "Prevents the system from killing Detooz. Enable 'Autostart'.",
              icon: Icons.flash_on,
              isDone: _autostartDone,
              actionLabel: "Open Settings",
              onAction: () async {
                try {
                  await smsReceiverService.openAutostartSettings();
                } catch (e) {
                  debugPrint('Autostart error: $e');
                } finally {
                  if (mounted) setState(() => _autostartDone = true);
                }
              },
            ),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _notificationGranted ? () {
                  Navigator.of(context).pop(); // Setup done
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: Tr('Start Protecting Me', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int index,
    required String title,
    required String description,
    required IconData icon,
    required bool isDone,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.5) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDone ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              color: isDone ? Colors.green : Colors.white70,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text(description, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                if (!isDone) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary.withOpacity(0.8)),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
