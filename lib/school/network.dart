enum SchoolNetwork {
  campus,
  webvpn;

  String get label => this == campus ? '校内直连' : 'WebVPN';

  static final _campusApp = Uri.https('jxzxehallapp.bit.edu.cn');
  static const _vpnHosts = {
    'jxzxehallapp.bit.edu.cn': '77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d',
    'jxzxehall.bit.edu.cn': '77726476706e69737468656265737421faef5b842238695c72468ba58c1b26316e8e7f6f',
    'jwms.bit.edu.cn':
        '77726476706e69737468656265737421fae04c8f69326144300d8db9d6562d',
  };

  Uri get app =>
      route(_campusApp.resolve('/jwapp/sys/wdkbby/*default/index.do'));

  Uri get accountPage =>
      route(_campusApp.resolve('/jwapp/sys/xsfacx/*default/index.do'));

  Uri get examApp =>
      route(_campusApp.resolve('/jwapp/sys/wdksapMobile/*default/index.do'));

  Uri get timetableTranslations =>
      route(_campusApp.resolve('/jwapp/i18n.do?appName=wdkbby&EMAP_LANG=zh'));

  Uri get accountConfig => route(
    _campusApp.resolve(
      '/jwapp/sys/funauthapp/api/getAppConfig/xsfacx-4766859113956613.do',
    ),
  );

  static Uri get teachingLogin => Uri.https(
    'jxzxehall.bit.edu.cn',
    '/auth-protocol-core/login',
    {'service': '${_campusApp.origin}/jwapp/sys/xsfacx/*default/index.do'},
  );

  static Uri get vpnLogin =>
      Uri.https('webvpn.bit.edu.cn', '/login', {'cas_login': 'true'});

  static Uri get recordsService => Uri.http('jwms.bit.edu.cn', '/');

  Uri endpoint(String path, {String app = 'wdkbby'}) =>
      route(_campusApp.resolve('/jwapp/sys/$app/$path'));

  Uri route(Uri url) {
    final encoded = _vpnHosts[url.host];
    if (this == campus || encoded == null) return url;
    return Uri.parse(
      'https://webvpn.bit.edu.cn/${url.scheme}/$encoded${url.path}'
      '${url.hasQuery ? '?${url.query}' : ''}',
    );
  }
}

bool isSchoolUrl(Uri uri) =>
    uri.userInfo.isEmpty &&
    ((uri.scheme == 'https' &&
            (uri.host == 'bit.edu.cn' || uri.host.endsWith('.bit.edu.cn'))) ||
        (uri.scheme == 'http' && uri.host == 'jwms.bit.edu.cn'));

bool isSchoolLogin(Uri uri) =>
    isSchoolUrl(uri) &&
    (uri.host == 'sso.bit.edu.cn' ||
        uri.host == 'login.bit.edu.cn' ||
        uri.path.contains('/authserver/login') ||
        uri.path.contains('/cas/login') ||
        (uri.host == 'webvpn.bit.edu.cn' && uri.path == '/login'));
