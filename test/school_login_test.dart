import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/core/diagnostics.dart';
import 'package:bitree/school/crypto.dart';
import 'package:bitree/school/errors.dart';
import 'package:bitree/school/login.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/session.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/school/verification.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/school_network.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lexue = DeadlineSource.lexue;
  final sso = Uri.https('sso.bit.edu.cn', '/cas/login', {
    'service': '${lexue.loginPage}',
  });
  const cryptoKey = 'AAECAwQFBgcICQoLDA0ODw==';
  late HttpServer server;
  late StreamIterator<HttpRequest> incoming;
  late LocalSchoolNetwork network;
  late MemorySchoolStorage storage;
  late SchoolSession session;
  late Directory directory;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('bitree-school-login-');
  });
  tearDownAll(() async {
    await AppDiagnostics.instance.recentLines();
    messenger.setMockMethodCallHandler(pathProvider, null);
    await directory.delete(recursive: true);
  });

  setUp(() async {
    messenger.setMockMethodCallHandler(
      pathProvider,
      (_) async => directory.path,
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    incoming = StreamIterator(server);
    network = LocalSchoolNetwork(server.port);
    storage = MemorySchoolStorage(
      credentials: const SchoolCredentials(
        username: 'student',
        password: 'test',
      ),
    );
  });

  tearDown(() async {
    session.close();
    await incoming.cancel();
    await server.close(force: true);
  });

  SchoolLogin login() {
    session = SchoolSession(network: SchoolNetwork.campus, storage: storage);
    return SchoolLogin(
      session,
      (_) async => throw StateError('No verification should open in this test'),
    );
  }

  Future<HttpRequest> nextRequest() async {
    expect(await incoming.moveNext(), isTrue);
    return incoming.current;
  }

  Future<void> reply(
    HttpRequest request, {
    int status = 200,
    String body = '',
    Uri? location,
  }) async {
    request.response.statusCode = status;
    if (location != null) {
      request.response.headers.set(HttpHeaders.locationHeader, '$location');
    }
    request.response.write(body);
    await request.response.close();
  }

  Future<HttpRequest> riskRequest({String action = ''}) async {
    final entry = await nextRequest();
    expect(entry.uri.path, '/lexue.bit.edu.cn/login/index.php');
    entry.response.cookies.add(
      Cookie('MoodleSession', 'bootstrap')..path = '/',
    );
    await reply(
      entry,
      status: 302,
      location: Uri.https('login.bit.edu.cn', '/authserver/login', {
        'service': '${lexue.loginPage}',
      }),
    );
    final legacyEntry = await nextRequest();
    expect(legacyEntry.uri.path, '/login.bit.edu.cn/authserver/login');
    await reply(legacyEntry, status: 302, location: sso);
    final page = await nextRequest();
    expect(page.uri.path, '/sso.bit.edu.cn/cas/login');
    await reply(
      page,
      body:
          '''
      <p id="login-page-flowkey">password-flow</p>
      <p id="login-croypto">$cryptoKey</p>
      <p id="riskSystemSwitch">USTC</p>
      <p id="targetSystem">sso</p>
      <p id="siteId">sourceId</p>
      <form method="post" $action></form>
    ''',
    );
    final captcha = await nextRequest();
    expect(captcha.uri.path, endsWith('/findCaptchaCount/student'));
    await reply(captcha, body: '{"data":{"captchaInvisible":false}}');
    final risk = await nextRequest();
    expect(risk.uri.path, '/sso.bit.edu.cn/ustc-rba-front/fp');
    return risk;
  }

  Future<HttpRequest> passwordPost({
    String action = '',
    int riskStatus = 200,
    String riskBody = '{"responsetoken":"risk-token"}',
  }) async {
    final risk = await riskRequest(action: action);
    await reply(risk, status: riskStatus, body: riskBody);
    final password = await nextRequest();
    expect(password.method, 'POST');
    expect(password.uri.path, '/sso.bit.edu.cn/cas/login');
    return password;
  }

  for (final (action, riskStatus) in [
    ('', 200),
    ('action=""', 200),
    ('', 404),
  ]) {
    test(
      'A login form with ${action.isEmpty ? 'no' : 'an empty'} action keeps its service after risk status $riskStatus',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final result = login().openService(lexue.loginPage);
        final expectation = expectLater(
          result,
          completion(
            isA<SchoolResponse>().having(
              (page) => page.url.host,
              'host',
              lexue.host,
            ),
          ),
        );
        final password = await passwordPost(
          action: action,
          riskStatus: riskStatus,
        );
        expect(password.uri.queryParameters['service'], '${lexue.loginPage}');
        final form = Uri.splitQueryString(
          await utf8.decoder.bind(password).join(),
        );
        expect(form['execution'], 'password-flow');
        expect(form['username'], 'student');
        expect(
          decryptSchoolValue(form['password']!, base64Decode(cryptoKey)),
          'test',
        );
        expect(
          jsonDecode(
            decryptSchoolValue(form['risk_payload']!, base64Decode(cryptoKey)),
          ),
          riskStatus == 200
              ? {'token': 'risk-token', 'groupId': ''}
              : {'error': true},
        );
        await reply(
          password,
          status: 302,
          location: lexue.loginPage.replace(
            queryParameters: {'ticket': 'test'},
          ),
        );
        final callback = await nextRequest();
        expect(callback.uri.path, '/lexue.bit.edu.cn/login/index.php');
        expect(
          callback.headers.value(HttpHeaders.cookieHeader),
          contains('MoodleSession=bootstrap'),
        );
        await reply(
          callback,
          body: '<script>M.cfg={"sesskey":"signed-in"};</script>',
        );
        await expectation;
      }, network),
    );
  }

  for (final (status, body) in [
    (404, ''),
    (503, ''),
    (200, '<html>Unavailable</html>'),
    (200, '{"responsetoken":42}'),
  ]) {
    test(
      'Risk collection failure ($status, $body) is reported to CAS, which can still require SMS',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final result = login().openService(lexue.loginPage);
        final expectation = expectLater(
          result,
          throwsA(
            isA<SchoolConnectionError>().having(
              (failure) => failure.url.path,
              'next authentication step',
              '/cas/api/protected/sms/getPhoneNumberByUserId',
            ),
          ),
        );
        final password = await passwordPost(riskStatus: status, riskBody: body);
        final form = Uri.splitQueryString(
          await utf8.decoder.bind(password).join(),
        );
        expect(form['riskEngine'], 'true');
        expect(
          jsonDecode(
            decryptSchoolValue(form['risk_payload']!, base64Decode(cryptoKey)),
          ),
          {'error': true},
        );
        expect(
          decryptSchoolValue(form['password']!, base64Decode(cryptoKey)),
          'test',
        );
        await reply(
          password,
          body: '''
          <p id="login-page-flowkey">sms-flow</p>
          <p id="user-object-id">test-user-object</p>
          <form id="secondSmsLoginForm" method="post"></form>
        ''',
        );
        final phone = await nextRequest();
        // Stop at the encrypted boundary; no real SMS is sent.
        await reply(phone, status: 503);
        await expectation;
      }, network),
    );
  }

  test(
    'Automatic login still defers SMS after a risk collection failure',
    () => HttpOverrides.runWithHttpOverrides(() async {
      session = SchoolSession(network: SchoolNetwork.campus, storage: storage);
      final result = SchoolLogin(session, null).openService(lexue.loginPage);
      final expectation = expectLater(
        result,
        throwsA(
          isA<SchoolVerificationRequired>().having(
            (request) => request.kind,
            'required verification',
            SchoolVerificationKind.sms,
          ),
        ),
      );
      final password = await passwordPost(riskStatus: 404, riskBody: '');
      await reply(
        password,
        body: '''
        <p id="login-page-flowkey">sms-flow</p>
        <p id="user-object-id">test-user-object</p>
        <form id="secondSmsLoginForm" method="post"></form>
      ''',
      );
      await expectation;
    }, network),
  );

  test(
    'Cancelling risk collection does not submit a failure payload or credentials',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final result = login().openService(lexue.loginPage);
      final expectation = expectLater(result, throwsA(isA<RequestCancelled>()));
      await riskRequest();
      session.close();
      await expectation;
    }, network),
  );

  for (final source in [DeadlineSource.lexue, DeadlineSource.eclass]) {
    test(
      '${source.label} reuses its authenticated session without asking for credentials',
      () => HttpOverrides.runWithHttpOverrides(() async {
        storage.credentials = null;
        await storage.saveCookies(SchoolNetwork.campus, source.origin, [
          Cookie('session', 'signed-in')..path = '/',
        ]);
        final result = login().openService(source.loginPage);
        final expectation = expectLater(result, completes);
        final request = await nextRequest();
        expect(request.uri.path, '/${source.host}${source.loginPage.path}');
        expect(
          request.headers.value(HttpHeaders.cookieHeader),
          contains('session=signed-in'),
        );
        await reply(
          request,
          body: '<script>M.cfg={"sesskey":"signed-in"};</script>',
        );
        await expectation;
      }, network),
    );
  }

  for (final marker in [
    '<div id="second-auth-tip">请验证绑定手机</div>',
    '<form id="secondSmsLoginForm"></form>',
    '<div class="cas-gateway"></div>',
  ]) {
    test(
      'A secondary verification page starts its phone lookup: $marker',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final result = login().openService(lexue.loginPage);
        final expectation = expectLater(
          result,
          throwsA(
            isA<SchoolConnectionError>().having(
              (failure) => failure.url.path,
              'failed endpoint',
              '/cas/api/protected/sms/getPhoneNumberByUserId',
            ),
          ),
        );
        final password = await passwordPost();
        await reply(
          password,
          body:
              '''
            <p id="login-page-flowkey">sms-flow</p>
            <p id="user-object-id">test-user-object</p>
            $marker
          ''',
        );
        final phone = await nextRequest();
        expect(phone.method, 'POST');
        expect(
          phone.uri.path,
          '/sso.bit.edu.cn/cas/api/protected/sms/getPhoneNumberByUserId',
        );
        // Keep this test at the secondary-auth boundary; no real SMS is sent.
        await reply(phone, status: 503);
        await expectation;
      }, network),
    );
  }

  for (final (target, entry) in [
    ('teaching', SchoolNetwork.campus.accountPage),
    ('records', SchoolNetwork.recordsService),
    ('lexue', lexue.loginPage),
    ('eclass', DeadlineSource.eclass.loginPage),
  ]) {
    test(
      '$target resumes SMS verification from an existing SSO session without a password page',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final auth = login();
        Future<void> authenticate() async {
          switch (target) {
            case 'teaching':
              await auth.signIn();
            case 'records':
              await auth.signInTo(entry);
            default:
              await auth.openService(entry);
          }
        }

        final expectation = expectLater(
          authenticate(),
          throwsA(
            isA<SchoolConnectionError>().having(
              (failure) => failure.url.path,
              'SMS endpoint reached',
              '/cas/api/protected/sms/getPhoneNumberByUserId',
            ),
          ),
        );
        if (target == 'teaching') {
          final preflight = await nextRequest();
          expect(
            preflight.uri.path,
            '/jxzxehall.bit.edu.cn/auth-protocol-core/login',
          );
          await reply(
            preflight,
            status: 302,
            location: sso.replace(queryParameters: {'service': '$entry'}),
          );
        } else if (target != 'records') {
          final service = await nextRequest();
          expect(service.uri.path, '/${entry.host}${entry.path}');
          await reply(
            service,
            status: 302,
            location: sso.replace(queryParameters: {'execution': 'sms-flow'}),
          );
        }
        final page = await nextRequest();
        expect(page.uri.path, '/sso.bit.edu.cn/cas/login');
        await reply(
          page,
          body: '''
          <p id="login-page-flowkey">sms-flow</p>
          <p id="user-object-id">test-user-object</p>
          <form id="secondSmsLoginForm" method="post"></form>
        ''',
        );
        final phone = await nextRequest();
        expect(
          phone.uri.path,
          '/sso.bit.edu.cn/cas/api/protected/sms/getPhoneNumberByUserId',
        );
        // Stop at the encrypted school boundary; never contact a real SMS service.
        await reply(phone, status: 503);
        await expectation;
      }, network),
    );
  }

  test(
    'A password response can redirect to the SMS step before the service callback',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final expectation = expectLater(
        login().openService(lexue.loginPage),
        throwsA(
          isA<SchoolConnectionError>().having(
            (failure) => failure.url.path,
            'SMS endpoint reached',
            '/cas/api/protected/sms/getPhoneNumberByUserId',
          ),
        ),
      );
      final password = await passwordPost();
      final continuation = sso.replace(
        queryParameters: {'execution': 'sms-flow'},
      );
      await reply(password, status: 303, location: continuation);
      final page = await nextRequest();
      expect(page.method, 'GET');
      expect(page.uri.queryParameters['execution'], 'sms-flow');
      await reply(
        page,
        body: '''
        <p id="login-page-flowkey">sms-flow</p>
        <p id="user-object-id">test-user-object</p>
        <div id="second-auth-tip">请验证绑定手机</div>
        <form method="post"></form>
      ''',
      );
      final phone = await nextRequest();
      expect(
        phone.uri.path,
        '/sso.bit.edu.cn/cas/api/protected/sms/getPhoneNumberByUserId',
      );
      await reply(phone, status: 503);
      await expectation;
    }, network),
  );

  test(
    'Repeated SSO redirects stop without submitting credentials',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final expectation = expectLater(
        login().signInTo(SchoolNetwork.recordsService),
        throwsA(isA<SchoolRequestError>()),
      );
      for (var redirect = 0; redirect <= 11; redirect++) {
        final request = await nextRequest();
        expect(request.method, 'GET');
        expect(request.uri.path, '/sso.bit.edu.cn/cas/login');
        await reply(request, status: 302, location: sso);
      }
      await expectation;
    }, network),
  );

  for (final riskStatus in [200, 404]) {
    test(
      'Rejected credentials keep the school login error after risk status $riskStatus',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final result = login().openService(lexue.loginPage);
        final expectation = expectLater(
          result,
          throwsA(
            isA<SchoolCredentialsRequired>().having(
              (failure) => failure.message,
              'message',
              '账号或密码错误',
            ),
          ),
        );
        final password = await passwordPost(riskStatus: riskStatus);
        await reply(
          password,
          status: 401,
          body: '''
          <p id="login-error-code">1030027</p>
          <p id="login-error-msg">认证信息无效</p>
        ''',
        );
        await expectation;
      }, network),
    );
  }
}
