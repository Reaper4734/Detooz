import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tr.dart';
import '../providers.dart';

class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch language provider to rebuild when language changes
    ref.watch(languageProvider);
    
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.dashboard_outlined),
          activeIcon: const Icon(Icons.dashboard),
          label: tr('Home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.history),
          label: tr('History'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.shield_outlined),
          activeIcon: const Icon(Icons.shield),
          label: tr('Guardians'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.school_outlined),
          activeIcon: const Icon(Icons.school),
          label: tr('Learn'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          activeIcon: const Icon(Icons.settings),
          label: tr('Settings'),
        ),
      ],
    );
  }
}
