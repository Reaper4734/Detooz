import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tr.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/responsive_utils.dart';

/// Bottom navigation bar — floating, brutalism-inspired, responsive
class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.home_outlined,
    Icons.history,
    Icons.shield_outlined,
    Icons.school_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch language provider to rebuild when language changes
    ref.watch(languageProvider);
    Responsive.init(context);

    final labels = [
      tr('HOME'),
      tr('HISTORY'),
      tr('GUARDIANS'),
      tr('LEARN'),
      tr('SETTINGS')
    ];

    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Center(
        child: Container(
          width: screenWidth * 0.9,
          margin: EdgeInsets.only(bottom: Responsive.sp(14)),
          padding: EdgeInsets.symmetric(vertical: Responsive.sp(10)),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: AppColors.border(context), width: 2),
            borderRadius: BorderRadius.circular(Responsive.sp(16)),
            boxShadow: AppColors.brutalCardShadow(context),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(labels.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[i],
                        size: Responsive.sp(22),
                        color: isActive ? AppColors.primary : AppColors.textSecondary(context),
                      ),
                      SizedBox(height: Responsive.sp(3)),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: Responsive.sp(8),
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.primary : AppColors.textSecondary(context),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
