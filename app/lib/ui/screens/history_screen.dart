import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../contracts/risk_level.dart';
import '../../contracts/scan_view_model.dart';
import '../theme/app_colors.dart';
import '../providers.dart';
import 'scan_detail_screen.dart';
import '../components/tr.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  RiskLevel? _filter; // null = All
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        ref.read(scansProvider.notifier).loadScans();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    
    final allScans = ref.watch(scanHistoryProvider);
    final filteredScans = allScans.where((s) {
      if (_filter != null && s.riskLevel != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = s.sender.toLowerCase().contains(query);
        final matchesNumber = s.senderNumber.toLowerCase().contains(query);
        final matchesPreview = s.messagePreview.toLowerCase().contains(query);
        if (!matchesName && !matchesNumber && !matchesPreview) return false;
      }
      return true;
    }).toList();

    final groupedScans = _groupScansByDate(filteredScans);
    final scale = MediaQuery.of(context).size.width / 375.0;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 24 * scale, 20 * scale, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SCAN HISTORY',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<String>(
                          position: PopupMenuPosition.under,
                          color: AppColors.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: AppColors.divider(context), width: 1),
                          ),
                          offset: const Offset(0, 8),
                          padding: EdgeInsets.zero,
                          child: Container(
                            width: 32 * scale,
                            height: 32 * scale,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(Icons.more_vert, color: Colors.black, size: 20 * scale),
                          ),
                          onSelected: (value) {
                            if (value == 'clear') {
                              ref.read(scansProvider.notifier).clearAllScans();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'clear',
                              height: 40 * scale,
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: AppColors.danger, size: 18 * scale),
                                  SizedBox(width: 8 * scale),
                                  Text(
                                    'CLEAR ALL MESSAGES',
                                    style: TextStyle(
                                      fontFamily: 'IntegralCF',
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.danger,
                                      fontSize: 11 * scale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44 * scale,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: AppColors.primary, width: 2),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13 * scale),
                            decoration: InputDecoration(
                              hintText: tr('Search by name, number, risk...'),
                              hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 44 * scale,
                        width: 44 * scale,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(Icons.search, color: Colors.black),
                      ),
                    ],
                  ),
                  SizedBox(height: 24 * scale),
                  // Dynamic 2x2 Filter Grid using Row/Expanded
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(6 * scale),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      border: Border.all(color: AppColors.divider(context), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildGridChip('ALL', null, scale)),
                            SizedBox(width: 6 * scale),
                            Expanded(child: _buildGridChip('HIGH RISK', RiskLevel.high, scale)),
                          ],
                        ),
                        SizedBox(height: 6 * scale),
                        Row(
                          children: [
                            Expanded(child: _buildGridChip('MEDIUM RISK', RiskLevel.medium, scale)),
                            SizedBox(width: 6 * scale),
                            Expanded(child: _buildGridChip('SAFE', RiskLevel.low, scale)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24 * scale),

            // Content List
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface(context),
                onRefresh: () async {
                  await ref.read(scansProvider.notifier).loadScans();
                },
                child: groupedScans.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 140 * scale),
                        itemCount: groupedScans.length,
                        itemBuilder: (context, index) {
                          final group = groupedScans[index];
                          return _buildDateSection(group, scale);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridChip(String label, RiskLevel? level, double scale) {
    final isSelected = _filter == level;
    final Color activeColor;
    if (level == RiskLevel.high) activeColor = AppColors.danger;
    else if (level == RiskLevel.medium) activeColor = AppColors.warning;
    else if (level == RiskLevel.low) activeColor = AppColors.success;
    else activeColor = AppColors.primary;

    return GestureDetector(
      onTap: () => setState(() => _filter = level),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          border: Border.all(color: isSelected ? activeColor : AppColors.divider(context)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IntegralCF',
              fontSize: 11 * scale,
              fontWeight: FontWeight.w900,
              color: isSelected && level != null && level != RiskLevel.low ? Colors.black : (isSelected ? Colors.black : AppColors.textPrimary(context)),
              letterSpacing: 0.5,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection(_DateGroup group, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 16 * scale, bottom: 16 * scale),
          child: Text(
            group.label,
            style: TextStyle(
              fontFamily: 'IntegralCF',
              fontSize: 12 * scale,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...group.scans.map((scan) => _buildScanCard(scan, scale)),
      ],
    );
  }

  Widget _buildScanCard(ScanViewModel scan, double scale) {
    Widget platformIconWidget;
    if (scan.sender.startsWith('Manual')) {
      platformIconWidget = Icon(
        Icons.search,
        color: AppColors.textPrimary(context),
        size: 16 * scale,
      );
    } else {
      switch (scan.platform) {
        case PlatformType.whatsapp:
          platformIconWidget = FaIcon(FontAwesomeIcons.whatsapp,
              color: AppColors.textPrimary(context), size: 18 * scale);
          break;
        case PlatformType.telegram:
          platformIconWidget = FaIcon(FontAwesomeIcons.telegram,
              color: AppColors.textPrimary(context), size: 18 * scale);
          break;
        case PlatformType.sms:
        default:
          platformIconWidget = Icon(Icons.sms_rounded,
              color: AppColors.textPrimary(context), size: 18 * scale);
          break;
      }
    }

    Color riskColor;
    if (scan.riskLevel == RiskLevel.high) riskColor = AppColors.danger;
    else if (scan.riskLevel == RiskLevel.medium) riskColor = AppColors.warning;
    else riskColor = AppColors.success;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScanDetailScreen(scan: scan)),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider(context))),
        ),
        child: Row(
          children: [
            Container(
              width: 34 * scale,
              height: 34 * scale,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border.all(color: AppColors.divider(context)),
              ),
              child: Center(
                child: platformIconWidget,
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.senderNumber.isNotEmpty ? scan.senderNumber : 'Unlabeled Scan',
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * scale),
                  Row(
                    children: [
                      Container(width: 6 * scale, height: 6 * scale, decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle)),
                      SizedBox(width: 6 * scale),
                      Expanded(
                        child: Text(
                          scan.messagePreview.replaceAll('\n', ' '),
                          style: TextStyle(fontSize: 11 * scale, color: AppColors.textSecondary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8 * scale),
            Text(
              DateFormat('h:mm a').format(scan.scannedAt.toLocal()),
              style: TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w500, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_sharp, size: 80, color: Colors.white24),
          const SizedBox(height: 24),
          Text(
            'NO SCAN HISTORY',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
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
      final localScanDate = scan.scannedAt.toLocal();
      final scanDate = DateTime(localScanDate.year, localScanDate.month, localScanDate.day);
      
      if (scanDate == today) {
        todayScans.add(scan);
      } else if (scanDate == yesterday) {
        yesterdayScans.add(scan);
      } else {
        final label = DateFormat('dd/MM/yy').format(localScanDate);
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
