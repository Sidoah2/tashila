import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final controller = PageController();
  int current = 0;

  static const _logoAsset = 'assets/images/arabic_logo.jpeg';

  static const _slides = [
    (_logoAsset, 'onboarding_title_1', 'onboarding_desc_1'),
    (_logoAsset, 'onboarding_title_2', 'onboarding_desc_2'),
    (_logoAsset, 'onboarding_title_3', 'onboarding_desc_3'),
  ];

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
                  child: Text('skip'.tr(), style: const TextStyle(color: AppColors.brandOrange)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  onPageChanged: (value) => setState(() => current = value),
                  itemCount: _slides.length,
                  itemBuilder: (_, index) {
                    final item = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(item.$1, height: 240),
                        ),
                        const SizedBox(height: 30),
                        Text(item.$2.tr(), style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(item.$3.tr(), textAlign: TextAlign.center),
                      ],
                    );
                  },
                ),
              ),
              SmoothPageIndicator(
                controller: controller,
                count: _slides.length,
                effect: const WormEffect(activeDotColor: AppColors.brandOrange),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: current == _slides.length - 1 ? 'start_now'.tr() : 'next'.tr(),
                onPressed: () {
                  if (current == _slides.length - 1) {
                    _finish();
                  } else {
                    controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
                icon: Icons.rocket_launch_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    await ref.read(appStateProvider.notifier).setSeenOnboarding();
    if (mounted) context.go('/login');
  }
}
