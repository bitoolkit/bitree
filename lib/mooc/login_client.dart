import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;

import 'cookie.dart';
import 'credentials.dart';
import 'login_crypto.dart';
import 'tasks.dart';

// The CAPTCHA SDK uses Mobile to select touch-only event handlers.
// Keep desktop sessions on its mouse-capable path, including the WebView.
String get moocNativeUserAgent => Platform.isAndroid || Platform.isIOS
    ? 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36'
    : 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

const _loginOrigin = 'https://reg.icourse163.org';
const _loginFrame =
    '$_loginOrigin/webzj/v1.0.1/pub/index_dl2_new.html'
    '?pkid=cjJVGQM&product=imooc';
const _loginTop = 'https://www.icourse163.org/member/login.htm#/webLoginIndex';
const _product = 'imooc';
const _productMark = 'cjJVGQM';
const _captchaId = 'a3b396bb2f589bbc1151f0fa61d14747';
const _commandTimeout = Duration(seconds: 25);

enum MoocLoginError {
  wrongCredentials,
  invalidPhone,
  rateLimited,
  smsRequired,
  invalidCode,
  unavailable,
  network,
  malformedResponse,
  noSession,
}

class MoocLoginException implements Exception {
  const MoocLoginException(this.kind, {this.code});

  final MoocLoginError kind;
  final String? code;

  @override
  String toString() => 'MOOC login failed: ${kind.name}';
}

class MoocCaptchaSolution {
  const MoocCaptchaSolution({required this.validate});

  final String validate;
}

class MoocLoginChallenge extends MoocLoginException {
  const MoocLoginChallenge(String code)
    : super(MoocLoginError.unavailable, code: code);

  int? get captchaType => switch (code) {
    '109' || '444' => 2,
    '110' || '445' => 3,
    '111' || '447' => 4,
    _ => null,
  };
}

/// Uses MOOC's own web sign-in protocol without loading its login UI.
///
/// One instance owns the cookies for an editor session. Repeated password
/// attempts share that session; successful responses are followed with the
/// same cookie jar before the account is read.
class MoocLoginClient {
  MoocLoginClient({HttpClient? http, String? userAgent})
    : _http = http ?? HttpClient(),
      _ownsHttp = http == null,
      userAgent = userAgent ?? moocNativeUserAgent {
    _http.connectionTimeout = _commandTimeout;
  }

  final HttpClient _http;
  final bool _ownsHttp;
  final String userAgent;
  final _cookies = CookieJar();
  final _random = Random.secure();
  bool _initialized = false;

  Future<MoocAccount> loginWithPassword({
    required String account,
    required String password,
    MoocCaptchaSolution? captcha,
  }) async {
    await _initialize();
    final proof = await _readProof(account: account, channel: 1);
    final result = await _login(
      account: account,
      channel: 1,
      proof: proof,
      payload: (ticket, proofParam) => {
        ..._common(),
        'l': 1,
        'd': 10,
        'un': account,
        'pw': encryptMoocPassword(password),
        'tk': ticket,
        'domains': '',
        'channel': 1,
        'pVParam': ?proofParam,
        ..._captchaFields(captcha),
      },
      path: '/dl/zj/yd/pwd/l',
    );
    return _finish(result);
  }

  Future<Duration> sendSmsCode(
    String phone, {
    MoocCaptchaSolution? captcha,
  }) async {
    await _initialize();
    final proof = await _readProof(account: phone, channel: 2);
    var response = await _post('/dl/zj/yd/sms/sm', {
      ..._common(),
      'un': phone,
      'channel': 2,
      'pVParam': ?proof.parameter,
      ..._captchaFields(captcha),
    });
    if (_isProofRequired(response)) {
      final retryProof = await _readProof(
        account: phone,
        channel: 2,
        pvSid: proof.sid,
      );
      response = await _post('/dl/zj/yd/sms/sm', {
        ..._common(),
        'un': phone,
        'channel': 2,
        'pVParam': ?retryProof.parameter,
        ..._captchaFields(captcha),
      });
    }
    _requireSuccess(response);
    final configuredSeconds =
        response['cd'] ??
        response['interval'] ??
        response['smsTime'] ??
        response['next'];
    final parsedSeconds = switch (configuredSeconds) {
      final num value => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };
    final seconds =
        parsedSeconds != null && parsedSeconds >= 1 && parsedSeconds <= 300
        ? parsedSeconds
        : 60;
    return Duration(seconds: seconds);
  }

