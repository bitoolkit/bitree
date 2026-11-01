import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/async/cancelable_request.dart';
import '../core/json.dart';
import 'errors.dart';
import 'network.dart';
import 'storage.dart';

class SchoolResponse {
  const SchoolResponse({
    required this.url,
    required this.status,
    required this.location,
    required this.bytes,
  });

  final Uri url;
  final int status;
  final Uri? location;
  final Uint8List bytes;

  String get text => utf8.decode(bytes);

  Map<String, dynamic> get json => jsonObject(jsonDecode(text), '学校接口响应');
}

class SchoolSession {
  SchoolSession({required this.network, required this.storage});

  final SchoolNetwork network;
  final SchoolStorage storage;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final _requestSlots = _RequestLimiter(4);
  bool _closed = false;

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';

  void checkActive() {
    if (_closed) throw const RequestCancelled();
  }

  Future<void> checkLogin() async {
    await request(network.accountPage, stopAtLogin: true);
    await request(network.accountConfig, stopAtLogin: true);
  }

  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, String>? form,
    String app = 'wdkbby',
  }) async {
    final response = await request(
      network.endpoint(path, app: app),
      form: form,
      headers: {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
      stopAtLogin: true,
    );
    if (response.text.trimLeft().startsWith('<')) {
      if (response.text.contains('login-page-flowkey') ||
          response.text.contains('authserver/login')) {
        throw const SessionExpired();
      }
      throw SchoolRequestError(
        schoolPageError(response.text) ?? '学校接口暂时未返回数据，请稍后重试。',
      );
    }
    return response.json;
  }

  Future<SchoolResponse> request(
    Uri target, {
    Map<String, String>? form,
    Object? jsonBody,
    String? body,
    Map<String, String> headers = const {},
    bool followRedirects = true,
    bool stopAtLogin = false,
    bool checkStatus = true,
    bool anonymous = false,
  }) {
    checkActive();
    return _requestSlots.run(
      () => _request(
        target,
        form: form,
        jsonBody: jsonBody,
        body: body,
        headers: headers,
        followRedirects: followRedirects,
        stopAtLogin: stopAtLogin,
        checkStatus: checkStatus,
        anonymous: anonymous,
      ),
    );
  }

  Future<SchoolResponse> _request(
    Uri target, {
    required Map<String, String>? form,
    required Object? jsonBody,
    required String? body,
    required Map<String, String> headers,
    required bool followRedirects,
    required bool stopAtLogin,
    required bool checkStatus,
    required bool anonymous,
  }) async {
    var url = target;
    var payload = form != null
        ? Uri(queryParameters: form).query
        : jsonBody != null
        ? jsonEncode(jsonBody)
        : body;
    final contentType = form != null
        ? 'application/x-www-form-urlencoded; charset=utf-8'
        : 'application/json; charset=utf-8';

    checkActive();
    for (var redirects = 0; redirects <= 10; redirects++) {
      if (!isSchoolUrl(url)) {
        throw const SchoolRequestError('学校请求跳转到了未授权的网站。');
      }
      if (stopAtLogin && isSchoolLogin(url)) throw const SessionExpired();

      try {
        final outgoing = await _client
            .openUrl(payload == null ? 'GET' : 'POST', url)
            .timeout(const Duration(seconds: 25));
        outgoing.followRedirects = false;
        outgoing.headers
          ..set(HttpHeaders.userAgentHeader, userAgent)
          ..set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9,en;q=0.7')
          ..set(HttpHeaders.acceptHeader, '*/*')
          ..set(
            'sec-ch-ua',
            '"Not;A=Brand";v="8", "Chromium";v="150", "Google Chrome";v="150"',
          )
          ..set('sec-ch-ua-mobile', '?0')
          ..set('sec-ch-ua-platform', '"macOS"');
        for (final entry in headers.entries) {
          if (redirects == 0 || entry.key.toLowerCase() == 'referer') {
            var value = entry.value;
            if (entry.key.toLowerCase() == 'referer') {
              final referer = Uri.parse(value);
              if (url.origin != referer.origin) value = '${referer.origin}/';
            }
            outgoing.headers.set(entry.key, value);
          }
        }
        if (!anonymous) {
          outgoing.cookies.addAll(await storage.cookiesFor(network, url));
        }
        checkActive();
        if (payload != null) {
          outgoing.headers.set(HttpHeaders.contentTypeHeader, contentType);
          outgoing.write(payload);
        }
        final response = await outgoing.close().timeout(
          const Duration(seconds: 25),
        );
        checkActive();
        if (!anonymous) {
          await storage.saveCookies(network, url, response.cookies);
        }
        final bytes = await response
            .fold<BytesBuilder>(
              BytesBuilder(copy: false),
              (buffer, chunk) => buffer..add(chunk),
            )
            .timeout(const Duration(seconds: 25));
        checkActive();
        final location = response.headers.value(HttpHeaders.locationHeader);
        final result = SchoolResponse(
          url: url,
          status: response.statusCode,
          location: location == null ? null : url.resolve(location),
          bytes: bytes.takeBytes(),
        );

        if (followRedirects &&
            [301, 302, 303, 307, 308].contains(result.status)) {
          final location = result.location;
          if (location == null) {
            throw SchoolRequestError('学校请求返回了重定向，但没有提供目标地址。');
          }
          final next = network.route(location);
          if ([301, 302, 303].contains(result.status)) {
            payload = null;
          }
          url = next;
          continue;
        }
        if (checkStatus && result.status >= 400) {
          if (stopAtLogin && result.status == 401) throw const SessionExpired();
          final message = switch (result.status) {
            403 => '请求被拒绝（403）：${url.host}${url.path}',
            429 => '请求过于频繁，请稍后重试。',
            _ => '请求失败（${result.status}）：${url.host}${url.path}',
          };
          final failure = SchoolRequestError(message);
          if (result.status == 403 || result.status >= 500) {
            throw SchoolConnectionError(url, failure);
          }
          throw failure;
        }
        return result;
      } on Exception catch (failure) {
        if (failure is SocketException ||
            failure is TimeoutException ||
            failure is HandshakeException ||
            failure is HttpException) {
          throw SchoolConnectionError(url, failure);
        }
        rethrow;
      }
    }
    throw const SchoolRequestError('学校登录反复跳转，请稍后重试。');
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}

/// Caps shared transport pressure without throwing away queued read work.
class _RequestLimiter {
  _RequestLimiter(this.limit) : assert(limit > 0);

  final int limit;
  final _waiters = Queue<Completer<void>>();
  var _active = 0;

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active < limit) {
      _active++;
    } else {
      final ready = Completer<void>();
      _waiters.add(ready);
      await ready.future;
    }

    try {
      return await operation();
    } finally {
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}
