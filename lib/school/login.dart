import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart';

import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import '../core/json.dart';
import 'crypto.dart';
import 'errors.dart';
import 'network.dart';
import 'session.dart';
import 'storage.dart';
import 'verification.dart';

/// The school's CAS protocol, also implemented by BIT101-dev/BIT-Login.
class SchoolLogin {
  SchoolLogin(this.session, this.verify);

  final SchoolSession session;
  final VerifySchoolLogin? verify;
  static final _sso = Uri.https('sso.bit.edu.cn');
  Uri _referer = _sso.resolve('/cas/login');

  VerifySchoolLogin _verification(SchoolVerificationKind kind) =>
      verify ?? (throw SchoolVerificationRequired(kind));

  Future<SchoolCredentials> _credentials(SchoolCredentials? provided) async {
    final account = provided ?? await session.storage.readCredentials();
    if (account == null) throw const SchoolCredentialsRequired();
    return account;
  }

  Future<SchoolResponse> openService(
    Uri entry, {
    SchoolCredentials? credentials,
  }) async {
    final response = await session.request(entry);
    if (!isSchoolLogin(response.url)) return response;
    final account = await _credentials(credentials);
    final callback = await _authenticate(account, entry, loginPage: response);
    return _openCallback(callback);
  }

  Future<void> signIn([SchoolCredentials? credentials]) async {
    final account = await _credentials(credentials);
    await _prepareNetwork(account);

    // The entry supplies the CAS service; the proxy needs its gateway cookie.
    final preflight = await session.request(
      session.network.route(SchoolNetwork.teachingLogin),
      followRedirects: false,
      anonymous: session.network == SchoolNetwork.campus,
    );
    final location = preflight.location;
    if (location == null) {
      throw const SchoolRequestError('学校登录入口未返回认证地址。');
    }
    final service = location.queryParameters['service'];
    if (service == null || service.isEmpty) {
      throw const SchoolRequestError('学校登录入口未返回有效服务地址。');
    }
    final callback = await _authenticate(account, Uri.parse(service));
    await _openCallback(callback);
    try {
      await session.checkLogin();
    } on SessionExpired {
      throw SchoolConnectionError(
        session.network.accountPage,
        const SchoolRequestError('未能建立学校登录会话，请重试。'),
      );
    }
  }

  Future<void> signInTo(Uri service) async {
    final account = await _credentials(null);
    await _prepareNetwork(account);
    final callback = await _authenticate(account, service);
    await session.request(
      session.network.route(service),
      followRedirects: false,
    );
    await _openCallback(callback);
  }

  Future<void> _prepareNetwork(SchoolCredentials account) async {
    if (session.network == SchoolNetwork.webvpn) {
      await _prepareWebVpn();
      final vpnCallback = await _authenticate(account, SchoolNetwork.vpnLogin);
      await _openCallback(vpnCallback);
    }
  }

  Future<void> _prepareWebVpn() async {
    final response = await session.request(SchoolNetwork.vpnLogin);
    if (response.url.path != '/fingerprint') return;

    // The gateway binds its session cookie to a stable client identifier.
    final fingerprint = schoolSha256(await _device()).substring(0, 32);
    await session.request(
      response.url
          .resolve('/set-fingerprint')
          .replace(
            queryParameters: {
              ...response.url.queryParameters,
              'fingerprint': fingerprint,
            },
          ),
      headers: {'Referer': response.url.toString()},
    );
  }

  Future<SchoolResponse> _openCallback(Uri callback) => session.request(
    session.network.route(callback),
    headers: {'Referer': _referer.toString()},
  );

