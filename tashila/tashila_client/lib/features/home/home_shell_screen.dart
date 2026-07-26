import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/features/history/history_screen.dart';
import 'package:tashila_client/features/map_booking/booking_screen.dart';
import 'package:tashila_client/features/profile_settings/profile_settings_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int currentIndex = 0;

  Widget _navItem(
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
  ) {
    final selected = currentIndex == index;
    final color = selected
        ? AppColors.brandOrange
        : AppColors.textSecondary.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: () => setState(() => currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              selected ? activeIcon : inactiveIcon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 10.5,
              height: 1.1,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 14 : 0,
            decoration: BoxDecoration(
              color: AppColors.brandOrange,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      BookingScreen(),
      HistoryScreen(),
      ProfileSettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: tabs[currentIndex]),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.03),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(
                    0,
                    Icons.explore_outlined,
                    Icons.explore,
                    'book'.tr(),
                  ),
                  _navItem(
                    1,
                    Icons.history_toggle_off_rounded,
                    Icons.history_rounded,
                    'history'.tr(),
                  ),
                  _navItem(
                    2,
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                    'profile'.tr(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
