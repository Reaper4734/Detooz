import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../providers.dart';
import '../components/scan_card.dart';
import 'scan_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  RiskLevel? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final allScans = ref.watch(scanHistoryProvider);
    final filteredScans = _filter == null 
        ? allScans 
        : allScans.where((s) => s.riskLevel == _filter).toList();
    
    // Group scans by date
    final groupedScans = _groupScansByDate(filteredScans);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scan History', style: AppTypography.h1),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.filter_list, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
            
            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _buildFilterTab('All', null),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterTab('High Risk', RiskLevel.high),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterTab('Medium Risk', RiskLevel.medium),
                  const SizedBox(width: AppSpacing.sm),
                  _buildFilterTab('Safe', RiskLevel.low),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            
            // List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: groupedScans.length,
                itemBuilder: (context, index) {
                  final group = groupedScans[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sticky Header style
                      Container(
                         padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                         color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                         width: double.infinity,
                         child: Text(
                           group.label,
                           style: const TextStyle(
                             fontSize: 12, 
                             fontWeight: FontWeight.bold, 
                             color: AppColors.textSecondaryLight,
                             letterSpacing: 1,
                           ),
                         ),
                      ),
                      ...group.scans.map((scan) => ScanCard(
                        scan: scan,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ScanDetailScreen(scan: scan)),
                          );
                        },
                      )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, RiskLevel? level) {
    final isSelected = _filter == level;
    return GestureDetector(
      onTap: () => setState(() => _filter = level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
             color: isSelected ? AppColors.primary : Theme.of(context).dividerColor.withOpacity(0.2),
          ),
          boxShadow: isSelected 
             ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
             : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<_DateGroup> _groupScansByDate(List<ScanViewModel> scans) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_DateGroup>[];
    final todayScans = <ScanViewModel>[];
    final yesterdayScans = <ScanViewModel>[];
    final olderScans = <ScanViewModel>[];

    for (var scan in scans) {
      final scanDate = DateTime(scan.scannedAt.year, scan.scannedAt.month, scan.scannedAt.day);
      if (scanDate == today) {
        todayScans.add(scan);
      } else if (scanDate == yesterday) {
        yesterdayScans.add(scan);
      } else {
        olderScans.add(scan);
      }
    }

    if (todayScans.isNotEmpty) groups.add(_DateGroup('TODAY', todayScans));
    if (yesterdayScans.isNotEmpty) groups.add(_DateGroup('YESTERDAY', yesterdayScans));
    if (olderScans.isNotEmpty) groups.add(_DateGroup('OLDER', olderScans));

    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<ScanViewModel> scans;
  _DateGroup(this.label, this.scans);
}
