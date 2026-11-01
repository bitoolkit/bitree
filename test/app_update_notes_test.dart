import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:bitree/l10n/app_localizations_en.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/updates/release.dart';
import 'package:bitree/updates/repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

Map<String, dynamic> _release({required bool development}) => {
  'tag_name': development ? 'v0.3.0-dev' : 'v0.3.0',
  'html_url':
      'https://github.com/bitoolkit/bitree/releases/tag/${development ? 'v0.3.0-dev' : 'v0.3.0'}',
  'body': '## Unreleased\n\n- 已安装的旧变更\n- 更早的历史变更',
  'published_at': '2026-10-27T10:00:00Z',
  'prerelease': development,
  'assets': development
      ? [
          {
            'name': 'BITree-${Platform.operatingSystem}-update.json',
            'browser_download_url': 'https://downloads.example/update.json',
          },
          if (Platform.isLinux)
            {
              'name': 'BITree-linux-arm64-update.json',
              'browser_download_url':
                  'https://downloads.example/arm64-update.json',
            },
        ]
      : [],
};

List<Map<String, dynamic>> _commits(int count, {String head = '3333333'}) => [
  for (var index = 1; index <= count; index++)
    {
      'sha': (index == count ? head : index.toRadixString(16).padLeft(7, '0'))
          .padRight(40, '0'),
      'html_url': 'https://github.com/bitoolkit/bitree/commit/change-$index',
      'commit': {'message': '变更 $index\n\n提交正文不应进入摘要'},
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late LocalHttpOverrides network;
  late List<Uri> requests;
  late Map<String, List<Map<String, dynamic>>> changes;
  late Map<String, dynamic>? stable;
  late Map<String, dynamic>? development;
  late String developmentVersion;
  late int compareStatus;
  late int discoveryStatus;

  setUp(() async {
    requests = [];
    changes = {};
    stable = null;
    development = _release(development: true);
    developmentVersion = 'v0.3.0-dev.3333333';
    compareStatus = HttpStatus.ok;
    discoveryStatus = HttpStatus.ok;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    network = LocalHttpOverrides(server.port);
    server.listen((request) async {
      requests.add(request.uri);
      Object? data;
      switch (request.uri.path) {
        case '/api.github.com/repos/bitoolkit/bitree/releases/latest':
          request.response.statusCode = stable == null
              ? HttpStatus.notFound
              : discoveryStatus;
          data = stable;
        case '/api.github.com/repos/bitoolkit/bitree/releases':
          request.response.statusCode = discoveryStatus;
          data = [?development];
        case '/downloads.example/update.json':
        case '/downloads.example/arm64-update.json':
          data = {
            'version': developmentVersion,
            'builtAt': '2026-10-27T09:00:00Z',
          };
        default:
          final entries = changes[request.uri.pathSegments.last];
          request.response.statusCode = entries == null
              ? HttpStatus.notFound
              : compareStatus;
          if (entries != null) {
            final page = int.parse(request.uri.queryParameters['page']!);
            final pageSize = int.parse(
              request.uri.queryParameters['per_page']!,
            );
            data = {
              'total_commits': entries.length,
              'commits': entries
                  .skip((page - 1) * pageSize)
                  .take(pageSize)
                  .toList(),
            };
          }
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(data));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    expect(network.clients.every((client) => client.closed), isTrue);
  });

  Future<List<AppRelease>> read(String installed, {DateTime? builtAt}) =>
      HttpOverrides.runWithHttpOverrides(
        () => availableAppReleases(
          installed,
          builtAt: builtAt,
          l10n: AppLocalizationsZh(),
        ),
        network,
      );

  if (Platform.isLinux) {
    test(
      'Metadata for another Linux architecture does not announce an update',
      () async {
        final other = Abi.current() == Abi.linuxArm64 ? 'linux' : 'linux-arm64';
        development!['assets'] = [
          {
            'name': 'BITree-$other-update.json',
            'browser_download_url': 'https://downloads.example/update.json',
          },
        ];
        expect(await read('v0.3.0-dev.1111111'), isEmpty);
        expect(
          requests.where((url) => url.path.startsWith('/downloads.example/')),
          isEmpty,
        );
      },
    );
  }

  test(
    'Development notes compare exact installed and downloaded commits',
    () async {
      changes['1111111...3333333'] = _commits(2);
      final release = (await read('v0.3.0-dev.1111111')).single;
      expect(release.version, developmentVersion);
      expect(release.notes, contains('变更 2'));
      expect(
        release.notes.indexOf('变更 2'),
        lessThan(release.notes.indexOf('变更 1')),
      );
      expect(release.notes, isNot(contains('旧变更')));
      expect(release.notes, isNot(contains('历史变更')));
      expect(release.notes, isNot(contains('提交正文')));
      expect(release.notes, isNot(contains('另有')));
      expect(
        requests.where((url) => url.path.contains('/compare/')).single.path,
        endsWith('/1111111...3333333'),
      );
    },
  );

  test(
    'Stable updates include all changes since the installed release',
    () async {
      development = null;
      stable = _release(development: false);
      changes['v0.1.0...v0.3.0'] = _commits(3);
      final release = (await read('0.1.0')).single;
      expect(release.isDevelopment, isFalse);
      expect(release.notes, contains('变更 3'));
      expect(release.notes, contains('变更 1'));
      expect(release.notes, isNot(contains('历史变更')));
    },
  );

  test(
    'Moving from development to stable excludes already installed changes',
    () async {
      development = null;
      stable = _release(development: false);
      changes['1111111...v0.3.0'] = _commits(1);
      final release = (await read('v0.3.0-dev.1111111')).single;
      expect(release.version, 'v0.3.0');
      expect(release.notes, contains('变更 1'));
      expect(release.notes, isNot(contains('已安装')));
    },
  );

  test(
    'A stable release without published_at still compares its version',
    () async {
      development = null;
      stable = _release(development: false)..remove('published_at');
      changes['1111111...v0.3.0'] = _commits(1);

      final release = (await read(
        'v0.3.0-dev.1111111',
        builtAt: DateTime.utc(2026, 10, 28),
      )).single;

      expect(release.version, 'v0.3.0');
      expect(release.notes, contains('变更 1'));
    },
  );

  test('Stable and development choices keep separate version ranges', () async {
    stable = _release(development: false);
    changes['v0.2.0...v0.3.0'] = _commits(1);
    changes['v0.2.0...3333333'] = _commits(2);
    final releases = await read('v0.2.0');
    expect(releases, hasLength(2));
    expect(releases.first.notes, isNot(contains('变更 2')));
    expect(releases.last.notes, contains('变更 2'));
    expect(releases.first.url.path, endsWith('/v0.3.0'));
    expect(releases.last.url.path, endsWith('/v0.3.0-dev'));
  });

  for (final (count, pages) in [
    (6, [1]),
    (102, [1, 2]),
    (106, [1, 2]),
    (305, [1, 4, 3]),
  ]) {
    test(
      'Shows the newest six of $count changes without reading unused pages',
      () async {
        changes['1111111...3333333'] = _commits(count);
        final release = (await read('v0.3.0-dev.1111111')).single;
        final bullets = const LineSplitter()
            .convert(release.notes)
            .where((line) => line.startsWith('- '))
            .toList();
        expect(bullets, hasLength(6));
        expect(bullets.first, contains('变更 $count '));
        expect(bullets.last, contains('变更 ${count - 5} '));
        if (count > 6) {
          expect(release.notes, contains('另有 ${count - 6} 项变更'));
          expect(
            release.notes,
            contains(
              'https://github.com/bitoolkit/bitree/compare/1111111...3333333',
            ),
          );
        }
        expect(
          requests
              .where((url) => url.path.contains('/compare/'))
              .map((url) => int.parse(url.queryParameters['page']!))
              .toList(),
          pages,
        );
      },
    );
  }

  test('No available update makes no changelog request', () async {
    stable = _release(development: false);
    expect(await read('v0.3.0', builtAt: DateTime.utc(2026, 10, 28)), isEmpty);
    expect(requests.where((url) => url.path.contains('/compare/')), isEmpty);
  });

  test('Generated update summaries follow the selected language', () async {
    changes['1111111...3333333'] = _commits(8);
    final release = (await HttpOverrides.runWithHttpOverrides(
      () => availableAppReleases(
        'v0.3.0-dev.1111111',
        l10n: AppLocalizationsEn(),
      ),
      network,
    )).single;

    expect(release.notes, contains('Plus 2 more changes.'));
    expect(release.notes, contains('[View full changes]'));
  });

  test(
    'Rebuilding the same commit does not request or repeat historical notes',
    () async {
      final release = (await read(
        'v0.3.0-dev.3333333',
        builtAt: DateTime.utc(2026, 10, 26),
      )).single;
      expect(release.notes, contains('此版本没有代码变更。'));
      expect(requests.where((url) => url.path.contains('/compare/')), isEmpty);
    },
  );

  test('An empty comparison does not fall back to cumulative notes', () async {
    changes['1111111...3333333'] = [];
    final release = (await read('v0.3.0-dev.1111111')).single;
    expect(release.notes, contains('此版本没有代码变更。'));
    expect(release.notes, isNot(contains('旧变更')));
  });

  for (final status in [HttpStatus.notFound, HttpStatus.serviceUnavailable]) {
    test(
      'A $status changelog failure keeps release and download actions available',
      () async {
        compareStatus = status;
        changes['1111111...3333333'] = _commits(1);
        final release = (await read('v0.3.0-dev.1111111')).single;
        expect(release.version, developmentVersion);
        expect(release.url.path, endsWith('/v0.3.0-dev'));
        expect(release.downloadUrl, release.url);
        expect(release.notes, '暂时无法读取更新说明。');
        expect(release.notes, isNot(contains('旧变更')));
      },
    );
  }

  group('Local update results', () {
    late MemoryPreferences preferences;

    setUp(() {
      preferences = MemoryPreferences();
      stable = _release(development: false);
      changes['v0.2.0...v0.3.0'] = _commits(1);
      changes['v0.2.0...3333333'] = _commits(2);
    });

    Future<List<AppRelease>> check({
      String installed = 'v0.2.0',
      DateTime? builtAt,
      bool automatic = true,
    }) => HttpOverrides.runWithHttpOverrides(
      () => UpdateRepository(
        preferences,
        l10n: AppLocalizationsZh(),
      ).check(installed, builtAt: builtAt, automatic: automatic),
      network,
    );

    test(
      'Automatic checks prompt only for stable and reuse results after restart',
      () async {
        final original = (await check()).single;
        expect(original.isDevelopment, isFalse);
        final saved =
            jsonDecode((await preferences.getString('updates.cache'))!) as Map;
        expect(saved['releases'], hasLength(2));
        requests.clear();
        final cached = (await check()).single;
        expect(cached.version, original.version);
        expect(cached.notes, original.notes);
        expect(cached.url, original.url);
        expect(cached.downloadUrl, original.downloadUrl);
        expect(requests, isEmpty);
      },
    );

    test('Development updates are cached silently and remain available to manual checks', () async {
      stable = null;
      expect(await check(), isEmpty);
      final saved =
          jsonDecode((await preferences.getString('updates.cache'))!) as Map;
      expect((saved['releases'] as List).single['isDevelopment'], isTrue);
      expect(
        await preferences.getString('updates.dev.notifiedVersion'),
        isNull,
      );
      requests.clear();
      final release = (await check(automatic: false)).single;
      expect(release.isDevelopment, isTrue);
      expect(requests, isNotEmpty);
    });

    test(
      'No-update results are also reused without another network request',
      () async {
        stable = null;
        development = null;
        expect(await check(), isEmpty);
        expect(requests, isNotEmpty);
        requests.clear();
        expect(await check(), isEmpty);
        expect(requests, isEmpty);
      },
    );

    test('Notified stable versions stay quiet, while manual checks refresh both channels', () async {
      final shown = await check();
      await UpdateRepository(
        preferences,
        l10n: AppLocalizationsZh(),
      ).markNotified(shown);
      requests.clear();
      expect(await check(), isEmpty);
      expect(requests, isEmpty);
      final manual = await check(automatic: false);
      expect(manual.map((release) => release.isDevelopment), [false, true]);
      expect(requests, isNotEmpty);
    });

    test(
      'Cached reads keep the original expiry and refresh after 24 hours',
      () async {
        await check();
        final saved = jsonDecode(
          (await preferences.getString('updates.cache'))!,
        ) as Map<String, dynamic>;
        final original = DateTime.now()
            .subtract(const Duration(hours: 23))
            .millisecondsSinceEpoch;
        saved['checkedAt'] = original;
        await preferences.setString('updates.cache', jsonEncode(saved));
        requests.clear();
        expect(await check(), hasLength(1));
        expect(requests, isEmpty);
        expect(
          (jsonDecode((await preferences.getString('updates.cache'))!)
              as Map)['checkedAt'],
          original,
        );
        saved['checkedAt'] = DateTime.now()
            .subtract(const Duration(hours: 25))
            .millisecondsSinceEpoch;
        await preferences.setString('updates.cache', jsonEncode(saved));
        await check();
        expect(requests, isNotEmpty);
      },
    );

    test(
      'Changing the installed version starts a new changelog comparison',
      () async {
        await check();
        requests.clear();
        changes['v0.1.0...v0.3.0'] = _commits(3);
        changes['v0.1.0...3333333'] = _commits(4);
        final result = await check(installed: 'v0.1.0');
        expect(result.single.notes, contains('变更 3'));
        expect(requests, isNotEmpty);
      },
    );

    test(
      'A rebuilt installed package invalidates the previous result',
      () async {
        await check(builtAt: DateTime.utc(2026, 10, 26));
        requests.clear();
        await check(builtAt: DateTime.utc(2026, 10, 26, 1));
        expect(requests, isNotEmpty);
      },
    );

    test(
      'Cached downloads from another architecture are never reused',
      () async {
        await check();
        final saved = jsonDecode(
          (await preferences.getString('updates.cache'))!,
        ) as Map<String, dynamic>;
        saved['abi'] = 'another-device-architecture';
        await preferences.setString('updates.cache', jsonEncode(saved));
        requests.clear();
        await check();
        expect(requests, isNotEmpty);
      },
    );

    test(
      'An unreadable cache is replaced by a successful network result',
      () async {
        await preferences.setString('updates.cache', '{');
        expect(await check(), hasLength(1));
        final saved =
            jsonDecode((await preferences.getString('updates.cache'))!) as Map;
        expect(saved['installed'], 'v0.2.0');
        expect(saved['releases'], hasLength(2));
      },
    );

    test(
      'An out-of-range cached timestamp is replaced by fresh results',
      () async {
        await check();
        final saved = jsonDecode(
          (await preferences.getString('updates.cache'))!,
        ) as Map<String, dynamic>;
        saved['checkedAt'] = 8640000000000001;
        await preferences.setString('updates.cache', jsonEncode(saved));
        requests.clear();

        expect(await check(), hasLength(1));
        expect(requests, isNotEmpty);
      },
    );

    test('Failed checks are not cached as no-update results', () async {
      discoveryStatus = HttpStatus.serviceUnavailable;
      await expectLater(check(), throwsA(isA<HttpException>()));
      expect(await preferences.getString('updates.cache'), isNull);
      discoveryStatus = HttpStatus.ok;
      requests.clear();
      expect(await check(), hasLength(1));
      expect(requests, isNotEmpty);
    });
  });

  test('Release discovery errors still reach the update caller', () async {
    discoveryStatus = HttpStatus.serviceUnavailable;
    await expectLater(
      read('v0.3.0-dev.1111111'),
      throwsA(isA<HttpException>()),
    );
  });
}
