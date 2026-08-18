import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';

const _otpResendSeconds = 60;

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    required this.phone,
    required this.verificationId,
    super.key,
  });

  final String phone;
  final String verificationId;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final pin = TextEditingController();
  Timer? _resendTimer;
  int _secondsUntilResend = _otpResendSeconds;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
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
    if (pin.text.length < 6 || _isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final ok = await ref
          .read(appStateProvider.notifier)
          .verifyOtp(widget.phone, pin.text);

      if (!mounted) return;
      if (!ok) {
        _showError('otp_invalid'.tr());
        return;
      }
      final needSetup = !ref.read(appStateProvider).profileSetupComplete;
      context.go(needSetup ? '/profile-setup' : '/home');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError([String? msg]) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg ?? 'otp_invalid'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pillBg = AppColors.brandOrange.withValues(alpha: 0.1);

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 58,
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brandOrange, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'otp_title'.tr(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'otp_subtitle'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone_rounded,
                          size: 18,
                          color: AppColors.brandOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\u200E${widget.phone}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: AutofillGroup(
                          child: Pinput(
                            length: 6,
                            controller: pin,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            submittedPinTheme: focusedPinTheme,
                            onCompleted: (_) => _verifyAndContinue(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_secondsUntilResend > 0)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: AppColors.brandOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formattedCountdown,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.brandOrange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_secondsUntilResend > 0) const SizedBox(height: 20),
                    Text(
                      'otp_didnt_receive'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _secondsUntilResend == 0 ? _onResend : null,
                        child: Text(
                          'otp_resend'.tr(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _secondsUntilResend == 0
                                ? AppColors.brandOrange
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isVerifying ? '...' : 'verify'.tr(),
                      onPressed:
                          _isVerifying ? null : () async => _verifyAndContinue(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
