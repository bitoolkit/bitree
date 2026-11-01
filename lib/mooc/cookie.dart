import 'dart:io';

/// Keeps browser cookie values verbatim, including commas and quoted data.
/// Dart's Cookie factory enforces the stricter server-side value grammar; its
/// attribute parsing still handles scope and expiry for the existing cookie jar.
class MoocCookie implements Cookie {
  MoocCookie(String name, String value)
    : _attributes = Cookie(name, ''),
      _value = _validateValue(value);

  MoocCookie._(this._attributes, String value) : _value = _validateValue(value);

  factory MoocCookie.fromSetCookieValue(String source) {
    final end = source.indexOf(';');
    final pair = end < 0 ? source : source.substring(0, end);
    final separator = pair.indexOf('=');
    if (separator <= 0) {
      throw const FormatException('MOOC 会话 Cookie 格式不正确。');
    }
    final name = pair.substring(0, separator).trim();
    final value = pair.substring(separator + 1).trim();
    final attributes = end < 0 ? '' : source.substring(end);
    return MoocCookie._(Cookie.fromSetCookieValue('$name=x$attributes'), value);
  }

  final Cookie _attributes;
  String _value;

  static String _validateValue(String value) {
    if (value.codeUnits.any(
      (code) => code < 0x20 || code == 0x7f || code > 0xff || code == 0x3b,
    )) {
      throw const FormatException('MOOC 会话 Cookie 含有无效字符，请重新登录。');
    }
    return value;
  }

  @override
  String get name => _attributes.name;
  @override
  set name(String value) => _attributes.name = value;
  @override
  String get value => _value;
  @override
  set value(String value) => _value = _validateValue(value);
  @override
  DateTime? get expires => _attributes.expires;
  @override
  set expires(DateTime? value) => _attributes.expires = value;
  @override
  int? get maxAge => _attributes.maxAge;
  @override
  set maxAge(int? value) => _attributes.maxAge = value;
  @override
  String? get domain => _attributes.domain;
  @override
  set domain(String? value) => _attributes.domain = value;
  @override
  String? get path => _attributes.path;
  @override
  set path(String? value) => _attributes.path = value;
  @override
  bool get secure => _attributes.secure;
  @override
  set secure(bool value) => _attributes.secure = value;
  @override
  bool get httpOnly => _attributes.httpOnly;
  @override
  set httpOnly(bool value) => _attributes.httpOnly = value;
  @override
  SameSite? get sameSite => _attributes.sameSite;
  @override
  set sameSite(SameSite? value) => _attributes.sameSite = value;

  @override
  String toString() {
    final serialized = _attributes.toString();
    final attributes = serialized.indexOf(';');
    return '$name=$value${attributes < 0 ? '' : serialized.substring(attributes)}';
  }
}
