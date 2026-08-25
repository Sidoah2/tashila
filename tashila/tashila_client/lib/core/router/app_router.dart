import 'package:flutter/material.dart';
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

import 'package:tashila_client/features/trip_flow/rate_driver_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
        if (appState.profileSetupComplete && appState.hasActiveTrip) {
          if (appState.tripStage == TripStage.arrivedSummary) {
            if (path != '/rate-driver') {
              return '/rate-driver';
            }
          } else {
            if (path != '/trip') {
              return '/trip';
            }
          }
        }
        if (appState.profileSetupComplete &&
            !appState.hasActiveTrip &&
            (path == '/trip' || path == '/rate-driver')) {
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
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            phone: extra['phone'] as String? ?? '',
            verificationId: extra['verificationId'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileOnboardingScreen(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeShellScreen()),
      GoRoute(path: '/trip', builder: (_, _) => const TripScreen()),
      GoRoute(
        path: '/rate-driver',
        builder: (_, _) => const RateDriverScreen(),
      ),
    ],
  );

  ref.listen<AppState>(
    appStateProvider,
    (previous, next) {
      if (previous?.initialized != next.initialized ||
          previous?.seenOnboarding != next.seenOnboarding ||
          previous?.isLoggedIn != next.isLoggedIn ||
          previous?.profileSetupComplete != next.profileSetupComplete ||
          previous?.hasActiveTrip != next.hasActiveTrip ||
          previous?.tripStage != next.tripStage) {
        router.refresh();
      }
    },
  );
  return router;
});