  Future<Uri> _authenticate(
    SchoolCredentials credentials,
    Uri service, {
    SchoolResponse? loginPage,
  }) async {
    final pageResponse = await _followLoginRedirects(
      loginPage ??
          await _request(
            _sso
                .resolve('/cas/login')
                .replace(queryParameters: {'service': service.toString()}),
            followRedirects: false,
          ),
    );
    if (pageResponse.location != null) return _callback(pageResponse);
    final page = _LoginPage(pageResponse);
    _referer = pageResponse.url;
    if (page.requiresSms) return _secondFactor(credentials.username, page);

    final captchaInfo = await _json(
      '/cas/api/protected/user/findCaptchaCount/${Uri.encodeComponent(credentials.username)}',
    );
    var captcha = jsonObjectField(captchaInfo, 'data');
    Future<Uint8List> loadCaptcha() async {
      final result = await _json(
        '/cas/api/protected/user/findCaptchaCount/${Uri.encodeComponent(credentials.username)}',
      );
      captcha = jsonObjectField(result, 'data');
      return _captchaImage(captcha);
    }

    final captchaRequired = captcha['captchaInvisible'] == true;
    var captchaCode = '';
    if (captchaRequired) {
      final verify = _verification(SchoolVerificationKind.image);
      final code = await verify(
        SchoolImageVerification(
          image: await _captchaImage(captcha),
          reload: loadCaptcha,
        ),
      );
      if (code == null) throw const RequestCancelled();
      captchaCode = code;
    }
    session.checkActive();

    final key = base64Decode(page.cryptoKey);
    final form = {
      'type': 'UsernamePassword',
      '_eventId': 'submit',
      'geolocation': '',
      'execution': page.execution,
      'username': credentials.username,
      'croypto': page.cryptoKey,
      'password': encryptSchoolValue(credentials.password, key),
      'captcha_code': captchaCode,
      'captcha_payload': encryptSchoolValue(
        jsonEncode(captcha['captchaPayload'] ?? {}),
        key,
      ),
    };
    if (page.field('riskSystemSwitch').toUpperCase() == 'USTC') {
      form.addAll({
        'risk_payload': encryptSchoolValue(
          jsonEncode(await _riskPayload()),
          key,
        ),
        'targetSystem': page.field('targetSystem').isEmpty
            ? 'sso'
            : page.field('targetSystem'),
        'siteId': page.field('siteId').isEmpty
            ? 'sourceId'
            : page.field('siteId'),
        'riskEngine': 'true',
      });
    }
    final response = await _followLoginRedirects(
      await _request(
        page.action,
        form: form,
        followRedirects: false,
        checkStatus: false,
      ),
    );
    final secondFactor = _LoginPage(response);
    if (secondFactor.requiresSms) {
      return _secondFactor(credentials.username, secondFactor);
    }
    return _callback(response);
  }

  Future<SchoolResponse> _followLoginRedirects(SchoolResponse response) async {
    for (var redirects = 0; redirects <= 10; redirects++) {
      final next = response.location;
      if (response.status < 300 ||
          response.status >= 400 ||
          next == null ||
          !isSchoolLogin(next)) {
        return response;
      }
      _referer = response.url;
      response = await _request(next, followRedirects: false);
    }
    throw const SchoolRequestError('学校登录反复跳转，请稍后重试。');
  }

