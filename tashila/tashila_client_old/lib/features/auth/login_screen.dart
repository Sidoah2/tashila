import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
      appBar: AppBar(title: Text('auth_title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'phone_hint'.tr(),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialCountryCode: 'DZ',
                decoration: InputDecoration(hintText: 'phone'.tr()),
                onChanged: (phone) => completePhone = phone.completeNumber,
              ),
              const SizedBox(height: 8),
              Text(
                'auth_otp_sms_notice'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
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
                textAlign: TextAlign.start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
