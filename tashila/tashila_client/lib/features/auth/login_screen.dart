import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:tashila_client/core/state/app_state.dart';
import 'package:tashila_client/core/theme/app_colors.dart';
import 'package:tashila_client/core/widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

const _kPrivacyPolicyUrl = 'https://tashila.app/privacy';
const _kTermsOfServiceUrl = 'https://tashila.app/terms';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String completePhone = '';
  bool _isSending = false;
  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()..onTap = () => _openLegalUrl(_kPrivacyPolicyUrl);
    _termsTap = TapGestureRecognizer()..onTap = () => _openLegalUrl(_kTermsOfServiceUrl);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/images/arabic_logo.jpeg', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'auth_title'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'phone_hint'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),
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
                        flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 14),
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'phone'.tr(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.brandOrange, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
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
                      'auth_otp_sms_notice'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'send_otp'.tr(),
                      onPressed: _isSending
                          ? null
                          : () async {
                              if (completePhone.isEmpty) return;
                              setState(() => _isSending = true);
                              var ok = false;
                              try {
                                await ref
                                    .read(appStateProvider.notifier)
                                    .sendOtp(completePhone);
                                ok = true;
                              } catch (_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('send_otp_failed'.tr())),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSending = false);
                              }
                              if (!mounted || !ok) return;
                              context.push('/otp', extra: completePhone);
                            },
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    Text.rich(
                      TextSpan(
                        style: baseStyle,
                        children: [
                          TextSpan(text: 'auth_legal_prefix'.tr()),
                          TextSpan(
                            text: 'privacy_policy'.tr(),
                            style: linkStyle,
                            recognizer: _privacyTap,
                          ),
                          TextSpan(text: 'auth_legal_middle'.tr()),
                          TextSpan(
                            text: 'terms_of_service'.tr(),
                            style: linkStyle,
                            recognizer: _termsTap,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
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

