import 'package:bitree/sources/source.dart';
import 'package:bitree/sources/transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transport = SourceHttpTransport();
  final permissions = SourcePermissions(
    networkHosts: const ['https://example.com'],
  );

  test(
    'HTTP transport rejects origins outside the source declaration',
    () async {
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://other.example/data',
        }),
        throwsA(
          isA<SourceHttpException>().having(
            (error) => error.code,
            'code',
            'permission_denied',
          ),
        ),
      );
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://example.com:444/data',
        }),
        throwsA(isA<SourceHttpException>()),
      );
    },
  );

  test(
    'HTTP transport does not expose credential headers to scripts',
    () async {
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://example.com/data',
          'headers': {'Cookie': 'session=secret'},
        }),
        throwsA(
          isA<SourceHttpException>().having(
            (error) => error.code,
            'code',
            'permission_denied',
          ),
        ),
      );
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://example.com/data',
          'headers': {'Authorization': 'Bearer secret'},
        }),
        throwsA(isA<SourceHttpException>()),
      );
    },
  );

  test(
    'HTTP transport rejects malformed bodies before opening a request',
    () async {
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://example.com/data',
          'method': 'GET',
          'body': 'not allowed',
        }),
        throwsA(isA<SourceHttpException>()),
      );
      await expectLater(
        transport.request('instance', permissions, {
          'url': 'https://example.com/data',
          'form': {'term': '2026-2'},
          'json': {'term': '2026-2'},
        }),
        throwsA(isA<SourceHttpException>()),
      );
    },
  );

  test('network permissions reject non-default HTTPS ports', () {
    expect(permissions.allows(Uri.parse('https://example.com/data')), isTrue);
    expect(
      permissions.allows(Uri.parse('https://example.com:444/data')),
      isFalse,
    );
    expect(
      permissions.allows(Uri.parse('https://user@example.com/data')),
      isFalse,
    );
  });
}
