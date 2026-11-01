import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/school/access.dart';
import 'package:bitree/school/connection.dart';
import 'package:bitree/school/errors.dart';
import 'package:bitree/school/login.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/session.dart';
import 'package:bitree/school/storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/school_network.dart';
import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SchoolNetwork.campus.accountPage;
  late HttpServer server;
  late StreamIterator<HttpRequest> incoming;
  late LocalSchoolNetwork network;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    incoming = StreamIterator(server);
    network = LocalSchoolNetwork(server.port);
  });

  tearDown(() async {
    await incoming.cancel();
    await server.close(force: true);
  });

  Future<HttpRequest> nextRequest() async {
    expect(await incoming.moveNext(), isTrue);
    return incoming.current;
  }

  Future<Map<SchoolNetwork, HttpRequest>> probes() async {
    final requests = [await nextRequest(), await nextRequest()];
    expect(requests.map((request) => request.method), everyElement('GET'));
    expect(
      requests.map(
        (request) => request.headers.value(HttpHeaders.cookieHeader),
      ),
      everyElement(isNull),
    );
    return {
      for (final request in requests)
        request.uri.pathSegments.first == 'webvpn.bit.edu.cn'
                ? SchoolNetwork.webvpn
                : SchoolNetwork.campus:
            request,
    };
  }

  Future<void> reply(
    HttpRequest request, {
    int status = 200,
    Uri? location,
  }) async {
    if (location != null) {
      request.response.headers.set(HttpHeaders.locationHeader, '$location');
    }
    request.response
      ..statusCode = status
      ..write('school response');
    await request.response.close();
  }

  test('Only the records service may use HTTP', () {
    expect(SchoolNetwork.recordsService.scheme, 'http');
    expect(isSchoolUrl(Uri.parse('https://bit.edu.cn')), isTrue);
    expect(isSchoolUrl(Uri.parse('https://jwms.bit.edu.cn/')), isTrue);
    expect(isSchoolUrl(Uri.parse('http://jwms.bit.edu.cn/')), isTrue);
    expect(isSchoolUrl(Uri.parse('http://sso.bit.edu.cn/')), isFalse);
    expect(isSchoolUrl(Uri.parse('https://bit.edu.cn.example.org')), isFalse);
    expect(isSchoolUrl(Uri.parse('https://user@bit.edu.cn/')), isFalse);
    expect(isSchoolUrl(Uri.parse('http://user@jwms.bit.edu.cn/')), isFalse);
  });

  test('A non-object school response is reported as malformed data', () {
    final response = SchoolResponse(
      url: Uri.https('jwms.bit.edu.cn'),
      status: 200,
      location: null,
      bytes: Uint8List.fromList(utf8.encode('[]')),
    );
    expect(() => response.json, throwsFormatException);
  });

  test(
    'The first successful probe wins and only it runs the operation',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final storage = MemorySchoolStorage();
      for (final route in SchoolNetwork.values) {
        await storage.saveCookies(route, route.route(service), [
          Cookie('session', route.name),
        ]);
      }
      final connection = SchoolConnection(storage);
      addTearDown(connection.close);
      final entered = Completer<void>();
      final finish = Completer<String>();
      final used = <SchoolNetwork>[];
      final result = connection.run(service, (session) {
        used.add(session.network);
        entered.complete();
        return finish.future;
      });

      final requests = await probes();
      expect(requests.keys, containsAll(SchoolNetwork.values));
      await reply(requests[SchoolNetwork.webvpn]!);
      await entered.future;
      expect(used, [SchoolNetwork.webvpn]);
      expect(network.clientFor(SchoolNetwork.campus).closed, isTrue);
      expect(network.clientFor(SchoolNetwork.webvpn).closed, isFalse);

      finish.complete('done');
      expect(await result, 'done');
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );

  test(
    'A failed fast probe does not discard a slower reachable route',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      final result = connection.run(
        service,
        (session) async => session.network,
      );
      final requests = await probes();
      await reply(requests[SchoolNetwork.campus]!, status: 503);
      await reply(requests[SchoolNetwork.webvpn]!);
      expect(await result, SchoolNetwork.webvpn);
    }, network),
  );

  test(
    'A login redirect proves reachability without starting authentication',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      final result = connection.run(
        service,
        (session) async => session.network,
      );
      final requests = await probes();
      await reply(
        requests[SchoolNetwork.campus]!,
        status: 302,
        location: Uri.https('sso.bit.edu.cn', '/cas/login'),
      );
      expect(await result, SchoolNetwork.campus);
      expect(network.clients.length, 2);
    }, network),
  );

  test(
    'Route probes target the requested grade service',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      final grades = SchoolNetwork.recordsService;
      final result = connection.run(grades, (session) async => session.network);
      final requests = await probes();
      expect(requests[SchoolNetwork.campus]!.uri.path, '/jwms.bit.edu.cn/');
      expect(
        requests[SchoolNetwork.webvpn]!.uri.path,
        '/webvpn.bit.edu.cn${SchoolNetwork.webvpn.route(grades).path}',
      );
      await reply(requests[SchoolNetwork.webvpn]!);
      expect(await result, SchoolNetwork.webvpn);
    }, network),
  );

  test(
    'WebVPN login keeps its gateway cookie when opening the teaching entry',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final storage = MemorySchoolStorage();
      final sso = Uri.https('sso.bit.edu.cn', '/cas/login');
      await storage.saveCookies(SchoolNetwork.webvpn, sso, [
        Cookie('TGC', 'existing-sso-session')..path = '/',
      ]);
      final session = SchoolSession(
        network: SchoolNetwork.webvpn,
        storage: storage,
      );
      addTearDown(session.close);
      final login = SchoolLogin(
        session,
        (_) async => throw StateError('The SSO session is already signed in'),
      ).signIn(const SchoolCredentials(username: 'student', password: 'test'));
      final expectation = expectLater(login, completes);

      // Open the gateway, then reuse the existing SSO session for its callback.
      await reply(await nextRequest());
      final gatewayLogin = await nextRequest();
      expect(gatewayLogin.uri.pathSegments.first, sso.host);
      await reply(
        gatewayLogin,
        status: 302,
        location: Uri.https('webvpn.bit.edu.cn', '/cas-callback'),
      );
      final gatewayCallback = await nextRequest();
      gatewayCallback.response.cookies.add(Cookie('vpn', 'ready')..path = '/');
      await reply(gatewayCallback);

      final entry = await nextRequest();
      expect(
        entry.uri.path,
        '/webvpn.bit.edu.cn'
        '${SchoolNetwork.webvpn.route(SchoolNetwork.teachingLogin).path}',
      );
      expect(
        entry.headers.value(HttpHeaders.cookieHeader),
        contains('vpn=ready'),
      );
      final accountPage = SchoolNetwork.webvpn.accountPage;
      await reply(
        entry,
        status: 302,
        location: sso.replace(queryParameters: {'service': '$accountPage'}),
      );
      final teachingLogin = await nextRequest();
      expect(teachingLogin.uri.pathSegments.first, sso.host);
      expect(teachingLogin.uri.queryParameters['service'], '$accountPage');
      await reply(
        teachingLogin,
        status: 302,
        location: accountPage.replace(queryParameters: {'ticket': 'test'}),
      );
      await reply(await nextRequest());
      await reply(await nextRequest());
      await reply(await nextRequest());
      await expectation;
    }, network),
  );

  test(
    'Each new operation reselects its route after the network changes',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final access = SchoolAccess(MemorySchoolStorage());
      for (final available in [SchoolNetwork.webvpn, SchoolNetwork.campus]) {
        final used = <SchoolNetwork>[];
        final result = access.read(
          (_) async => throw StateError('No login should be needed'),
          (session) async {
            used.add(session.network);
            return session.network;
          },
        );
        final requests = await probes();
        await reply(requests[available]!);
        expect(await result, available);
        expect(used, [available]);
      }
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );

  for (final first in SchoolNetwork.values) {
    test(
      'A lost $first connection retries the other route once',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final connection = SchoolConnection(MemorySchoolStorage());
        final attempts = <SchoolNetwork>[];
        final other = SchoolNetwork.values.singleWhere((item) => item != first);
        final result = connection.run(service, (session) async {
          attempts.add(session.network);
          if (session.network == first) {
            throw SchoolConnectionError(
              session.network.route(service),
              const SocketException('Network changed'),
            );
          }
          return session.network;
        });
        final requests = await probes();
        await reply(requests[first]!);
        expect(await result, other);
        expect(attempts, [first, other]);
        expect(network.clients.every((client) => client.closed), isTrue);
      }, network),
    );
  }

  test(
    'Connection failure on both operation attempts is returned without looping',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      final attempts = <SchoolNetwork>[];
      final result = connection.run(service, (session) async {
        attempts.add(session.network);
        throw SchoolConnectionError(
          session.network.route(service),
          const SocketException('Disconnected'),
        );
      });
      final expectation = expectLater(
        result,
        throwsA(isA<SchoolConnectionError>()),
      );
      final requests = await probes();
      await reply(requests[SchoolNetwork.webvpn]!);
      await expectation;
      expect(attempts, [SchoolNetwork.webvpn, SchoolNetwork.campus]);
    }, network),
  );

  for (final failure in [
    const SchoolCredentialsRequired('账号或密码错误'),
    const FormatException('Invalid response'),
  ]) {
    test(
      'Non-connection failures are not retried: ${failure.runtimeType}',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final connection = SchoolConnection(MemorySchoolStorage());
        var attempts = 0;
        final result = connection.run(service, (_) async {
          attempts++;
          throw failure;
        });
        final expectation = expectLater(result, throwsA(same(failure)));
        final requests = await probes();
        await reply(requests[SchoolNetwork.campus]!);
        await expectation;
        expect(attempts, 1);
      }, network),
    );
  }

  test(
    'A failed login connection still allows the other route to reuse its session',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final access = SchoolAccess(MemorySchoolStorage());
      final attempts = <SchoolNetwork>[];
      final result = access.read(
        (_) async => throw StateError('The direct session is still valid'),
        (session) async {
          attempts.add(session.network);
          if (session.network == SchoolNetwork.webvpn) {
            throw SchoolConnectionError(
              Uri.https('sso.bit.edu.cn', '/cas/login'),
              const SocketException('SSO unavailable'),
            );
          }
          return 'cached session';
        },
      );
      final requests = await probes();
      await reply(requests[SchoolNetwork.webvpn]!);
      expect(await result, 'cached session');
      expect(attempts, [SchoolNetwork.webvpn, SchoolNetwork.campus]);
    }, network),
  );

  test(
    'When both probes fail, no login or business operation runs',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      var attempts = 0;
      final result = connection.run(service, (_) async => attempts++);
      final expectation = expectLater(
        result,
        throwsA(isA<SchoolConnectionError>()),
      );
      final requests = await probes();
      await reply(requests[SchoolNetwork.campus]!, status: 503);
      await reply(requests[SchoolNetwork.webvpn]!, status: 403);
      await expectation;
      expect(attempts, 0);
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );

  test(
    'Cancelling during route selection closes both probes immediately',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final access = SchoolAccess(MemorySchoolStorage());
      final cancellation = CancellationToken();
      var attempts = 0;
      final result = access.read(
        (_) async => throw StateError('No verification should open'),
        (_) async => attempts++,
        cancellation: cancellation,
      );
      final expectation = expectLater(result, throwsA(isA<RequestCancelled>()));
      await probes();
      cancellation.cancel();
      await expectation;
      expect(attempts, 0);
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );

  test(
    'Cancelling an active operation does not start a fallback request',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      var attempts = 0;
      final result = connection.run(service, (session) {
        attempts++;
        return session.request(session.network.accountConfig);
      });
      final expectation = expectLater(result, throwsA(isA<RequestCancelled>()));
      final requests = await probes();
      await reply(requests[SchoolNetwork.campus]!);
      await nextRequest();
      connection.close();
      await expectation;
      expect(attempts, 1);
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );

  for (final source in [DeadlineSource.lexue, DeadlineSource.eclass]) {
    for (final stillExpired in [false, true]) {
      test(
        '${source.label} retries authentication once when a DDL read expires, stillExpired=$stillExpired',
        () => HttpOverrides.runWithHttpOverrides(() async {
          final access = SchoolAccess(MemorySchoolStorage());
          var reads = 0;
          final result = access.readLearningPlatform(
            source,
            (_) async =>
                throw StateError('The platform session is already valid'),
            (session, page) async {
              reads++;
              if (reads == 1 || stillExpired) throw const SessionExpired();
              return 'deadlines';
            },
          );
          final expectation = stillExpired
              ? expectLater(result, throwsA(isA<SessionExpired>()))
              : expectLater(result, completion('deadlines'));
          for (var attempt = 0; attempt < 2; attempt++) {
            final request = await nextRequest();
            expect(request.uri.path, '/${source.host}${source.loginPage.path}');
            await reply(request);
          }
          await expectation;
          expect(reads, 2);
          expect(network.clients.every((client) => client.closed), isTrue);
        }, network),
      );
    }

    test(
      '${source.label} uses one direct request without probing WebVPN',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final connection = SchoolConnection(MemorySchoolStorage());
        final result = connection.run(source.loginPage, (session) {
          expect(session.network, SchoolNetwork.campus);
          return session.request(source.loginPage);
        });
        final request = await nextRequest();
        expect(request.uri.pathSegments.first, source.host);
        expect(network.clients.length, 1);
        await reply(request);
        expect((await result).status, 200);
      }, network),
    );
  }

  test(
    'Unresponsive probes time out and close their connections',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final connection = SchoolConnection(MemorySchoolStorage());
      var attempts = 0;
      final result = connection.run(service, (_) async => attempts++);
      final expectation = expectLater(
        result,
        throwsA(
          isA<SchoolConnectionError>().having(
            (failure) => failure.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      await probes();
      await expectation;
      expect(attempts, 0);
      expect(network.clients.every((client) => client.closed), isTrue);
    }, network),
  );
}
