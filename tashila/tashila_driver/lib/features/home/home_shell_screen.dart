import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/state/driver_app_state.dart';
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
      body: tabs[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) {
          if (hasActiveTrip && value != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('active_trip_nav_locked'.tr())),
            );
            return;
          }
          setState(() => currentIndex = value);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map),
            label: 'home_tab'.tr(),
          ),
          NavigationDestination(
            icon: Icon(
              Icons.account_balance_wallet,
              color: hasActiveTrip
                  ? Theme.of(context).disabledColor
                  : null,
            ),
            label: 'earnings_tab'.tr(),
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person,
              color: hasActiveTrip
                  ? Theme.of(context).disabledColor
                  : null,
            ),
            label: 'profile_tab'.tr(),
          ),
        ],
      ),
    );
  }
}
