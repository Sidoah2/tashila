import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../earnings/earnings_screen.dart';
import '../profile/profile_setup_screen.dart';
import 'driver_home_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int currentIndex = 0;

  Widget _navItem(
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
    bool hasActiveTrip,
  ) {
    final selected = currentIndex == index;
    final disabled = hasActiveTrip && index != 0;
    final color = selected
        ? AppColors.brandOrange
        : (disabled
            ? Colors.grey.shade300
            : AppColors.textSecondary.withValues(alpha: 0.55));
    return GestureDetector(
      onTap: disabled
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('active_trip_nav_locked'.tr())),
              );
            }
          : () => setState(() => currentIndex = index),
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
    final state = ref.watch(driverAppStateProvider);
    final ready = state.profile?.isReadyForDashboard ?? false;
    if (!ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/profile');
      });
      return const SizedBox.shrink();
    }
    final hasActiveTrip = state.hasActiveTrip;
    final tabs = const [
      DriverHomeScreen(),
      EarningsScreen(),
      ProfileSetupScreen(),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navItem(
                        0,
                        Icons.map_outlined,
                        Icons.map,
                        'home_tab'.tr(),
                        hasActiveTrip,
                      ),
                      _navItem(
                        1,
                        Icons.account_balance_wallet_outlined,
                        Icons.account_balance_wallet,
                        'earnings_tab'.tr(),
                        hasActiveTrip,
                      ),
                      _navItem(
                        2,
                        Icons.person_outline_rounded,
                        Icons.person_rounded,
                        'profile_tab'.tr(),
                        hasActiveTrip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

