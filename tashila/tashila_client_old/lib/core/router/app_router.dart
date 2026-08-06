import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/features/auth/login_screen.dart';
import 'package:tashila_client/features/auth/otp_screen.dart';
import 'package:tashila_client/features/home/home_shell_screen.dart';
import 'package:tashila_client/features/onboarding/onboarding_screen.dart';
import 'package:tashila_client/features/profile/profile_onboarding_screen.dart';
import 'package:tashila_client/features/splash/splash_screen.dart';
import 'package:tashila_client/features/trip_flow/trip_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final appState = ref.read(appStateProvider);
      if (!appState.initialized) return '/';
      final path = state.uri.path;
      final atSplash = path == '/';
      if (atSplash) {
        if (!appState.seenOnboarding) return '/onboarding';
        if (!appState.isLoggedIn) return '/login';
        if (!appState.profileSetupComplete) return '/profile-setup';
        if (appState.hasActiveTrip) return '/trip';
        return '/home';
      }
      if (appState.isLoggedIn) {
        if (!appState.profileSetupComplete && path != '/profile-setup') {
          return '/profile-setup';
        }
        if (appState.profileSetupComplete &&
            (path == '/login' || path == '/otp')) {
          return '/home';
        }
        if (appState.profileSetupComplete &&
            appState.hasActiveTrip &&
            path != '/trip') {
          return '/trip';
        }
        if (appState.profileSetupComplete &&
            !appState.hasActiveTrip &&
            path == '/trip') {
          return '/home';
        }
      } else if (path != '/login' &&
          path != '/otp' &&
          path != '/onboarding' &&
          path != '/') {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileOnboardingScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeShellScreen()),
      GoRoute(path: '/trip', builder: (_, _) => const TripScreen()),
    ],
  );

  ref.listen(appStateProvider, (_, next) => router.refresh());
  return router;
});
