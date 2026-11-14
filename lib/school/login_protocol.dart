part of 'login.dart';

extension _SchoolLoginProtocol on SchoolLogin {
  Future<String> _device() async {
    final cookies = await session.storage.cookiesFor(
      session.network,
      SchoolLogin._sso,
    );
    var device = cookies
        .where((cookie) => cookie.name == 'device')
        .firstOrNull
        ?.value;
    if (device == null) {
      device = schoolSha256(base64Encode(schoolRandomBytes(32)));
      await session.storage.saveCookies(session.network, SchoolLogin._sso, [
        Cookie('device', device)
          ..path = '/'
          ..secure = true,
      ]);
    }
    return device;
  }

  Future<Map<String, dynamic>> _riskPayload() async {
    final device = await _device();
    final cookies = await session.storage.cookiesFor(
      session.network,
      SchoolLogin._sso,
    );
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
        SchoolLogin._sso.resolve('/ustc-rba-front/fp'),
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
      (await _request(SchoolLogin._sso.resolve(path), jsonBody: body)).json;

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
        'Origin': SchoolLogin._sso.origin,
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
