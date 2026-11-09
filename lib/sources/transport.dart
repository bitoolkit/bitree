import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';

import 'source.dart';

class SourceHttpException implements Exception {
  const SourceHttpException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

/// HTTP boundary for source scripts. Scripts choose a logical URL and body;
/// this class enforces declared origins, strips credential headers, follows
/// only allowed redirects, and keeps cookies per source instance.
class SourceHttpTransport {
  SourceHttpTransport({
    this.timeout = const Duration(seconds: 30),
    this.maxResponseBytes = 8 * 1024 * 1024,
  });

  final Duration timeout;
  final int maxResponseBytes;
  final Map<String, CookieJar> _cookies = {};

  CookieJar _jarFor(String instanceId) =>
      _cookies.putIfAbsent(instanceId, CookieJar.new);

  Future<Map<String, Object?>> request(
    String instanceId,
    SourcePermissions permissions,
    Map<String, Object?> request, {
    bool Function()? isCancelled,
  }) async {
    if (permissions.networkHosts.isEmpty) {
      throw const SourceHttpException('permission_denied', '该来源没有网络访问权限');
    }
    final rawUrl = request['url'];
    if (rawUrl is! String) {
      throw const SourceHttpException('invalid_request', 'HTTP 请求缺少 url');
    }
    final parsedUrl = Uri.tryParse(rawUrl);
    if (parsedUrl == null) {
      throw const SourceHttpException('invalid_request', 'HTTP 请求 url 无效');
    }
    var current = parsedUrl;
    _requireAllowed(permissions, current);

    var method = _method(request['method'], request);
    final headers = _requestHeaders(request['headers']);
    var body = _requestBody(request, headers);
    if ((method == 'GET' || method == 'HEAD') && body != null) {
      throw const SourceHttpException('invalid_request', 'GET 和 HEAD 请求不能携带正文');
    }
    final redirectLimit = _redirectLimit(request['maxRedirects']);
    final query = request['query'];
    if (query != null) {
      if (query is! Map) {
        throw const SourceHttpException('invalid_request', 'HTTP query 必须是对象');
      }
      current = current.replace(
        queryParameters: {
          ...current.queryParameters,
          for (final entry in query.entries)
            '${entry.key}': _queryValue(entry.value),
        },
      );
    }

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      var redirects = 0;
      while (true) {
        _checkCancelled(isCancelled);
        final request = await client.openUrl(method, current).timeout(timeout);
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
        if (body != null) request.add(body);
        final cookies = await _jarFor(instanceId).loadForRequest(current);
        if (cookies.isNotEmpty) {
          request.headers.set(
            HttpHeaders.cookieHeader,
            cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; '),
          );
        }

        final response = await request.close().timeout(timeout);
        _checkCancelled(isCancelled);
        await _jarFor(instanceId).saveFromResponse(current, response.cookies);

        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || location.isEmpty) {
            throw const SourceHttpException('invalid_response', 'HTTP 重定向缺少目标');
          }
          if (redirects >= redirectLimit) {
            throw const SourceHttpException('invalid_response', 'HTTP 重定向次数过多');
          }
          final next = current.resolve(location);
          _requireAllowed(permissions, next);
          await response.drain<void>();
          redirects++;
          current = next;
          if (response.statusCode == HttpStatus.seeOther ||
              (response.statusCode != HttpStatus.temporaryRedirect &&
                  response.statusCode != HttpStatus.permanentRedirect &&
                  method != 'GET' &&
                  method != 'HEAD')) {
            method = 'GET';
            body = null;
            headers
              ..remove(HttpHeaders.contentTypeHeader)
              ..remove(HttpHeaders.contentLengthHeader);
          }
          continue;
        }

