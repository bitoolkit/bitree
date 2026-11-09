import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

import 'package.dart';

class ExtensionDownloadException implements Exception {
  const ExtensionDownloadException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class ExtensionBundle {
  const ExtensionBundle({required this.manifest, required this.sources});

  factory ExtensionBundle.parse(Object? value) {
    try {
      if (value is! Map) {
        throw const ExtensionDownloadException(
          'invalid_bundle',
          '扩展包下载内容必须是 JSON 对象。',
        );
      }
      final json = Map<String, dynamic>.from(value);
      final manifest = ExtensionManifest.parse(json['manifest']);
      final rawFiles = json['files'];
      if (rawFiles is! Map) {
        throw const ExtensionDownloadException(
          'invalid_bundle',
          '扩展包缺少 files 对象。',
        );
      }
      final files = <String, String>{};
      for (final entry in rawFiles.entries) {
        final name = entry.key;
        final source = entry.value;
        if (name is! String || source is! String) {
          throw const ExtensionDownloadException(
            'invalid_bundle',
            '扩展包文件必须是文本键值。',
          );
        }
        files[name] = source;
      }
      final entries = {
        for (final source in manifest.sources) source.entry,
      };
      if (files.keys.toSet().difference(entries).isNotEmpty ||
          entries.difference(files.keys.toSet()).isNotEmpty) {
        throw const ExtensionDownloadException(
          'invalid_bundle',
          '扩展包文件与 manifest 入口不一致。',
        );
      }
      return ExtensionBundle(manifest: manifest, sources: files);
    } on FormatException catch (failure) {
      throw ExtensionDownloadException('invalid_bundle', failure.message);
    }
  }

  final ExtensionManifest manifest;
  final Map<String, String> sources;
}

typedef ExtensionFetch = Future<List<int>> Function(Uri url);

class ExtensionDownloader {
  ExtensionDownloader({
    this.timeout = const Duration(seconds: 30),
    this.maxBytes = 2 * 1024 * 1024,
    this.fetch,
  });

  final Duration timeout;
  final int maxBytes;
  final ExtensionFetch? fetch;

  Future<ExtensionBundle> inspect({
    required Uri url,
    required String sha256,
  }) async {
    if (url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        (url.hasPort && url.port != 443)) {
      throw const ExtensionDownloadException(
        'invalid_url',
        '扩展包地址必须是 HTTPS，且不能包含用户信息或非 443 端口。',
      );
    }
    final expected = sha256.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      throw const ExtensionDownloadException(
        'invalid_digest',
        'SHA-256 必须是 64 位十六进制文本。',
      );
    }
    final bytes = await (fetch?.call(url) ?? _fetchHttps(url));
    if (bytes.length > maxBytes) {
      throw ExtensionDownloadException(
        'too_large',
        '扩展包超过 ${maxBytes ~/ (1024 * 1024)} MiB。',
      );
    }
    final actual = _hex(SHA256Digest().process(Uint8List.fromList(bytes)));
    if (!_sameDigest(actual, expected)) {
      throw const ExtensionDownloadException(
        'digest_mismatch',
        '扩展包 SHA-256 不匹配，已拒绝安装。',
      );
    }
    try {
      return ExtensionBundle.parse(
        jsonDecode(utf8.decode(bytes, allowMalformed: false)),
      );
    } on FormatException catch (failure) {
      throw ExtensionDownloadException('invalid_bundle', failure.message);
    }
  }

  Future<List<int>> _fetchHttps(Uri url) async {
    final client = HttpClient();
    try {
      var current = url;
      for (var redirects = 0; redirects <= 3; redirects++) {
        final request = await client.getUrl(current).timeout(timeout);
        request.followRedirects = false;
        final response = await request.close().timeout(timeout);
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || location.isEmpty || redirects == 3) {
            throw const ExtensionDownloadException(
              'invalid_response',
              '扩展包下载重定向次数过多。',
            );
          }
          await response.drain<void>();
          current = current.resolve(location);
          if (current.scheme != 'https' ||
              current.host.isEmpty ||
              current.userInfo.isNotEmpty ||
              (current.hasPort && current.port != 443)) {
            throw const ExtensionDownloadException(
              'invalid_response',
              '扩展包下载被重定向到不安全的地址。',
            );
          }
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw ExtensionDownloadException(
            'http_error',
            '扩展包下载失败：HTTP ${response.statusCode}。',
          );
        }
        final builder = BytesBuilder(copy: false);
        var length = 0;
        await for (final chunk in response.timeout(timeout)) {
          length += chunk.length;
          if (length > maxBytes) {
            throw ExtensionDownloadException(
              'too_large',
              '扩展包超过 ${maxBytes ~/ (1024 * 1024)} MiB。',
            );
          }
          builder.add(chunk);
        }
        return builder.takeBytes();
      }
      throw const ExtensionDownloadException(
        'invalid_response',
        '扩展包下载重定向次数过多。',
      );
    } on TimeoutException {
      throw const ExtensionDownloadException('timeout', '扩展包下载超时。');
    } on IOException catch (failure) {
      throw ExtensionDownloadException('network', '扩展包下载失败：$failure');
    } finally {
      client.close(force: true);
    }
  }

  static String _hex(List<int> bytes) => [
    for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
  ].join();

  static bool _sameDigest(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