  Future<MoocAccount> loginWithSmsCode({
    required String phone,
    required String code,
    MoocCaptchaSolution? captcha,
  }) async {
    await _initialize();
    final proof = await _readProof(account: phone, channel: 2);
    final result = await _login(
      account: phone,
      channel: 2,
      proof: proof,
      payload: (ticket, proofParam) => {
        ..._common(),
        'un': phone,
        'sms': code,
        'tk': ticket,
        'domains': '',
        'channel': 2,
        'pVParam': ?proofParam,
        ..._captchaFields(captcha),
      },
      path: '/dl/zj/yd/sms/vfsms',
    );
    return _finish(result);
  }

  Future<MoocAccount> verifyCookies(Iterable<Cookie> cookies) async {
    final values = cookies.where((cookie) => cookie.value.isNotEmpty).toList();
    if (!MoocCredentials.hasSession(values)) {
      throw const MoocLoginException(MoocLoginError.noSession);
    }
    await _cookies.deleteAll();
    await _cookies.saveFromResponse(MoocCredentials.origin, values);
    final page = await _get(MoocCredentials.origin.resolve('/home.htm'));
    final account = _readAccount(page.body);
    return await _account(account);
  }

  Future<List<Cookie>> exportCookies() async {
    final values = <String, Cookie>{};
    for (final uri in [
      MoocCredentials.origin,
      Uri.parse(_loginOrigin),
      MoocCredentials.rpcDirectory,
    ]) {
      for (final cookie in await _cookies.loadForRequest(uri)) {
        values['${cookie.domain}\n${cookie.path}\n${cookie.name}'] = cookie;
      }
    }
    return values.values.toList(growable: false);
  }

  Future<({Map<String, Object>? parameter, String? sid})> _readProof({
    required String account,
    required int channel,
    String? pvSid,
  }) async {
    final response = await _post('/dl/zj/yd/powGetP', {
      ..._common(),
      'pkht': MoocCredentials.origin.host,
      'un': account,
      'channel': channel,
      if (pvSid != null && pvSid.isNotEmpty) 'pvSid': pvSid,
    });
    _requireSuccess(response);
    final info = moocMap(response['pVInfo']);
    if (info == null || info['needCheck'] != true) {
      return (parameter: null, sid: null);
    }
    final sid = info['sid'];
    if (sid is! String || sid.isEmpty) {
      throw const MoocLoginException(MoocLoginError.malformedResponse);
    }
    try {
      return (parameter: await solveMoocProof(info), sid: sid);
    } on FormatException {
      throw const MoocLoginException(MoocLoginError.unavailable);
    } on ArgumentError {
      throw const MoocLoginException(MoocLoginError.unavailable);
    }
  }

  Future<Map<String, dynamic>> _login({
    required String account,
    required int channel,
    required ({Map<String, Object>? parameter, String? sid}) proof,
    required Map<String, Object?> Function(
      String ticket,
      Map<String, Object>? proof,
    )
    payload,
    required String path,
  }) async {
    var activeProof = proof;
    for (var attempt = 0; attempt < 2; attempt++) {
      final ticketResponse = await _post('/dl/zj/yd/gt', {
        ..._common(),
        'un': account,
        'channel': channel,
      });
      _requireSuccess(ticketResponse);
      final ticket = ticketResponse['tk'];
      if (ticket is! String || ticket.isEmpty) {
        throw const MoocLoginException(MoocLoginError.malformedResponse);
      }
      final response = await _post(
        path,
        payload(ticket, activeProof.parameter),
      );
      if (!_isProofRequired(response)) return response;
      if (attempt == 1) {
        throw MoocLoginException(
          MoocLoginError.unavailable,
          code: '${response['ret']}',
        );
      }
      activeProof = await _readProof(
        account: account,
        channel: channel,
        pvSid: activeProof.sid,
      );
      if (activeProof.parameter == null) {
        throw const MoocLoginException(MoocLoginError.unavailable);
      }
    }
    throw const MoocLoginException(MoocLoginError.unavailable);
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await _get(MoocCredentials.origin.resolve('/member/login.htm'));
    await _get(Uri.parse(_loginFrame));
    final seedCookies = [
      MoocCookie('utid', _randomId(32))
        ..domain = '.icourse163.org'
        ..path = '/'
        ..secure = true,
      MoocCookie('__snaker__id', _randomId(16))
        ..domain = '.icourse163.org'
        ..path = '/'
        ..secure = true,
      MoocCookie(
          'NTES_WEB_FP',
          List<int>.generate(
            16,
            (_) => _random.nextInt(256),
          ).map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
        )
        ..domain = '.icourse163.org'
        ..path = '/'
        ..secure = true,
    ];
    await _cookies.saveFromResponse(MoocCredentials.origin, seedCookies);
    for (final (path, channel) in [
      ('/dl/zj/mail/ini', 0),
      ('/zc/zj/yd/ini', 3),
      ('/dl/zj/yd/ini', 1),
    ]) {
      final response = await _post(path, {
        ..._common(),
        'pkht': MoocCredentials.origin.host,
        'channel': channel,
      });
      _requireSuccess(response);
    }
    _initialized = true;
  }

