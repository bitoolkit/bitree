import 'dart:convert';
import 'dart:io';

import 'package:bitree/mooc/cookie.dart';
import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/mooc/login_client.dart';
import 'package:bitree/mooc/login_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/mooc_login_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MOOC params use the expected SM4 envelope', () {
    expect(
      encryptMoocParams({'hello': 'world'}),
      '29f11380bc7a2f2f829ec400300b274b'
      '5b3a9f53398c010b8c0631ccc3ab2011',
    );
  });

  test('MOOC proof signature matches its MurmurHash3 vector', () {
    expect(
      moocProofSignature(
        'runTimes=387487&spendTime=1051&t=387487'
        '&x=2ba4da5041f5e5da892612e7614823519a',
        387487,
      ),
      '1788250788',
    );
  });

  test('MOOC proof solver returns a signed short VDF result', () async {
    final result = await solveMoocProof({
      'hashFunc': 'VDF_FUNCTION',
      'sid': 'proof-session',
      'minTime': 0,
      'maxTime': 100,
      'args': {'mod': '0b', 'x': '02', 't': 2, 'puzzle': 'puzzle'},
    });
    expect(result['puzzle'], 'puzzle');
    expect(result['sid'], 'proof-session');
    expect(result['runTimes'], 2);
    final args = jsonDecode(result['args']! as String) as Map<String, dynamic>;
    expect(args['x'], '5');
    expect(args['t'], result['runTimes']);
    expect(args['sign'], isA<int>());
  });

  group('native login protocol', () {
    late MoocLoginServer server;
    late HttpOverrides? previous;

    setUp(() async {
      server = await MoocLoginServer.start();
      previous = HttpOverrides.current;
      HttpOverrides.global = LocalHttpOverrides(server.port);
    });

    tearDown(() async {
      HttpOverrides.global = previous;
      await server.close();
    });

    test(
      'password login follows initialization and reads the account',
      () async {
        final client = MoocLoginClient();
        addTearDown(client.close);

        final account = await client.loginWithPassword(
          account: 'student@example.com',
          password: 'password',
        );

        expect(account.id, '123');
        expect(account.name, '测试账号');
        expect(
          MoocCredentials.hasSession(
            account.credentials.cookies.map(MoocCookie.fromSetCookieValue),
          ),
          isTrue,
        );
        expect(server.requests, [
          'GET /www.icourse163.org/member/login.htm',
          'GET /reg.icourse163.org/webzj/v1.0.1/pub/index_dl2_new.html',
          'POST /reg.icourse163.org/dl/zj/mail/ini',
          'POST /reg.icourse163.org/zc/zj/yd/ini',
          'POST /reg.icourse163.org/dl/zj/yd/ini',
          'POST /reg.icourse163.org/dl/zj/yd/powGetP',
          'POST /reg.icourse163.org/dl/zj/yd/gt',
          'POST /reg.icourse163.org/dl/zj/yd/pwd/l',
          'GET /www.icourse163.org/home.htm',
        ]);
      },
    );

    test('wrong credentials remain a retryable login error', () async {
      server.passwordResult = {'ret': 413};
      final client = MoocLoginClient();
      addTearDown(client.close);

      await expectLater(
        client.loginWithPassword(
          account: 'student@example.com',
          password: 'wrong',
        ),
        throwsA(
          isA<MoocLoginException>().having(
            (error) => error.kind,
            'kind',
            MoocLoginError.wrongCredentials,
          ),
        ),
      );
    });

    test('a proof challenge retries once with a fresh VDF proof', () async {
      server.requireProofOnFirstPassword = true;
      final client = MoocLoginClient();
      addTearDown(client.close);

      final account = await client.loginWithPassword(
        account: 'student@example.com',
        password: 'password',
      );

      expect(account.id, '123');
      expect(server.passwordAttempts, 2);
      expect(
        server.requests.where(
          (request) => request == 'POST /reg.icourse163.org/dl/zj/yd/powGetP',
        ),
        hasLength(2),
      );
    });

    for (final code in const {
      '108',
      '109',
      '110',
      '111',
      '441',
      '444',
      '445',
      '447',
    }) {
      test('challenge $code asks the caller to verify', () async {
        server.passwordResult = {'ret': code};
        final client = MoocLoginClient();
        addTearDown(client.close);

        await expectLater(
          client.loginWithPassword(
            account: 'student@example.com',
            password: 'password',
          ),
          throwsA(
            isA<MoocLoginChallenge>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
      });
    }

    test('691 is not treated as a recoverable CAPTCHA challenge', () async {
      server.passwordResult = {'ret': 691};
      final client = MoocLoginClient();
      addTearDown(client.close);

      await expectLater(
        client.loginWithPassword(
          account: 'student@example.com',
          password: 'password',
        ),
        throwsA(
          isA<MoocLoginException>()
              .having((error) => error.kind, 'kind', MoocLoginError.unavailable)
              .having((error) => error.code, 'code', '691'),
        ),
      );
    });

    test('password login retries with a CAPTCHA solution', () async {
      server.passwordResult = {'ret': 445};
      final client = MoocLoginClient();
      addTearDown(client.close);

      await expectLater(
        client.loginWithPassword(
          account: 'student@example.com',
          password: 'password',
        ),
        throwsA(isA<MoocLoginChallenge>()),
      );
      server.passwordResult = {'ret': 201};
      final account = await client.loginWithPassword(
        account: 'student@example.com',
        password: 'password',
        captcha: const MoocCaptchaSolution(
          validate: 'verified-token',
          captchaType: '3',
        ),
      );

      expect(account.id, '123');
      expect(server.passwordAttempts, 2);
    });

    test('SMS send and login share one initialized session', () async {
      final client = MoocLoginClient();
      addTearDown(client.close);

      expect(
        await client.sendSmsCode('13800138000'),
        const Duration(seconds: 2),
      );
      final account = await client.loginWithSmsCode(
        phone: '13800138000',
        code: '123456',
      );

      expect(account.id, '123');
      expect(
        server.requests.where(
          (request) => request == 'GET /www.icourse163.org/member/login.htm',
        ),
        hasLength(1),
      );
      expect(
        server.requests.where(
          (request) => request == 'POST /reg.icourse163.org/dl/zj/yd/sms/sm',
        ),
        hasLength(1),
      );
      expect(
        server.requests.where(
          (request) => request == 'POST /reg.icourse163.org/dl/zj/yd/sms/vfsms',
        ),
        hasLength(1),
      );
    });

    test('cookie verification stays native and reads the account', () async {
      final client = MoocLoginClient();
      addTearDown(client.close);
      final cookies = MoocCredentials.cookiesFromHeader(
        'NTESSTUDYSI=csrf; STUDY_SESS=session',
      );

      final account = await client.verifyCookies(cookies);

      expect(account.id, '123');
      expect(account.name, '测试账号');
      expect(server.requests, ['GET /www.icourse163.org/home.htm']);
    });
  });
}
