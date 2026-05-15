import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sms_receiver_service.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';

import 'package:permission_handler/permission_handler.dart';
import '../components/tr.dart';
import 'setup_offline_protection_screen.dart';

class PermissionWizardScreen extends StatefulWidget {
  const PermissionWizardScreen({super.key});

  @override
  State<PermissionWizardScreen> createState() => _PermissionWizardScreenState();
}

class _PermissionWizardScreenState extends State<PermissionWizardScreen> with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _autostartDone = false;
  bool _offlineSetupDone = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('offline_setup_done') ?? false;
    if (mounted) setState(() => _offlineSetupDone = done);
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
  
  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.sp(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: Responsive.sp(12)),
                    // ─── Header ───
                    Text(
                      'SETUP',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(36),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: -1,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      'DETOOZ',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(36),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: -1,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: Responsive.sp(12)),
                    Tr(
                      'To protect you 24/7, Detooz needs system permissions to operate successfully.',
                      style: TextStyle(
                        fontSize: Responsive.sp(14),
                        color: AppColors.textSecondary(context),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: Responsive.sp(40)),

                    // ─── Step 1: Notification Access ───
                    _buildStepCard(
                      index: 1,
                      title: tr("SCAM DETECTION ACCESS"),
                      description: tr("Required to read incoming SMS/WhatsApp messages independently."),
                      icon: Icons.notifications_active,
                      isDone: _notificationGranted,
                      actionLabel: "GRANT ACCESS",
                      onAction: () async {
                         await [Permission.sms, Permission.contacts].request();
                         await smsReceiverService.openNotificationListenerSettings();
                      },
                    ),
                    
                    SizedBox(height: Responsive.sp(20)),

                    // ─── Step 2: App Installation Shield (Informational) ───
                    _buildStepCard(
                      index: 2,
                      title: tr("APP INSTALL SHIELD"),
                      description: tr("Automatically scans sideloaded apps and APKs for malware. (Permission granted on install)."),
                      icon: Icons.shield,
                      isDone: true,
                      actionLabel: "",
                      onAction: () {},
                    ),
                    
                    SizedBox(height: Responsive.sp(20)),

                    // ─── Step 3: Autostart (Xiaomi/Oppo/Vivo) ───
                    _buildStepCard(
                      index: 3,
                      title: tr("RUN IN BACKGROUND"),
                      description: tr("Prevents the system from killing Detooz. Enable 'Autostart'."),
                      icon: Icons.flash_on,
                      isDone: _autostartDone,
                      actionLabel: "OPEN SETTINGS",
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
                  ],
                ),
              ),
            ),
            
            // ─── Continue Button ───
            Padding(
              padding: EdgeInsets.fromLTRB(Responsive.sp(24), 0, Responsive.sp(24), Responsive.sp(16)),
              child: GestureDetector(
                onTap: _notificationGranted ? () async {
                  if (!_offlineSetupDone) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('offline_setup_done', true);
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SetupOfflineProtectionScreen(
                          onComplete: (setupContext) {
                            Navigator.of(setupContext).popUntil((route) => route.isFirst);
                          },
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).pop();
                  }
                } : null,
                child: Container(
                  width: double.infinity,
                  height: Responsive.h(56),
                  decoration: BoxDecoration(
                    color: _notificationGranted ? AppColors.primary : AppColors.divider(context),
                    boxShadow: _notificationGranted 
                        ? const [BoxShadow(offset: Offset(4, 4), color: Colors.black)]
                        : [],
                    border: Border.all(
                      color: _notificationGranted ? Colors.transparent : AppColors.textSecondary(context).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'START PROTECTING ME',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(16),
                        fontWeight: FontWeight.w700,
                        color: _notificationGranted ? Colors.black : AppColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
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
      padding: EdgeInsets.all(Responsive.sp(16)),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border.all(
          color: isDone ? AppColors.success : AppColors.textPrimary(context),
          width: 2,
        ),
        boxShadow: [
          if (!isDone) const BoxShadow(offset: Offset(4, 4), color: Colors.black)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Responsive.sp(36),
                height: Responsive.sp(36),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : AppColors.background(context),
                  border: Border.all(color: isDone ? AppColors.success : AppColors.textPrimary(context), width: 2),
                ),
                child: Center(
                  child: Icon(
                    isDone ? Icons.check : icon,
                    color: isDone ? Colors.white : AppColors.textPrimary(context),
                    size: Responsive.sp(18),
                  ),
                ),
              ),
              SizedBox(width: Responsive.sp(16)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IntegralCF',
                    fontSize: Responsive.sp(14),
                    fontWeight: FontWeight.w700,
                    color: isDone ? AppColors.success : AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.sp(12)),
          Text(
            description,
            style: TextStyle(
              fontSize: Responsive.sp(13),
              color: AppColors.textSecondary(context),
              height: 1.4,
            ),
          ),
          if (!isDone) ...[
            SizedBox(height: Responsive.sp(16)),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: Responsive.sp(10), horizontal: Responsive.sp(16)),
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: Responsive.sp(11),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: Responsive.sp(8)),
                    Icon(Icons.arrow_forward, color: Colors.white, size: Responsive.sp(14)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
