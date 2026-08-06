import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final PageController _pageController = PageController();
  int _current = 0;

  static const _slides = [
    (Icons.local_shipping_outlined, 'driver_onboarding_title_1',
        'driver_onboarding_desc_1'),
    (Icons.route_outlined, 'driver_onboarding_title_2',
        'driver_onboarding_desc_2'),
    (Icons.account_balance_wallet_outlined, 'driver_onboarding_title_3',
        'driver_onboarding_desc_3'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(driverAppStateProvider.notifier).setSeenOnboarding();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'skip'.tr(),
                    style: const TextStyle(color: AppColors.brandOrange),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(36),
                            child: Icon(
                              slide.$1,
                              size: 120,
                              color: AppColors.brandOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          slide.$2.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.$3.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: _pageController,
                count: _slides.length,
                effect: const WormEffect(activeDotColor: AppColors.brandOrange),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _current == _slides.length - 1
                    ? 'start_now'.tr()
                    : 'next'.tr(),
                icon: Icons.rocket_launch_outlined,
                onPressed: () {
                  if (_current == _slides.length - 1) {
                    _finish();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
