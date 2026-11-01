import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bitree/school/errors.dart';
import 'package:bitree/school/session.dart';
import 'package:bitree/school/ui/school_verification_dialog.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SchoolResponse _response(int status, Map<String, dynamic> body) =>
    SchoolResponse(
      url: Uri.https(
        'sso.bit.edu.cn',
        '/cas/api/protected/sms/publicNoToken/sendSmsCode',
      ),
      status: status,
      location: null,
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );

Map<String, dynamic> _cooldown({
  int code = 412,
  int errorCode = 8000068,
  int interval = 120,
  int remaining = 62,
}) => {
  'message': 'Precondition Failed',
  'code': code,
  'data': {
    'errorCode': errorCode,
    'errorMessage': jsonEncode({'interval': interval, 'remaining': remaining}),
  },
};

void main() {
  group('school SMS delivery', () {
    test('a regular send starts the normal resend cooldown', () {
      final delivery = SchoolSmsCodeDelivery.fromResponse(
        _response(200, {'code': 200, 'message': 'success'}),
      );

      expect(delivery.resendAfter, const Duration(seconds: 60));
    });

    for (final status in [200, 412]) {
      test('HTTP $status keeps the previous code and returns its cooldown', () {
        final delivery = SchoolSmsCodeDelivery.fromResponse(
          _response(status, _cooldown()),
        );

        expect(delivery.resendAfter, const Duration(seconds: 62));
      });
    }

    for (final (reason, status, body) in [
      ('unrelated HTTP failure', 503, _cooldown()),
      ('unrelated HTTP status', 412, _cooldown(code: 200)),
      ('unrelated school error', 412, _cooldown(errorCode: 8000069)),
      ('zero remaining time', 412, _cooldown(remaining: 0)),
      ('negative remaining time', 412, _cooldown(remaining: -1)),
      ('remaining time beyond the interval', 412, _cooldown(remaining: 121)),
    ]) {
      test('$reason remains an error', () {
        expect(
          () => SchoolSmsCodeDelivery.fromResponse(_response(status, body)),
          throwsA(
            anyOf(isA<SchoolRequestError>(), isA<SchoolConnectionError>()),
          ),
        );
      });
    }
  });

  testWidgets('SMS verification displays the server resend cooldown', (
    tester,
  ) async {
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                verifySchoolLogin(
                  context,
                  SchoolSmsVerification(
                    phone: '138****0000',
                    sendCode: () async =>
                        Duration(seconds: ++sends == 1 ? 1 : 62),
                    checkCode: (_) async {},
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump();

    expect(find.text('1 秒后重发'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('重新发送'), findsOneWidget);

    await tester.tap(find.text('重新发送'));
    await tester.pump();
    await tester.pump();

    expect(find.text('62 秒后重发'), findsOneWidget);
    expect(find.text('Precondition Failed'), findsNothing);
    expect(sends, 2);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('61 秒后重发'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
}
