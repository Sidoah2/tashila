import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';
import 'package:tashila_client/features/auth/code_sms_retriever.dart';

const _otpResendSeconds = 60;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.phone, super.key});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final pin = TextEditingController();
  Timer? _resendTimer;
  int _secondsUntilResend = _otpResendSeconds;
  final _smsRetriever = CodeSmsRetriever();

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    pin.dispose();
    unawaited(_smsRetriever.dispose());
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

  Future<void> _onResend() async {
    if (_secondsUntilResend > 0) return;
    _startResendCountdown();
    try {
      await ref.read(appStateProvider.notifier).sendOtp(widget.phone);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('otp_resend_sent'.tr())),
    );
  }

  Future<void> _verifyAndContinue() async {
    if (pin.text.length < 6) return;
    final ok = await ref
        .read(appStateProvider.notifier)
        .verifyOtp(widget.phone, pin.text);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('otp_invalid'.tr())),
      );
      return;
    }
    final needSetup = !ref.read(appStateProvider).profileSetupComplete;
    context.go(needSetup ? '/profile-setup' : '/home');
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: Text('otp_title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'otp_subtitle'.tr(),
                style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              Text(
                '${'otp_sent'.tr()} ${widget.phone}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 20),
              AutofillGroup(
                child: Pinput(
                  length: 6,
                  controller: pin,
                  smsRetriever: _smsRetriever,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: focusedPinTheme,
                  onCompleted: (_) => _verifyAndContinue(),
                ),
              ),
              const SizedBox(height: 24),
              if (_secondsUntilResend > 0)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 20, color: AppColors.brandOrange),
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
                'otp_didnt_receive'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _secondsUntilResend == 0 ? _onResend : null,
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
              const Spacer(),
              PrimaryButton(
                label: 'verify'.tr(),
                onPressed: () async => _verifyAndContinue(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
