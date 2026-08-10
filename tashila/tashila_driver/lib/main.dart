import 'dart:async';


import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/models.dart';
import 'core/router/app_router.dart';
import 'core/state/driver_app_state.dart';
import 'core/theme/app_theme.dart';
import 'package:device_preview/device_preview.dart';
import 'package:tashila_driver/core/widgets/connectivity_banner.dart';

const _supported = [Locale('en'), Locale('ar'), Locale('fr')];



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    DevicePreview(
      enabled: false,
      builder: (context) => EasyLocalization(
        supportedLocales: _supported,
        path: 'assets/translations',
        fallbackLocale: const Locale('ar'),
        startLocale: const Locale('ar'),
        useOnlyLangCode: true,
        child: const ProviderScope(child: TashilaDriverApp()),
      ),
    ),
  );
}

class TashilaDriverApp extends ConsumerStatefulWidget {
  const TashilaDriverApp({super.key});

  @override
  ConsumerState<TashilaDriverApp> createState() => _TashilaDriverAppState();
}

class _TashilaDriverAppState extends ConsumerState<TashilaDriverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    final appState = ref.read(driverAppStateProvider);
    if (!appState.isAuthenticated || !appState.bootstrapped) return;
    unawaited(
      ref.read(driverAppStateProvider.notifier).resumeSessionOnForeground(),
    );
  }

  // Future<void> _showClientRatingSheet() async {
  //   if (!mounted) return;
  //   await showRequiredClientRatingSheet(context);
  // }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.listen<DriverAppState>(driverAppStateProvider, (previous, next) {
      if (previous?.tripStatus != TripStatus.awaitingClientRating &&
          next.tripStatus == TripStatus.awaitingClientRating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          router.go('/rate-client');
        });
      }
    });
    ref.watch(driverAppStateProvider);

    return MaterialApp.router(
      title: 'app_title'.tr(),
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const ConnectivityBanner(),
          ],
        );
      },
    );
  }
}
