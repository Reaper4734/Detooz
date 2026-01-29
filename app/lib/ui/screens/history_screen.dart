import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import 'scan_detail_screen.dart';
import '../components/tr.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  RiskLevel? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when translations are loaded
    ref.watch(languageProvider);
    
    final allScans = ref.watch(scanHistoryProvider);
    final filteredScans = _filter == null
        ? allScans
        : allScans.where((s) => s.riskLevel == _filter).toList();

    // Group scans by date
    final groupedScans = _groupScansByDate(filteredScans);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tr('Scan History',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildIconButton(Icons.search),
                ],
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    SizedBox(width: 12),
                    _buildFilterChip('High Risk', RiskLevel.high),
                    SizedBox(width: 12),
                    _buildFilterChip('Medium Risk', RiskLevel.medium),
                    SizedBox(width: 12),
                    _buildFilterChip('Safe', RiskLevel.low),
                  ],
                ),
              ),
            ),

            // Content List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceDark,
                onRefresh: () async {
                  await ref.read(scansProvider.notifier).loadScans();
                },
                child: groupedScans.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: groupedScans.length,
                        itemBuilder: (context, index) {
                          final group = groupedScans[index];
                          return _buildDateSection(group);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceDark.withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
    );
  }

  Widget _buildFilterChip(String label, RiskLevel? level) {
    final isSelected = _filter == level;
    return GestureDetector(
      onTap: () => setState(() => _filter = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.borderDark,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          tr(label),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondaryDark,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection(_DateGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Text(
            group.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryDark.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
        ),
        // Scan Items
        ...group.scans.map((scan) => _buildScanCard(scan)),
      ],
    );
  }

  Widget _buildScanCard(ScanViewModel scan) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScanDetailScreen(scan: scan)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            // Icon Container
            _buildScanIcon(scan),
            SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scan.senderNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildRiskBadge(scan.riskLevel),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    scan.messagePreview,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanIcon(ScanViewModel scan) {
    final IconData icon;
    switch (scan.platform) {
      case PlatformType.sms:
        icon = Icons.sms_outlined;
        break;
      case PlatformType.whatsapp:
        icon = Icons.mark_email_unread_outlined;
        break;
      case PlatformType.telegram:
        icon = Icons.send_outlined;
        break;
    }

    final bool showIndicator = scan.riskLevel == RiskLevel.high || scan.riskLevel == RiskLevel.medium;
    final Color indicatorColor = scan.riskLevel == RiskLevel.high
        ? AppColors.riskHigh
        : AppColors.riskMedium;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        if (showIndicator)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.backgroundDark, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRiskBadge(RiskLevel level) {
    final String label;
    final Color color;

    switch (level) {
      case RiskLevel.high:
        label = 'HIGH RISK';
        color = AppColors.riskHigh;
        break;
      case RiskLevel.medium:
        label = 'MEDIUM';
        color = AppColors.riskMedium;
        break;
      case RiskLevel.low:
        label = 'SAFE';
        color = AppColors.riskLow;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: AppColors.textSecondaryDark.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Tr('No scan history',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Tr('Your scanned items will appear here',
            style: TextStyle(
              color: AppColors.textSecondaryDark.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<_DateGroup> _groupScansByDate(List<ScanViewModel> scans) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_DateGroup>[];
    final Map<String, List<ScanViewModel>> olderGroups = {};
    final todayScans = <ScanViewModel>[];
    final yesterdayScans = <ScanViewModel>[];

    for (var scan in scans) {
      final scanDate = DateTime(scan.scannedAt.year, scan.scannedAt.month, scan.scannedAt.day);
      if (scanDate == today) {
        todayScans.add(scan);
      } else if (scanDate == yesterday) {
        yesterdayScans.add(scan);
      } else {
        // Format older dates as "MONTH DAY" (e.g., "JULY 12")
        final months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
                        'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
        final label = '${months[scanDate.month - 1]} ${scanDate.day}';
        olderGroups.putIfAbsent(label, () => []).add(scan);
      }
    }

    if (todayScans.isNotEmpty) groups.add(_DateGroup('TODAY', todayScans));
    if (yesterdayScans.isNotEmpty) groups.add(_DateGroup('YESTERDAY', yesterdayScans));
    olderGroups.forEach((label, scans) {
      groups.add(_DateGroup(label, scans));
    });

    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<ScanViewModel> scans;
  _DateGroup(this.label, this.scans);
}
