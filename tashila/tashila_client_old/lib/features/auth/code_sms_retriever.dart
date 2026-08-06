import 'dart:async';

import 'package:pinput/pinput.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Bridges [sms_autofill] to Pinput's [SmsRetriever] for Android SMS OTP hints.
final class CodeSmsRetriever implements SmsRetriever {
  @override
  Future<void> dispose() => SmsAutoFill().unregisterListener();

  @override
  Future<String?> getSmsCode() async {
    final autoFill = SmsAutoFill();
    await autoFill.listenForCode(smsCodeRegexPattern: r'\d{6}');
    try {
      return await autoFill.code.first.timeout(const Duration(seconds: 90));
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get listenForMultipleSms => false;
}
