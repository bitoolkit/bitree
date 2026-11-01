class SchoolCredentialsRequired implements Exception {
  const SchoolCredentialsRequired([this.message = '请登录学校账号。']);

  final String message;

  @override
  String toString() => message;
}

class SessionExpired implements Exception {
  const SessionExpired();

  @override
  String toString() => '请先登录学校账号。本地课表可继续使用。';
}

class SchoolRequestError implements Exception {
  const SchoolRequestError(this.message);
  final String message;

  @override
  String toString() => message;
}

class SchoolConnectionError implements Exception {
  const SchoolConnectionError(this.url, this.cause);

  final Uri url;
  final Object cause;

  @override
  String toString() => cause.toString();
}

class SchoolStorageError implements Exception {
  const SchoolStorageError(this.message, [this.cause]);

  final String message;
  final Exception? cause;

  @override
  String toString() => message;
}

String? schoolPageError(String text) {
  if (text.contains('Illegal referrer')) {
    return '教学中心拒绝了请求来源，请稍后重试。';
  }
  if (text.contains('Access Denied') || text.contains('您没有权限访问该资源')) {
    return 'WebVPN 拒绝访问教学中心，请检查学校端的资源权限。';
  }
  return null;
}
