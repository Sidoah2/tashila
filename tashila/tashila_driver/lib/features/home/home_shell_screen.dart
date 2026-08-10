import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

class _HomeShellScreenState extends ConsumerState<HomeShellScreen>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  bool _gpsAllowed = true;
  bool _checkingGps = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkGpsPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _checkGpsPermission();
    }
  }

  Future<void> _checkGpsPermission() async {
    if (!mounted) return;
    setState(() => _checkingGps = true);
    try {
      final hasService = await Geolocator.isLocationServiceEnabled();
      if (!hasService) {
        if (mounted) {
          setState(() {
            _gpsAllowed = false;
            _checkingGps = false;
          });
        }
        return;
      }
      final permission = await Geolocator.checkPermission();
      final allowed =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (mounted) {
        setState(() {
          _gpsAllowed = allowed;
          _checkingGps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsAllowed = false;
          _checkingGps = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    if (!state.isAuthenticated) {
      return const SizedBox.shrink();
    }
    final ready = state.profile?.isReadyForDashboard ?? false;
    if (!ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/profile');
      });
      return const SizedBox.shrink();
    }

    if (_checkingGps) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandOrange),
        ),
      );
    }

    if (!_gpsAllowed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.location_off_rounded,
                  size: 80,
                  color: AppColors.brandOrange,
                ),
                const SizedBox(height: 24),
                const Text(
                  "يجب تمكين صلاحية الموقع (GPS) لاستخدام التطبيق",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "يسجل التطبيق موقعك لربطك بالرحلات القريبة وتتبع مسارك أثناء الرحلة. يرجى تفعيل الموقع ومنح التطبيق صلاحية الوصول للموقع دائماً أو أثناء استخدام التطبيق.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                    await Geolocator.openLocationSettings();
                    _checkGpsPermission();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "تفعيل الصلاحية / تشغيل GPS",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasActiveTrip = state.hasActiveTrip;
    final tabs = const [
      DriverHomeScreen(),
      EarningsScreen(),
      ProfileSetupScreen(),
    ];

    return Scaffold(
      body: tabs[currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          // margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            // borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.map_outlined,
                selectedIcon: Icons.map_rounded,
                label: 'home_tab'.tr(),
                hasActiveTrip: hasActiveTrip,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'earnings_tab'.tr(),
                hasActiveTrip: hasActiveTrip,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'profile_tab'.tr(),
                hasActiveTrip: hasActiveTrip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool hasActiveTrip,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.brandOrange;
    final inactiveColor = Colors.grey.shade500;

    return InkWell(
      onTap: () {
        if (hasActiveTrip && index != 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('active_trip_nav_locked'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        setState(() => currentIndex = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? activeColor
                  : (hasActiveTrip && index != 0
                        ? Colors.grey.shade300
                        : inactiveColor),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (hasActiveTrip && index != 0
                          ? Colors.grey.shade300
                          : inactiveColor),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
