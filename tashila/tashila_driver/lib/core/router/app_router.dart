import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/home/home_shell_screen.dart';
import '../../features/onboarding/driver_onboarding_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../state/driver_app_state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final appState = ref.read(driverAppStateProvider);
      final route = state.matchedLocation;

      if (!appState.bootstrapped) {
        return route == '/splash' ? null : '/splash';
      }

      if (appState.isAuthenticated) {
        if (route == '/onboarding') {
          return appState.needsProfileSetup ? '/profile' : '/home';
        }
        if (appState.needsProfileSetup && route != '/profile') {
          return '/profile';
        }
        if (!appState.needsProfileSetup &&
            (route == '/login' ||
                route == '/otp' ||
                route == '/profile' ||
                route == '/splash' ||
                route == '/onboarding')) {
          return '/home';
        }
        return null;
      }

      if (!appState.seenOnboarding) {
        if (route == '/onboarding') return null;
        return '/onboarding';
      }

      if (route == '/splash' || route == '/onboarding') {
        return '/login';
      }
      if (route == '/login' || route == '/otp') {
        return null;
      }
      if (route == '/profile' || route == '/home' || route == '/earnings') {
        return '/login';
      }
      return '/login';
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const DriverOnboardingScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
    ],
  );

  ref.listen(driverAppStateProvider, (_, state) => router.refresh());
  return router;
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('splash_title'.tr()),
          ],
        ),
      ),
    );
  }
}