  Map<String, Object> _common() => {
    'pd': _product,
    'pkid': _productMark,
    'topURL': _loginTop,
    'rtid': _randomId(32),
  };

  Map<String, Object> _captchaFields(MoocCaptchaSolution? captcha) {
    if (captcha == null) return const {};
    if (captcha.validate.isEmpty) {
      throw ArgumentError.value(
        captcha.validate,
        'captcha.validate',
        'CAPTCHA validation must not be empty',
      );
    }
    return {'cap': captcha.validate, 'capkey': _captchaId};
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> payload,
  ) async {
    try {
      final url = Uri.parse('$_loginOrigin$path');
      final request = await _http.postUrl(url).timeout(_commandTimeout);
      request
        ..followRedirects = false
        ..headers.contentType = ContentType.json
        ..headers.set(HttpHeaders.acceptHeader, '*/*')
        ..headers.set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9')
        ..headers.set(HttpHeaders.userAgentHeader, userAgent)
        ..headers.set(HttpHeaders.refererHeader, _loginFrame)
        ..headers.set('Origin', _loginOrigin)
        ..cookies.addAll(await _cookies.loadForRequest(request.uri));
      request.write(jsonEncode({'encParams': encryptMoocParams(payload)}));
      final response = await request.close().timeout(_commandTimeout);
      await _saveResponseCookies(url, response);
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_commandTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MoocLoginException(
          MoocLoginError.unavailable,
          code: 'http-${response.statusCode}',
        );
      }
      final decoded = jsonDecode(text);
      final data = moocMap(decoded);
      if (data == null) {
        throw const MoocLoginException(MoocLoginError.malformedResponse);
      }
      return data;
    } on MoocLoginException {
      rethrow;
    } on FormatException {
      throw const MoocLoginException(MoocLoginError.malformedResponse);
    } on SocketException {
      throw const MoocLoginException(MoocLoginError.network);
    } on HttpException {
      throw const MoocLoginException(MoocLoginError.network);
    } on HandshakeException {
      throw const MoocLoginException(MoocLoginError.network);
    } on TimeoutException {
      throw const MoocLoginException(MoocLoginError.network);
    }
  }

  Future<({Uri url, String body})> _get(Uri url, {int redirects = 0}) async {
    if (redirects > 5) {
      throw const MoocLoginException(MoocLoginError.unavailable);
    }
    try {
      final request = await _http.getUrl(url).timeout(_commandTimeout);
      request
        ..followRedirects = false
        ..headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
        )
        ..headers.set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9')
        ..headers.set(HttpHeaders.userAgentHeader, userAgent)
        ..headers.set(HttpHeaders.refererHeader, 'https://www.icourse163.org/')
        ..cookies.addAll(await _cookies.loadForRequest(url));
      final response = await request.close().timeout(_commandTimeout);
      await _saveResponseCookies(url, response);
      if (_isRedirect(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) {
          throw const MoocLoginException(MoocLoginError.unavailable);
        }
        return await _get(url.resolve(location), redirects: redirects + 1);
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_commandTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MoocLoginException(
          MoocLoginError.unavailable,
          code: 'http-${response.statusCode}',
        );
      }
      return (url: url, body: body);
    } on MoocLoginException {
      rethrow;
    } on SocketException {
      throw const MoocLoginException(MoocLoginError.network);
    } on HttpException {
      throw const MoocLoginException(MoocLoginError.network);
    } on HandshakeException {
      throw const MoocLoginException(MoocLoginError.network);
    } on TimeoutException {
      throw const MoocLoginException(MoocLoginError.network);
    }
  }

  Future<MoocAccount> _finish(Map<String, dynamic> response) async {
    _requireSuccess(response);
    final nextUrls = response['nextUrls'];
    if (nextUrls != null && nextUrls is! List) {
      throw const MoocLoginException(MoocLoginError.malformedResponse);
    }
    for (final value in nextUrls as List? ?? const []) {
      if (value is! String || value.isEmpty) {
        throw const MoocLoginException(MoocLoginError.malformedResponse);
      }
      final uri = Uri.tryParse(value.startsWith('//') ? 'https:$value' : value);
      if (uri == null ||
          uri.scheme != 'https' ||
          !MoocCredentials.isMoocHost(uri.host)) {
        throw const MoocLoginException(MoocLoginError.malformedResponse);
      }
      await _get(uri);
    }
    final home = await _get(MoocCredentials.origin.resolve('/home.htm'));
    final values = _readAccount(home.body);
    return _account(values);
  }

  Future<MoocAccount> _account(({String id, String name}) values) async {
    final cookies = await _cookies.loadForRequest(MoocCredentials.rpcDirectory);
    if (!MoocCredentials.hasSession(cookies)) {
      throw const MoocLoginException(MoocLoginError.noSession);
    }
    return MoocAccount(
      id: values.id,
      name: values.name,
      credentials: MoocCredentials(userAgent: userAgent, cookies: cookies),
    );
  }

  ({String id, String name}) _readAccount(String source) {
    for (final script
        in html_parser
            .parse(source)
            .getElementsByTagName('script')
            .map((element) => element.text)) {
      final assignment = RegExp(r'\bwindow\.webUser\s*=\s*\{')
          .firstMatch(script);
      if (assignment == null) continue;
      final object = _balancedObject(script, assignment.end - 1);
      if (object == null) continue;
      // MOOC emits a data object with unquoted property names and JSON strings.
      // Quote only the property names; leave string contents untouched.
      final json = object.replaceAllMapped(
        RegExp(r'"(?:\\.|[^"\\])*"|([a-zA-Z_$][\w$]*)\s*:'),
        (match) => match[1] == null ? match[0]! : '"${match[1]}":',
      );
      try {
        final value = moocMap(jsonDecode(json));
        final id = moocId(value?['id']);
        final name = value?['nickName'] ?? value?['name'];
        if (id != null && name is String && name.trim().isNotEmpty) {
          return (id: id, name: name);
        }
      } on FormatException {
        continue;
      }
    }
    throw const MoocLoginException(MoocLoginError.noSession);
  }

  void _requireSuccess(Map<String, dynamic> data) {
    final code = '${data['ret'] ?? ''}';
    if (code == '201') return;
    final detail = '${data['dt'] ?? ''}';
    if (const {
      '108',
      '109',
      '110',
      '111',
      '441',
      '444',
      '445',
      '447',
    }.contains(code)) {
      throw MoocLoginChallenge(code);
    }
    final error = switch (code) {
      '413' || '420' => MoocLoginError.wrongCredentials,
      '401' when const {'02', '10', '20'}.contains(detail) =>
        MoocLoginError.wrongCredentials,
      '409' || '458' => MoocLoginError.rateLimited,
      '410' || '433' => MoocLoginError.unavailable,
      '415' || '609' => MoocLoginError.smsRequired,
      '442' || '443' => MoocLoginError.invalidCode,
      '401' when detail == '09' => MoocLoginError.invalidPhone,
      _ => MoocLoginError.unavailable,
    };
    throw MoocLoginException(error, code: code);
  }

  bool _isProofRequired(Map<String, dynamic> data) =>
      const {'805', '806'}.contains('${data['ret'] ?? ''}');

  Future<void> _saveResponseCookies(
    Uri url,
    HttpClientResponse response,
  ) async {
    final values =
        (response.headers[HttpHeaders.setCookieHeader] ?? const <String>[])
            .map(MoocCookie.fromSetCookieValue)
            .where((cookie) {
              final domain = cookie.domain?.toLowerCase().replaceFirst(
                RegExp(r'^\.'),
                '',
              );
              return domain == null ||
                  (MoocCredentials.isMoocHost(domain) &&
                      (url.host == domain || url.host.endsWith('.$domain')));
            })
            .toList();
    for (final cookie in values) {
      final seconds = cookie.maxAge;
      if (seconds != null && seconds > 0) {
        cookie.expires = DateTime.now().toUtc().add(Duration(seconds: seconds));
        cookie.maxAge = null;
      }
    }
    await _cookies.saveFromResponse(url, values);
  }

  String _randomId(int length) {
    const alphabet =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes(
      List<int>.generate(
        length,
        (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
      ),
    );
  }

  static bool _isRedirect(int code) =>
      const {301, 302, 303, 307, 308}.contains(code);

  void close() {
    if (_ownsHttp) _http.close(force: true);
  }
}

String? _balancedObject(String source, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = start; index < source.length; index++) {
    final code = source.codeUnitAt(index);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (code == 0x5c) {
        escaped = true;
      } else if (code == 0x22) {
        inString = false;
      }
      continue;
    }
    if (code == 0x22) {
      inString = true;
    } else if (code == 0x7b) {
      depth++;
    } else if (code == 0x7d) {
      depth--;
      if (depth == 0) return source.substring(start, index + 1);
    }
  }
  return null;
}
