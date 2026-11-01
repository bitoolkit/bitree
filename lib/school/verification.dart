import 'dart:convert';
import 'dart:typed_data';

import '../core/json.dart';
import 'errors.dart';
import 'session.dart';

typedef VerifySchoolLogin = Future<String?> Function(
  SchoolVerification request,
);

enum SchoolVerificationKind { image, sms }

/// A non-interactive login stops before loading or sending a verification code.
class SchoolVerificationRequired implements Exception {
  const SchoolVerificationRequired(this.kind);

  final SchoolVerificationKind kind;
}

sealed class SchoolVerification {
  const SchoolVerification();
}

class SchoolImageVerification extends SchoolVerification {
  const SchoolImageVerification({required this.image, required this.reload});

  final Uint8List image;
  final Future<Uint8List> Function() reload;
}

class SchoolSmsVerification extends SchoolVerification {
  const SchoolSmsVerification({
    required this.phone,
    required this.sendCode,
    required this.checkCode,
  });

  final String phone;
  final Future<Duration> Function() sendCode;
  final Future<void> Function(String) checkCode;
}

/// The school keeps the previous SMS valid when another code is requested
/// during its cooldown and tells the client when it may request a new one.
class SchoolSmsCodeDelivery {
  const SchoolSmsCodeDelivery._(this.resendAfter);

  static const defaultResendAfter = Duration(seconds: 60);

  factory SchoolSmsCodeDelivery.fromResponse(SchoolResponse response) {
    if (response.status != 200 && response.status != 412) {
      _throwRequestFailure(response);
    }

    final result = response.json;
    final code = jsonIntField(result, 'code');
    if (response.status == 200 && code == 200) {
      return const SchoolSmsCodeDelivery._(defaultResendAfter);
    }
    if (code != 412) throw _responseFailure(result);

    try {
      final data = jsonObjectField(result, 'data');
      if (jsonIntField(data, 'errorCode') != 8000068) {
        throw _responseFailure(result);
      }
      final cooldown = jsonObject(
        jsonDecode(jsonStringField(data, 'errorMessage')),
        '短信验证码冷却时间',
      );
      final interval = jsonIntField(cooldown, 'interval');
      final remaining = jsonIntField(cooldown, 'remaining');
      if (remaining <= 0 || remaining > interval) {
        throw _responseFailure(result);
      }
      return SchoolSmsCodeDelivery._(Duration(seconds: remaining));
    } on FormatException {
      throw _responseFailure(result);
    }
  }

  final Duration resendAfter;

  static Never _throwRequestFailure(SchoolResponse response) {
    final failure = SchoolRequestError(switch (response.status) {
      429 => '请求过于频繁，请稍后重试。',
      _ =>
        '请求失败（${response.status}）：'
            '${response.url.host}${response.url.path}',
    });
    if (response.status == 403 || response.status >= 500) {
      throw SchoolConnectionError(response.url, failure);
    }
    throw failure;
  }

  static SchoolRequestError _responseFailure(Map<String, dynamic> result) =>
      SchoolRequestError(
        (result['message'] ?? result['msg'] ?? '验证码发送失败，请重试。').toString(),
      );
}
