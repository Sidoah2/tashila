import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal_urls.dart';
import '../../core/state/driver_app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_language_menu.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String completePhone = '';
  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegalUrl(kPrivacyPolicyUrl);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegalUrl(kTermsOfServiceUrl);
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(driverAppStateProvider);
    final notifier = ref.read(driverAppStateProvider.notifier);

    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final linkStyle = baseStyle?.copyWith(
      color: AppColors.brandOrange,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Premium gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.brandOrange, Color(0xFFFF9E80)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const AuthLanguageMenu(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'app_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'login_title'.tr(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Form content
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Directionality(
                            textDirection: ui.TextDirection.ltr,
                            child: IntlPhoneField(
                              initialCountryCode: 'DZ',
                              dropdownIconPosition: IconPosition.trailing,
                              showCountryFlag: true,
                              pickerDialogStyle: PickerDialogStyle(
                                backgroundColor: Colors.white,
                                countryNameStyle: theme.textTheme.bodyMedium,
                                countryCodeStyle: theme.textTheme.bodyMedium,
                              ),
                              flagsButtonPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'phone_label'.tr(),
                                filled: true,
                                fillColor: AppColors.bg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandOrange,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (phone) {
                                var number = phone.number.trim();
                                if (number.startsWith('0')) {
                                  number = number.substring(1);
                                }
                                completePhone = '${phone.countryCode}$number';
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'otp_sms_notice'.tr(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'send_otp'.tr(),
                      isBusy: state.isBusy,
                      onPressed: () async {
                        if (completePhone.isEmpty) return;
                        await notifier.requestOtp(completePhone);
                        if (!context.mounted) return;
                        context.push('/otp');
                      },
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        style: baseStyle,
                        children: [
                          TextSpan(text: 'legal_prefix'.tr()),
                          TextSpan(
                            text: 'privacy_policy'.tr(),
                            style: linkStyle,
                            recognizer: _privacyTap,
                          ),
                          TextSpan(text: 'legal_and'.tr()),
                          TextSpan(
                            text: 'terms_of_service'.tr(),
                            style: linkStyle,
                            recognizer: _termsTap,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
