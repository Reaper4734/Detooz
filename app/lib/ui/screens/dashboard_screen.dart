import 'dart:ui';
import 'dart:async'; // Added
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; 
import '../../utils/datetime_utils.dart'; // Added
import '../theme/app_colors.dart';
import '../providers.dart';
import 'scan_detail_screen.dart';
import 'manual_result_screen.dart';
import '../../contracts/scan_view_model.dart';
import '../../contracts/risk_level.dart';

import 'package:image_picker/image_picker.dart';
import '../components/tr.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  // Animation constants
  final Duration pauseDuration = const Duration(seconds: 2);
  final Duration animationDuration = const Duration(seconds: 4);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _manualCheckController = TextEditingController();
  bool _isAnalyzing = false;
  final ImagePicker _picker = ImagePicker();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        ref.read(scansProvider.notifier).loadScans();
        ref.read(userStatsProvider.notifier).loadStats();
      }
    });
    
    // Existing PostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(scansProvider.notifier).loadScans();
      ref.read(userStatsProvider.notifier).loadStats();
      ref.read(guardiansProvider.notifier).loadGuardians();
      ref.read(userProfileProvider.notifier).loadProfile();
      ref.read(userSettingsProvider.notifier).loadSettings();
      ref.read(trustedSendersProvider.notifier).loadTrustedSenders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
            MaterialPageRoute(builder: (_) => ManualResultScreen(scan: scan, isCloudAnalysis: true)),
          );
      }
    } catch (e) {
       setState(() => _isAnalyzing = false);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Tr('Image analysis failed: $e'), backgroundColor: AppColors.danger),
         );
       }
    }
  }

  Future<void> _analyzeManualInput() async {
    final text = _manualCheckController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAnalyzing = true);
    
    try {
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
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tr('Scan failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentScans = ref.watch(recentScansProvider);
    final userStats = ref.watch(userStatsProvider);
    final userProfile = ref.watch(userProfileProvider);
    
    // Greeting Logic
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // True Black styling
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          onRefresh: () async {
            await ref.read(scansProvider.notifier).loadScans();
            await ref.read(userStatsProvider.notifier).loadStats();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Tr('$greeting, ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userProfile.hasValue)
                              Flexible(
                                child: _MarqueeText(
                                  text: userProfile.value!.name.split(' ').first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Tr('Stay safe today',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
              
              SizedBox(height: 32),
              
              // Protection Active Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: AppColors.surfaceDark.withOpacity(0.8), // Zinc Glass
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                                          border: Border.all(color: AppColors.borderDark),
                                        ),
                                        child: const Icon(Icons.security, color: AppColors.primary, size: 24),
                                      ),
                                      SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Tr('Protection Active',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.success,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(color: AppColors.success, blurRadius: 8), 
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Tr('Monitoring active',
                                                style: TextStyle(
                                                  color: AppColors.success,
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
                          
                          SizedBox(height: 24),
                          
                          // Metrics Grid
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2), // Darker inset
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.borderDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Tr('Items Scanned',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        userStats.isLoading ? '-' : '${userStats.value?.totalScans ?? 0}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.borderDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Tr('High Risk Blocked',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            userStats.isLoading ? '-' : '${userStats.value?.highRiskBlocked ?? 0}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Tr('Today',
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
                ),
              ),
              
              SizedBox(height: 36),
              
              // Manual Check
              Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Tr('Manual Check',
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
                    SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey[600], size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _manualCheckController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: tr('Check text, URL, or number'),
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _analyzeManualInput(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.camera_alt_outlined, color: Colors.grey[400]),
                      onPressed: _pickImage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 12),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGlow.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
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
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Tr('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 36),
              
              // Recent Scans
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Tr('Recent Scans',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {}, // View All
                    child: Tr('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Dynamic List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentScans.length,
                separatorBuilder: (context, index) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildScanItem(context, recentScans[index]);
                },
              ),
              
              SizedBox(height: 100),
            ],
          ),
        ),
        ), // Close RefreshIndicator
      ),
    );
  }

  Widget _buildScanItem(BuildContext context, ScanViewModel scan) {
    // LOGIC: Map ScanViewModel to UI
    final RiskLevel risk = scan.riskLevel;
    
    Color statusColor;
    IconData statusIcon;

    switch (risk) {
      case RiskLevel.high:
        statusColor = const Color(0xFFF87171); // Red-400
        statusIcon = Icons.gpp_bad_outlined;
         break;
      case RiskLevel.medium:
        statusColor = const Color(0xFFFBBF24); // Amber-400
        statusIcon = Icons.warning_amber_rounded;
        break;
      case RiskLevel.low:
        statusColor = const Color(0xFF34D399); // Emerald-400
        statusIcon = Icons.verified_user_outlined;
        break;
    }

    // Platform Icon logic
    IconData platformIcon;
    switch (scan.platform) {
      case PlatformType.whatsapp:
        platformIcon = Icons.chat_bubble_outline;
        break;
      case PlatformType.telegram:
        platformIcon = Icons.send;
        break;
      case PlatformType.sms:
      default:
        platformIcon = Icons.message_outlined;
        break;
    }
    
    // Time logic using DateTimeUtils
    final timeAgo = DateTimeUtils.formatSmartDate(scan.scannedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B).withOpacity(0.8), // Zinc-900 Glass
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A), // Zinc-800
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Icon(
                platformIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Content
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                            color: Color(0xFFA1A1AA), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scan.messagePreview.replaceAll('\n', ' '),
                          style: const TextStyle(
                            color: Color(0xFFD4D4D8), // Zinc-300
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;
  final Duration animationDuration;

  const _MarqueeText({
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(seconds: 1),
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() async {
    if (!mounted) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;
      
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: widget.animationDuration,
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}
