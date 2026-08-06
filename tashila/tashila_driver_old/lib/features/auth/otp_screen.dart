import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_language_menu.dart';

const _otpResendSeconds = 60;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final pin = TextEditingController();
  Timer? _resendTimer;
  int _secondsUntilResend = _otpResendSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    // Clear any error carried over from the send-OTP step on the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(driverAppStateProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    pin.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _secondsUntilResend = _otpResendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend--);
      }
    });
  }

  String get _formattedCountdown {
    final m = _secondsUntilResend ~/ 60;
    final s = _secondsUntilResend % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyAndContinue() async {
    if (pin.text.length < 6) return;
    final ok = await ref.read(driverAppStateProvider.notifier).verifyOtp(pin.text);
    if (!mounted) return;
    if (ok) {
      final ready =
          ref.read(driverAppStateProvider).profile?.isReadyForDashboard ??
              false;
      context.go(ready ? '/home' : '/profile');
    } else {
      pin.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverAppStateProvider);
    final notifier = ref.read(driverAppStateProvider.notifier);
    final theme = Theme.of(context);
    final pillBg = AppColors.brandOrange.withValues(alpha: 0.12);

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: theme.textTheme.titleLarge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandOrange, width: 2),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('otp_title'.tr()),
        actions: const [AuthLanguageMenu()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'otp_enter_code'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'otp_sent_to'.tr(namedArgs: {'phone': state.phone}),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Pinput(
                length: 6,
                controller: pin,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: focusedPinTheme,
                onCompleted: (_) => _verifyAndContinue(),
              ),
              const SizedBox(height: 24),
              if (_secondsUntilResend > 0)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: AppColors.brandOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formattedCountdown,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.brandOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_secondsUntilResend > 0) const SizedBox(height: 16),
              Text(
                'otp_no_code'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _secondsUntilResend == 0
                      ? () async {
                          await notifier.requestOtp(state.phone);
                          _startResendCountdown();
                        }
                      : null,
                  child: Text(
                    'otp_resend'.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _secondsUntilResend == 0
                          ? AppColors.brandOrange
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 10),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'verify_continue'.tr(),
                isBusy: state.isBusy,
                onPressed: () async => _verifyAndContinue(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
