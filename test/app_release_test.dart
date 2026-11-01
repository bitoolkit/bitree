import 'dart:ffi';

import 'package:bitree/updates/release.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _release(
  List<String> names, {
  bool development = false,
}) => {
  'tag_name': development ? 'v0.2.0-dev' : 'v0.2.0',
  'html_url': 'https://github.com/bitoolkit/bitree/releases/tag/v0.2.0',
  'body': '更新说明',
  'prerelease': development,
  'assets': [
    for (final name in names)
      {'name': name, 'browser_download_url': 'https://downloads.example/$name'},
  ],
};

void main() {
  for (final suffix in ['', '-debug-signed']) {
    test('Selects the ARM64 APK with suffix "$suffix"', () {
      final release = AppRelease.fromGitHub(
        _release([
          for (final architecture in ['armeabi-v7a', 'arm64-v8a', 'x86_64'])
            'BITree-v0.2.0-android-$architecture$suffix.apk',
          'BITree-v0.2.0-android.aab',
          'BITree-v0.2.0-windows-x64-setup-unsigned.exe',
        ]),
        abi: Abi.androidArm64,
      );
      expect(
        release.downloadUrl.path,
        endsWith('-android-arm64-v8a$suffix.apk'),
      );
      expect(release.url.path, '/bitoolkit/bitree/releases/tag/v0.2.0');
      expect(release.version, 'v0.2.0');
      expect(release.notes, '更新说明');
    });
  }

  for (final (abi, architecture) in [
    (Abi.linuxX64, 'x64'),
    (Abi.linuxArm64, 'arm64'),
  ]) {
    test('Selects the Linux $architecture package', () {
      final release = AppRelease.fromGitHub(
        _release([
          'BITree-v0.2.0-linux-x64.tar.xz',
          'BITree-v0.2.0-linux-arm64.tar.xz',
          'BITree-v0.2.0-android-arm64-v8a.apk',
        ]),
        abi: abi,
      );
      expect(release.downloadUrl.path, endsWith('-linux-$architecture.tar.xz'));
    });
  }

  test('Removed Android architectures use the release page', () {
    final data = _release([
      'BITree-v0.2.0-android-armeabi-v7a.apk',
      'BITree-v0.2.0-android-x86_64.apk',
      'BITree-v0.2.0-android-arm64-v8a.apk',
    ]);
    for (final abi in [Abi.androidArm, Abi.androidX64, Abi.androidIA32]) {
      final release = AppRelease.fromGitHub(data, abi: abi);
      expect(release.downloadUrl, release.url);
    }
  });

  test('Prefers the release-signed APK when both signing variants exist', () {
    final release = AppRelease.fromGitHub(
      _release([
        'BITree-v0.2.0-android-arm64-v8a-debug-signed.apk',
        'BITree-v0.2.0-android-arm64-v8a.apk',
      ]),
      abi: Abi.androidArm64,
    );
    expect(release.downloadUrl.path, endsWith('-android-arm64-v8a.apk'));
  });

  test(
    'Missing matching APK uses the release page, never another architecture',
    () {
      final data = _release(['BITree-v0.2.0-android-x86_64.apk']);
      for (final abi in [
        Abi.androidArm64,
        Abi.androidArm,
        Abi.linuxX64,
        Abi.linuxArm64,
        Abi.iosArm64,
      ]) {
        final release = AppRelease.fromGitHub(data, abi: abi);
        expect(release.downloadUrl, release.url);
      }
    },
  );

  test('A missing Linux architecture never selects the other package', () {
    for (final (abi, other) in [
      (Abi.linuxX64, 'arm64'),
      (Abi.linuxArm64, 'x64'),
    ]) {
      final release = AppRelease.fromGitHub(
        _release(['BITree-v0.2.0-linux-$other.tar.xz']),
        abi: abi,
      );
      expect(release.downloadUrl, release.url);
    }
  });

  test('Development metadata version preserves its release page and APK', () {
    final release = AppRelease.fromGitHub(
      _release([
        'BITree-v0.2.0-abc1234-android-arm64-v8a.apk',
      ], development: true),
      abi: Abi.androidArm64,
      version: 'v0.2.0-abc1234',
    );
    expect(release.version, 'v0.2.0-abc1234');
    expect(release.isDevelopment, isTrue);
    expect(release.downloadUrl.path, endsWith('abc1234-android-arm64-v8a.apk'));
  });

  test('Missing optional release fields use safe defaults', () {
    final data = _release(['BITree-v0.2.0-android-arm64-v8a.apk'])
      ..remove('body')
      ..remove('prerelease')
      ..remove('assets');

    final release = AppRelease.fromGitHub(data, abi: Abi.androidArm64);

    expect(release.downloadUrl, release.url);
    expect(release.notes, isEmpty);
    expect(release.isDevelopment, isFalse);
  });

  test('Rejects non-HTTPS release and download links', () {
    final data = _release(['BITree-v0.2.0-android-arm64-v8a.apk']);
    data['html_url'] = 'http://github.com/bitoolkit/bitree/releases/tag/v0.2.0';
    expect(
      () => AppRelease.fromGitHub(data, abi: Abi.androidArm64),
      throwsFormatException,
    );

    data['html_url'] =
        'https://github.com/bitoolkit/bitree/releases/tag/v0.2.0';
    (data['assets'] as List).single['browser_download_url'] =
        'http://downloads.example/app.apk';
    expect(
      () => AppRelease.fromGitHub(data, abi: Abi.androidArm64),
      throwsFormatException,
    );
  });
}