  Future<Uri> _secondFactor(String username, _LoginPage page) async {
    final verify = _verification(SchoolVerificationKind.sms);
    _referer = _sso.resolve('/cas/');
    final key = schoolRandomBytes(16);
    final encrypted = await _request(
      _sso.resolve('/cas/api/protected/sms/getPhoneNumberByUserId'),
      body: encryptSchoolValue(
        jsonEncode({'userId': page.field('user-object-id')}),
        key,
      ),
      headers: {'hasCrypto': 'true', 'privateKey': encryptSchoolKey(key)},
    );
    final data = jsonObjectField(
      jsonObject(jsonDecode(decryptSchoolValue(encrypted.text, key)), '短信验证响应'),
      'data',
    );
    final phoneId = jsonStringField(data, 'tel');
    final maskedPhone = jsonStringField(data, 'maskTel');
    final code = await verify(
      SchoolSmsVerification(
        phone: maskedPhone,
        sendCode: () async {
          final response = await _request(
            _sso.resolve('/cas/api/protected/sms/publicNoToken/sendSmsCode'),
            jsonBody: {'phone': phoneId, 'businessNo': '0008'},
            checkStatus: false,
          );
          return SchoolSmsCodeDelivery.fromResponse(response).resendAfter;
        },
        checkCode: (code) async {
          final result = await _json(
            '/cas/api/protected/sms/checkToken',
            body: {
              'phone': phoneId,
              'token': code,
              'delete': false,
              'trustDevice': true,
            },
          );
          if (result['code'] != 200) {
            throw SchoolRequestError(
              _message(result).isEmpty ? '验证码错误或已失效。' : _message(result),
            );
          }
        },
      ),
    );
    if (code == null) throw const RequestCancelled();
    session.checkActive();
    return _callback(
      await _request(
        page.action,
        form: {
          'username': username,
          'password': code,
          'type': 'smsLogin',
          '_eventId': 'submit',
          'geolocation': '',
          'execution': page.execution,
          'captcha_code': '',
          'trustDevice': 'true',
        },
        followRedirects: false,
        checkStatus: false,
      ),
    );
  }

  Uri _callback(SchoolResponse response) {
    final location = response.location;
    if (location != null && response.status >= 300 && response.status < 400) {
      return location;
    }
    final page = _LoginPage(response);
    final code = page.field('login-error-code');
    final message = switch (code) {
      '1030027' || '1030031' => '账号或密码错误',
      '1030028' => '账号已被锁定，请先在学校统一身份认证平台解锁。',
      '1320007' || '1320010' => '验证码错误或已失效，请重试。',
      '1330001' => '学校要求进一步验证，请稍后重试。',
      '1410040' || '1410041' => '学校账号状态异常，请联系学校处理。',
      '3910001' => '账号已休眠，请先在学校统一身份认证平台激活。',
      _ => page.field('login-error-msg'),
    };
    if (code == '1030027' || code == '1030031') {
      throw SchoolCredentialsRequired(message);
    }
    if (response.status == 429) throw const SchoolRequestError('登录过于频繁，请稍后重试。');
    if (response.status >= 500) {
      throw SchoolConnectionError(
        response.url,
        SchoolRequestError(
          '认证请求失败（${response.status}）：'
          '${response.url.host}${response.url.path}',
        ),
      );
    }
    if (message.isEmpty) {
      AppDiagnostics.instance.info(
        '统一身份认证未返回跳转：HTTP ${response.status}，'
        '${response.url.origin}${response.url.path}，错误码 ${code.isEmpty ? '未提供' : code}',
      );
    }
    throw SchoolRequestError(message.isEmpty ? '学校未完成登录，请重试。' : message);
  }

  Future<Uint8List> _captchaImage(Map<String, dynamic> captcha) async {
    final url = jsonStringField(captcha, 'captchaUrl');
    if (url.startsWith('data:')) return UriData.parse(url).contentAsBytes();
    return (await _request(_sso.resolve('/cas/').resolve(url))).bytes;
  }

  Future<String> _device() async {
    final cookies = await session.storage.cookiesFor(session.network, _sso);
    var device = cookies
        .where((cookie) => cookie.name == 'device')
        .firstOrNull
        ?.value;
    if (device == null) {
      device = schoolSha256(base64Encode(schoolRandomBytes(32)));
      await session.storage.saveCookies(session.network, _sso, [
        Cookie('device', device)
          ..path = '/'
          ..secure = true,
      ]);
    }
    return device;
  }

