import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../components/scan_card.dart';
import '../providers.dart';
import 'scan_detail_screen.dart';
import 'manual_result_screen.dart';
import 'settings_screen.dart';
import '../components/scam_alert_overlay.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _manualCheckController = TextEditingController();
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _manualCheckController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      setState(() => _isAnalyzing = true);
      
      final scan = await ref.read(scansProvider.notifier).analyzeImage(File(image.path));
      
      // Refresh stats
      ref.read(userStatsProvider.notifier).loadStats();
      
      setState(() => _isAnalyzing = false);
      
      if (scan != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScanDetailScreen(scan: scan)),
          );
      }
    } catch (e) {
       setState(() => _isAnalyzing = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Image analysis failed: $e'), backgroundColor: AppColors.danger),
         );
       }
    }
  }

  Future<void> _analyzeManualInput() async {
    final text = _manualCheckController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    
    final scan = await ref.read(scansProvider.notifier).manualScan(text);
    
    // Refresh stats
    ref.read(userStatsProvider.notifier).loadStats();
    
    setState(() => _isAnalyzing = false);
    _manualCheckController.clear();
    
    if (scan != null && mounted) {
      // Navigate directly - no overlay needed for manual check
      
      // Navigate to appropriate screen
      if (scan.sender.startsWith('Manual')) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManualResultScreen(scan: scan)),
          );
      } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScanDetailScreen(scan: scan)),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentScans = ref.watch(recentScansProvider);
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScamShield'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(scansProvider.notifier).loadScans(),
            ref.read(userStatsProvider.notifier).loadStats(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card: Protection Active
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B3D20), Color(0xFF101922)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // TODO: Background pattern/image overlay if needed
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF15803D), Color(0xFF14532D)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      boxShadow: [
                                        BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 15)
                                      ]
                                    ),
                                    child: const Icon(Icons.verified_user, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Protection Active', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text('System is online & scanning', style: TextStyle(color: Colors.green[200]!.withOpacity(0.8), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red[900]!.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning, size: 14, color: Colors.red[200]),
                                    const SizedBox(width: 4),
                                    statsAsync.when(
                                      data: (stats) => Text('${stats.highRiskBlocked} HIGH RISK DETECTED', style: TextStyle(color: Colors.red[200], fontSize: 10, fontWeight: FontWeight.bold)),
                                      loading: () => Text('... HIGH RISK', style: TextStyle(color: Colors.red[200], fontSize: 10, fontWeight: FontWeight.bold)),
                                      error: (_, __) => Text('0 HIGH RISK', style: TextStyle(color: Colors.red[200], fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Content (Counter)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              statsAsync.when(
                                data: (stats) => Text('${stats.totalScans}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                loading: () => const Text('...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                error: (_, __) => const Text('0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              Text('SCANNED', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Manual Check
            Text('Manual Check', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                      IconButton(
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        onPressed: _pickImage,
                        color: Colors.grey,
                      ),
                  Expanded(
                    child: TextField(
                      controller: _manualCheckController,
                      decoration: const InputDecoration(
                        hintText: 'Check text, URL, or number...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                      onSubmitted: (_) => _analyzeManualInput(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ]
                    ),
                    child: _isAnalyzing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_upward, color: Colors.white),
                            onPressed: _analyzeManualInput,
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('Analyze screenshots, SMS text, or suspicious URLs instantly.', style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.grey)),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Recent Activity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity', style: AppTypography.h3),
                TextButton(
                  onPressed: () {
                    // Navigate to history tab via MainScreen logic if possible, or push screen
                    // For now simple push
                  }, 
                  child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentScans.length,
              itemBuilder: (context, index) {
                return ScanCard(
                  scan: recentScans[index],
                  onTap: () {
                    if (recentScans[index].sender.startsWith('Manual')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ManualResultScreen(scan: recentScans[index])),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ScanDetailScreen(scan: recentScans[index])),
                      );
                    }
                  },
                );
              },
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Safety Tips
            Text('Safety Tips', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTipCard(
                    icon: Icons.lightbulb,
                    title: 'TIP OF THE DAY',
                    message: 'Never share your 2FA codes with anyone, even if they claim to be support.',
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _buildTipCard(
                    icon: Icons.lock,
                    title: 'SECURITY',
                    message: 'Enable biometric login for an extra layer of protection.',
                    color: Theme.of(context).cardColor,
                    textColor: Theme.of(context).textTheme.bodyMedium!.color!,
                    iconColor: AppColors.primary,
                    borderColor: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        ), // SingleChildScrollView
      ), // RefreshIndicator
    ); // Scaffold
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String message,
    Color? color,
    Gradient? gradient,
    required Color textColor,
    Color? iconColor,
    Color? borderColor,
  }) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor ?? textColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: (iconColor ?? textColor).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
