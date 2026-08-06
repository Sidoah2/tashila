import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/earnings/earnings_screen.dart';
import '../../features/home/home_shell_screen.dart';
import '../../features/home/rate_client_screen.dart';
import '../../features/legal/privacy_policy_screen.dart';
import '../../features/legal/terms_conditions_screen.dart';
import '../../features/onboarding/driver_onboarding_screen.dart';
import '../../features/orders/driver_orders_screen.dart';
import '../../features/profile/driver_profile_edit_screen.dart';
import '../../features/profile/driver_profile_view_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/settings/language_screen.dart';
import '../../features/support/driver_support_screen.dart';
import '../state/driver_app_state.dart';
import '../theme/app_colors.dart';

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
        path: '/profile-view',
        builder: (context, state) => const DriverProfileViewScreen(),
      ),
      GoRoute(
        path: '/profile-edit',
        builder: (context, state) => const DriverProfileEditScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const DriverSupportScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const DriverOrdersScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),

      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/rate-client',
        builder: (context, state) => const RateClientScreen(),
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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/arabic_logo.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brandOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