  Future<Map<String, dynamic>> _riskPayload() async {
    final device = await _device();
    final cookies = await session.storage.cookiesFor(session.network, _sso);
    final group =
        cookies
            .where((cookie) => cookie.name == 'riskSystemGroupId')
            .firstOrNull
            ?.value ??
        '';
    final values = {
      'fonts': jsonEncode([
        'Arial',
        'Helvetica Neue',
        'PingFang SC',
        'Times New Roman',
      ]),
      'deviceMemory': '16',
      'hardwareConcurrency': '10',
      'timezone': jsonEncode('Asia/Shanghai'),
      'cpuClass': jsonEncode('not available'),
      'platform': jsonEncode('MacIntel'),
      'language': jsonEncode('zh-CN'),
      'screenResolution': '[956,1470]',
    };
    try {
      final response = await _request(
        _sso.resolve('/ustc-rba-front/fp'),
        jsonBody: {
          for (final entry in values.entries)
            entry.key:
                [
                  'fonts',
                  'deviceMemory',
                  'hardwareConcurrency',
                  'cpuClass',
                ].contains(entry.key)
                ? schoolSha256(entry.value)
                : entry.value,
          'localgroupId': group,
          'fingerprint': schoolSha256(values.values.join()),
          'cookieValue': device,
          'userAgent': SchoolSession.userAgent,
          'platformAuthenticator': 'support',
        },
      );
      final result = jsonDecode(response.text);
      if (result case {'responsetoken': final String token}
          when token.isNotEmpty) {
        return {'token': token, 'groupId': group};
      }
      throw const FormatException('学校风控接口未返回有效 token');
    } on Exception catch (failure) {
      session.checkActive();
      if (failure is! SchoolRequestError &&
          failure is! SchoolConnectionError &&
          failure is! FormatException) {
        rethrow;
      }
      // The school's login page submits this exact payload when fingerprint
      // collection fails; CAS still decides whether authentication or SMS passes.
      final detail = failure is FormatException ? failure.message : '$failure';
      AppDiagnostics.instance.info('学校风控采集失败，将在登录时提交采集失败状态，由学校继续验证：$detail');
      return {'error': true};
    }
  }

  Future<Map<String, dynamic>> _json(String path, {Object? body}) async =>
      (await _request(_sso.resolve(path), jsonBody: body)).json;

  Future<SchoolResponse> _request(
    Uri url, {
    Map<String, String>? form,
    Object? jsonBody,
    String? body,
    Map<String, String> headers = const {},
    bool followRedirects = true,
    bool checkStatus = true,
  }) => session.request(
    url,
    form: form,
    jsonBody: jsonBody,
    body: body,
    followRedirects: followRedirects,
    checkStatus: checkStatus,
    headers: {
      'Referer': _referer.toString(),
      if (form != null || jsonBody != null || body != null)
        'Origin': _sso.origin,
      if (url.path.contains('/protected/')) ...{
        ...schoolCsrfHeaders(),
        'Sid-Language': 'zh_CN',
      },
      ...headers,
    },
  );

  String _message(Map<String, dynamic> result) =>
      (result['message'] ?? result['msg'] ?? result['errorMessage'] ?? '')
          .toString();
}

class _LoginPage {
  _LoginPage(SchoolResponse response)
    : document = parse(response.text),
      url = response.url;

  final Document document;
  final Uri url;

  bool get requiresSms =>
      field('user-object-id').isNotEmpty &&
      document.querySelector(
            '#secondSmsLoginForm, #second-auth-tip, .cas-gateway, #cas-gateway',
          ) !=
          null;

  String field(String id) {
    final element = document.getElementById(id);
    return (element?.attributes['value'] ?? element?.text ?? '').trim();
  }

  String get execution => _element('login-page-flowkey').text.trim();
  String get cryptoKey => _element('login-croypto').text.trim();
  Uri get action {
    final form = document.querySelector('form');
    if (form == null) {
      throw const FormatException('学校登录页面缺少登录表单');
    }
    final target = form.attributes['action'];
    final action = target == null || target.trim().isEmpty
        ? url
        : url.resolve(target);
    if (action.origin != 'https://sso.bit.edu.cn') {
      throw const SchoolRequestError('学校登录表单的地址异常。');
    }
    return action;
  }

  Element _element(String id) =>
      document.getElementById(id) ?? (throw FormatException('学校登录页面缺少 $id'));
}
