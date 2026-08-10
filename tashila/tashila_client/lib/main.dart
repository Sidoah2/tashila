import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tashila_client/core/router/app_router.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_theme.dart';
import 'package:tashila_client/core/widgets/rating_sheet_host.dart';
import 'package:tashila_client/core/widgets/connectivity_banner.dart';

const _supportedLocales = [Locale('ar'), Locale('en'), Locale('fr')];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  // Quiet [🌎 Easy Localization] debug/info spam in the console; keep warnings/errors.
  EasyLocalization.logger.enableLevels = const [
    LevelMessages.warning,
    LevelMessages.error,
  ];
  runApp(
    EasyLocalization(
      supportedLocales: _supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      useOnlyLangCode: true,
      child: const ProviderScope(child: AppBootstrap()),
    ),
  );
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('lang');
      if (savedLang == null) {
        // First run: Force Arabic
        await prefs.setString('lang', 'ar');
        if (mounted) {
          await context.setLocale(const Locale('ar'));
        }
      }

      await ref.read(appStateProvider.notifier).bootstrap();
      if (!mounted) return;
      final saved = ref.read(appStateProvider).locale;
      await context.setLocale(saved);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    final appState = ref.read(appStateProvider);
    if (!appState.isLoggedIn) return;
    unawaited(ref.read(appStateProvider.notifier).resumeActiveTripIfAny());
  }

  Future<void> _showGlobalRatingSheet() async {
    final router = ref.read(appRouterProvider);
    if (router.state.uri.path == '/trip') return;
    if (!mounted) return;
    await showRequiredDriverRatingSheet(context);
    if (!mounted) return;
    if (ref.read(appStateProvider).tripStage == TripStage.idle) {
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppState>(appStateProvider, (previous, next) {
      if (previous?.tripStage != TripStage.arrivedSummary &&
          next.tripStage == TripStage.arrivedSummary) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showGlobalRatingSheet();
        });
      }
      if (next.showDriverCancelledDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(appStateProvider.notifier).clearDriverCancelledDialog();
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            showDialog<void>(
              context: navContext,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text('order_cancelled'.tr()),
                content: Text('driver_cancelled'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('ok'.tr()),
                  ),
                ],
              ),
            );
          }
        });
      }
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Tashila',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [if (child != null) child, const ConnectivityBanner()],
        );
      },
    );
  }
}
