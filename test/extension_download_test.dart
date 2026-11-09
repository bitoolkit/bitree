import 'dart:convert';
import 'dart:typed_data';

import 'package:bitree/extensions/download.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/sha256.dart';

Map<String, Object?> _bundle({
  String id = 'test.download',
  String entry = 'source.lua',
  Map<String, Object?>? files,
}) => {
  'manifest': {
    'id': id,
    'name': {'zh': '下载测试'},
    'version': '1.0.0',
    'apiVersion': 1,
    'sources': [
      {
        'id': 'source',
        'entry': entry,
        'operations': ['courses.list'],
      },
    ],
  },
  'files': files ?? {entry: 'return { operations = {} }\n'},
};

String _sha256(List<int> bytes) => [
  for (final byte in SHA256Digest().process(Uint8List.fromList(bytes)))
    byte.toRadixString(16).padLeft(2, '0'),
].join();

void main() {
  test('accepts a bundle whose SHA-256 matches', () async {
    final bytes = utf8.encode(jsonEncode(_bundle()));
    final downloader = ExtensionDownloader(
      fetch: (_) async => bytes,
    );

    final bundle = await downloader.inspect(
      url: Uri.parse('https://example.com/extension.json'),
      sha256: _sha256(bytes),
    );

    expect(bundle.manifest.id, 'test.download');
    expect(bundle.sources['source.lua'], contains('operations'));
  });

  test('rejects a digest mismatch before parsing the bundle', () async {
    final downloader = ExtensionDownloader(
      fetch: (_) async => utf8.encode(jsonEncode(_bundle())),
    );

    await expectLater(
      downloader.inspect(
        url: Uri.parse('https://example.com/extension.json'),
        sha256: List.filled(64, '0').join(),
      ),
      throwsA(
        isA<ExtensionDownloadException>().having(
          (error) => error.code,
          'code',
          'digest_mismatch',
        ),
      ),
    );
  });

  test('only permits a plain HTTPS URL', () async {
    final downloader = ExtensionDownloader(fetch: (_) async => const []);
    for (final url in [
      Uri.parse('http://example.com/extension.json'),
      Uri.parse('https://user@example.com/extension.json'),
      Uri.parse('https://example.com:8443/extension.json'),
    ]) {
      await expectLater(
        downloader.inspect(
          url: url,
          sha256: List.filled(64, '0').join(),
        ),
        throwsA(
          isA<ExtensionDownloadException>().having(
            (error) => error.code,
            'code',
            'invalid_url',
          ),
        ),
      );
    }
  });

  test('rejects bundles whose files do not match manifest entries', () {
    expect(
      () => ExtensionBundle.parse(
        _bundle(files: {'other.lua': 'return { operations = {} }\n'}),
      ),
      throwsA(
        isA<ExtensionDownloadException>().having(
          (error) => error.code,
          'code',
          'invalid_bundle',
        ),
      ),
    );
  });

  test('rejects oversized downloads', () async {
    final bytes = utf8.encode(jsonEncode(_bundle()));
    final downloader = ExtensionDownloader(
      maxBytes: 1,
      fetch: (_) async => bytes,
    );

    await expectLater(
      downloader.inspect(
        url: Uri.parse('https://example.com/extension.json'),
        sha256: _sha256(bytes),
      ),
      throwsA(
        isA<ExtensionDownloadException>().having(
          (error) => error.code,
          'code',
          'too_large',
        ),
      ),
    );
  });
}
