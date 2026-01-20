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
import '../../contracts/scan_view_model.dart';
import '../../contracts/risk_level.dart';

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
      
      final scan = await ref.read(scansProvider.notifier).analyzeImage(image);
      
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

    return Scaffold(
      backgroundColor: Colors.black, // Dark background as per design
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good Morning, Alex',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay safe today',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAFyYFn2y2xT2u1p2ca8CuBuFmN6pCxEh5GKQz-Z7lNJrFr9NjWypYQzNRUQJuSmO_tcKaMlFuFsTdJ_rATPtwzwbWdJLNsedzejOy9KnNkQ_PagQALkBqKew-GcL5Ua7pWGtoG_lxcJtLmCd9zNgjAYfEpGkQmCTGveko90Y5c5uB3OTd_0zPNsaJGuH0iuqVyJYOTz1eJ-zydGV4dMNgsljHiVVe3HjDJrwTWFsFFhVtWgku-U-zYU5UYCD1n4euAK7NeKJjoIXbw'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Protection Active Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: const Color(0xFF141416), // Surface dark
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Gradient overlay
                    Positioned(
                      top: 0,
                      right: 0,
                      left: 0,
                      height: 200,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Card Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E24), // Slightly lighter
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: const Icon(Icons.security, color: AppColors.primary, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Protection Active',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color:  Color(0xFF10B981), // Success
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: Color(0xFF10B981), blurRadius: 8), 
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Monitoring active',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Icon(Icons.more_horiz, color: Colors.grey[600]),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Metrics Grid
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E24).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Items Scanned',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '142', // Static
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E24).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'High Risk Blocked',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            '12', // Static
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              'Total today',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 36),
              
              // Manual Check
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Manual Check',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(100), // Pill shape
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey[600], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _manualCheckController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Check text, URL, or number',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _analyzeManualInput(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.camera_alt_outlined, color: Colors.grey[400]),
                      onPressed: _pickImage, // Kept functional
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isAnalyzing ? null : _analyzeManualInput,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _isAnalyzing 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 36),
              
              // Recent Scans
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Recent Scans',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {}, // View All
                    child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Dynamic List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentScans.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildScanItem(context, recentScans[index]);
                },
              ),
              
              // Spacing for bottom nav not needed if using standard Scaffold bottomNavigationBar or floating, 
              // but design shows spacing.
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildScanItem(BuildContext context, ScanViewModel scan) {
    // LOGIC: Map ScanViewModel to UI
    final RiskLevel risk = scan.riskLevel;
    
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (risk) {
      case RiskLevel.high:
        statusColor = const Color(0xFFEF4444); // Red
        statusText = 'RISK';
        statusIcon = Icons.warning;
        break;
      case RiskLevel.medium:
        statusColor = const Color(0xFFEAB308); // Yellow
        statusText = 'CAUTION';
        statusIcon = Icons.info;
        break;
      case RiskLevel.low:
        statusColor = const Color(0xFF10B981); // Green
        statusText = 'SAFE';
        statusIcon = Icons.verified_user;
        break;
    }
    
    Color badgeBg = statusColor.withOpacity(0.1);
    Color badgeBorder = statusColor.withOpacity(0.2);

    // Platform Icon logic
    IconData platformIcon;
    switch (scan.platform) {
      case PlatformType.whatsapp:
        platformIcon = Icons.chat;
        break;
      case PlatformType.telegram:
        platformIcon = Icons.telegram;
        break;
      case PlatformType.sms:
      default:
        platformIcon = Icons.sms;
        break;
    }
    
    // Time logic
    final now = DateTime.now();
    final diff = now.difference(scan.scannedAt);
    String timeAgo = '';
    if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () {
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
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Icon(platformIcon, color: risk == RiskLevel.low ? const Color(0xFF10B981) : (risk == RiskLevel.high ? const Color(0xFFEF4444) : const Color(0xFFEAB308)), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          scan.sender,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scan.messagePreview.replaceAll('\n', ' '),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: badgeBorder),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
