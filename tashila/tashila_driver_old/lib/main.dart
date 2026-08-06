import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/models.dart';
import 'core/router/app_router.dart';
import 'core/state/driver_app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/rating_sheet_host.dart';

const _supported = [Locale('en'), Locale('ar'), Locale('fr')];

/// Picks en / ar / fr from the OS locale; anything else falls back to English.
Locale _localeFromDevice() {
  final device = ui.PlatformDispatcher.instance.locale;
  final code = device.languageCode.toLowerCase();
  for (final locale in _supported) {
    if (locale.languageCode == code) {
      return locale;
    }
  }
  return const Locale('en');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: _supported,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: _localeFromDevice(),
      useOnlyLangCode: true,
      child: const ProviderScope(child: TashilaDriverApp()),
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
    unawaited(ref.read(driverAppStateProvider.notifier).resumeSessionOnForeground());
  }

  Future<void> _showClientRatingSheet() async {
    if (!mounted) return;
    await showRequiredClientRatingSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.listen<DriverAppState>(driverAppStateProvider, (previous, next) {
      if (previous?.tripStatus != TripStatus.awaitingClientRating &&
          next.tripStatus == TripStatus.awaitingClientRating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showClientRatingSheet();
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
    );
  }
}
