import 'dart:io';

import 'cookie.dart';
import 'errors.dart';

/// Cookies and the browser user agent needed by MOOC's authenticated APIs.
/// Passwords are never stored here.
class MoocCredentials {
  MoocCredentials({required this.userAgent, required Iterable<Cookie> cookies})
    : cookies = List.unmodifiable(_requestCookies(cookies)) {
    if (userAgent.trim().isEmpty || userAgent.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('无法读取登录浏览器的信息，请重新登录。');
    }
    if (!hasSession(this.cookies.map(MoocCookie.fromSetCookieValue))) {
      throw const MoocFailure.issue(MoocIssue.noSession);
    }
  }

  final String userAgent;
  final List<String> cookies;

  static final origin = Uri.https('www.icourse163.org');
  static final rpcDirectory = origin.resolve('/web/j/');
  static const _sessionCookieNames = {'STUDY_SESS', 'STUDY_INFO', 'NTES_SESS'};

  static bool isMoocHost(String host) =>
      host == 'icourse163.org' || host.endsWith('.icourse163.org');

  static bool hasSession(Iterable<Cookie> cookies) {
    var hasCsrf = false;
    var hasSession = false;
    for (final cookie in cookies) {
      hasCsrf |= cookie.name == 'NTESSTUDYSI';
      hasSession |= _sessionCookieNames.contains(cookie.name);
    }
    return hasCsrf && hasSession;
  }

  /// A copied request header has no cookie scope metadata. Treat its first
  /// occurrence of a name as the value selected by the browser for this URL.
  static List<Cookie> cookiesFromHeader(String input) {
    final header = RegExp(
      r'^\s*cookie\s*:\s*([^\r\n]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(input);
    final value = header?.group(1) ?? input.trim();
    if (value.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('请粘贴 Cookie 值或包含 Cookie 的请求头。');
    }
    final names = <String>{};
    final cookies = <Cookie>[];
    for (final part in value.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final content = part.substring(separator + 1).trim();
      if (content.isEmpty || !names.add(name)) continue;
      cookies.add(
        MoocCookie(name, content)
          ..path = '/'
          ..secure = true,
      );
    }
    if (!hasSession(cookies)) {
      throw const MoocFailure.issue(MoocIssue.noSession);
    }
    return cookies;
  }

  Map<String, Object> toJson() => {'userAgent': userAgent, 'cookies': cookies};

  factory MoocCredentials.fromJson(Map<String, dynamic> json) {
    final agent = json['userAgent'];
    final values = json['cookies'];
    if (agent is! String ||
        values is! List ||
        values.any((v) => v is! String)) {
      throw const FormatException('保存的 MOOC 会话已损坏，请重新登录。');
    }
    return MoocCredentials(
      userAgent: agent,
      cookies: values.cast<String>().map(MoocCookie.fromSetCookieValue),
    );
  }

  static Iterable<String> _requestCookies(Iterable<Cookie> input) sync* {
    final seen = <(String, String, String)>{};
    for (final cookie in input) {
      final domain =
          cookie.domain?.toLowerCase().replaceFirst(RegExp(r'^\.'), '') ??
          origin.host;
      final path = cookie.path?.isNotEmpty == true ? cookie.path! : '/';
      if (!isMoocHost(domain) ||
          !(origin.host == domain || origin.host.endsWith('.$domain')) ||
          !(rpcDirectory.path == path ||
              rpcDirectory.path.startsWith(
                path.endsWith('/') ? path : '$path/',
              )) ||
          cookie.value.isEmpty ||
          cookie.maxAge == 0 ||
          (cookie.expires?.isBefore(DateTime.now()) ?? false) ||
          !seen.add((domain, path, cookie.name))) {
        continue;
      }
      yield cookie.toString();
    }
  }
}

class MoocAccount {
  const MoocAccount({
    required this.id,
    required this.name,
    required this.credentials,
  });

  final String id;
  final String name;
  final MoocCredentials credentials;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'credentials': credentials.toJson(),
  };

  factory MoocAccount.fromJson(Map<String, dynamic> json) => switch (json) {
    {
      'id': final String id,
      'name': final String name,
      'credentials': final Map<String, dynamic> credentials,
    }
        when id.isNotEmpty =>
      MoocAccount(
        id: id,
        name: name,
        credentials: MoocCredentials.fromJson(credentials),
      ),
    _ => throw const FormatException('保存的 MOOC 账号已损坏，请重新登录。'),
  };
}