        final bytes = await _readBytes(response, isCancelled);
        final responseHeaders = <String, Object?>{};
        response.headers.forEach((name, values) {
          final lower = name.toLowerCase();
          if (!_sensitiveHeaders.contains(lower)) {
            responseHeaders[lower] = values.join(', ');
          }
        });
        String bodyText;
        List<int>? binary;
        try {
          bodyText = utf8.decode(bytes);
        } on FormatException {
          bodyText = '';
          binary = bytes;
        }
        final result = <String, Object?>{
          'status': response.statusCode,
          'url': current.toString(),
          'headers': responseHeaders,
          'body': bodyText,
        };
        if (binary != null) result['bytes'] = binary;
        return result;
      }
    } on TimeoutException {
      throw const SourceHttpException('timeout', 'HTTP 请求超时');
    } on IOException catch (failure) {
      throw SourceHttpException('network', 'HTTP 请求失败', '$failure');
    } finally {
      client.close(force: true);
    }
  }

  void _requireAllowed(SourcePermissions permissions, Uri url) {
    if (!permissions.allows(url)) {
      throw SourceHttpException(
        'permission_denied',
        '来源没有访问 ${url.origin} 的权限',
      );
    }
  }

  void _checkCancelled(bool Function()? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const SourceHttpException('cancelled', '请求已取消');
    }
  }

  String _method(Object? value, Map<String, Object?> request) {
    final method = value is String ? value.toUpperCase() : null;
    final resolved =
        method ??
        (request.containsKey('body') ||
                request.containsKey('form') ||
                request.containsKey('json')
            ? 'POST'
            : 'GET');
    if (!_methods.contains(resolved)) {
      throw SourceHttpException('invalid_request', '不支持的 HTTP 方法：$resolved');
    }
    return resolved;
  }

  Map<String, String> _requestHeaders(Object? value) {
    if (value == null) return {};
    if (value is! Map) {
      throw const SourceHttpException('invalid_request', 'HTTP headers 必须是对象');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final name = '${entry.key}';
      final lower = name.toLowerCase();
      if (!_headerName.hasMatch(name) ||
          _forbiddenRequestHeaders.contains(lower)) {
        throw SourceHttpException('permission_denied', '不能设置 HTTP 请求头 $name');
      }
      final headerValue = '${entry.value}';
      if (headerValue.contains('\r') || headerValue.contains('\n')) {
        throw SourceHttpException('invalid_request', 'HTTP 请求头包含换行');
      }
      result[name] = headerValue;
    }
    return result;
  }

  Uint8List? _requestBody(
    Map<String, Object?> request,
    Map<String, String> headers,
  ) {
    final present = [
      if (request['body'] != null) 'body',
      if (request['form'] != null) 'form',
      if (request.containsKey('json')) 'json',
    ];
    if (present.length > 1) {
      throw const SourceHttpException(
        'invalid_request',
        'HTTP 正文只能使用 body、form 或 json 之一',
      );
    }
    if (present.isEmpty) return null;
    if (request['form'] case final Map form) {
      if (headers.keys.any(
        (name) => name.toLowerCase() == HttpHeaders.contentTypeHeader,
      )) {
        // Keep an explicitly provided content type.
      } else {
        headers[HttpHeaders.contentTypeHeader] =
            'application/x-www-form-urlencoded';
      }
      return Uint8List.fromList(
        utf8.encode(
          Uri(
            queryParameters: {
              for (final entry in form.entries)
                '${entry.key}': _queryValue(entry.value),
            },
          ).query,
        ),
      );
    }
    if (request.containsKey('json')) {
      headers.putIfAbsent(
        HttpHeaders.contentTypeHeader,
        () => 'application/json',
      );
      return Uint8List.fromList(utf8.encode(jsonEncode(request['json'])));
    }
    final body = request['body'];
    if (body is String) {
      return Uint8List.fromList(utf8.encode(body));
    }
    if (body is List) {
      return Uint8List.fromList([
        for (final value in body)
          if (value is int && value >= 0 && value <= 255)
            value
          else
            throw const SourceHttpException(
              'invalid_request',
              'HTTP 字节正文必须使用 0–255 的整数',
            ),
      ]);
    }
    throw const SourceHttpException(
      'invalid_request',
      'HTTP 正文必须是文本、字节数组或 form/json 对象',
    );
  }

  Future<Uint8List> _readBytes(
    HttpClientResponse response,
    bool Function()? isCancelled,
  ) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.timeout(timeout)) {
      _checkCancelled(isCancelled);
      length += chunk.length;
      if (length > maxResponseBytes) {
        throw SourceHttpException(
          'invalid_response',
          'HTTP 响应超过 ${maxResponseBytes ~/ (1024 * 1024)} MiB',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  int _redirectLimit(Object? value) {
    if (value == null) return 5;
    if (value is! int || value < 0 || value > 10) {
      throw const SourceHttpException(
        'invalid_request',
        'HTTP maxRedirects 必须在 0–10 之间',
      );
    }
    return value;
  }

  static const _methods = {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'};
  static final _headerName = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");
  static const _forbiddenRequestHeaders = {
    'authorization',
    'connection',
    'content-length',
    'cookie',
    'host',
    'proxy-authorization',
    'set-cookie',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'proxy-authenticate',
    'proxy-authorization',
    'set-cookie',
  };
}

String _queryValue(Object? value) => value is List
    ? value.join(',')
    : value == null
    ? ''
    : '$value';
