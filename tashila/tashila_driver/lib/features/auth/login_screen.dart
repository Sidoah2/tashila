import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
      appBar: AppBar(
        title: Text('login_title'.tr()),
        actions: const [AuthLanguageMenu()],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('phone_login_otp'.tr(), style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialCountryCode: 'DZ',
                decoration: InputDecoration(hintText: 'phone_label'.tr()),
                onChanged: (phone) => completePhone = phone.completeNumber,
              ),
              const SizedBox(height: 8),
              Text(
                'otp_sms_notice'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'send_otp'.tr(),
                isBusy: state.isBusy,
                onPressed: () async {
                  if (completePhone.isEmpty) return;
                  await notifier.requestOtp(completePhone);
                  // Always navigate — even if send fails, the OTP may be
                  // delivered and the user can resend from the OTP screen.
                  if (!context.mounted) return;
                  context.push('/otp');
                },
              ),
              if (state.error != null) ...[
                const SizedBox(height: 10),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
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
    );
  }
}
