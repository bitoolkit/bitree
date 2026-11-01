import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'errors.dart';
import 'network.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);

const _credentialsKey = 'bitree.school.credentials';
const _cookiePrefix = 'bitree.school.cookie.';

class SchoolCredentials {
  const SchoolCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

class SchoolStorage {
  final _cookies = <SchoolNetwork, PersistCookieJar>{};

  PersistCookieJar _cookiesFor(SchoolNetwork network) => _cookies.putIfAbsent(
    network,
    () => PersistCookieJar(
      storage: _SecureCookieStorage(network),
      persistSession: true,
    ),
  );

  Future<SchoolCredentials?> readCredentials() async {
    final saved = await _accessStorage(
      () => _secureStorage.read(key: _credentialsKey),
    );
    if (saved == null) return null;

    Object? value;
    try {
      value = jsonDecode(saved);
    } on FormatException {
      throw const SchoolStorageError('保存的登录信息已损坏，请退出账号后重新登录。');
    }

    return switch (value) {
      {'username': final String username, 'password': final String password} =>
        SchoolCredentials(username: username, password: password),
      _ => throw const SchoolStorageError('保存的登录信息已损坏，请退出账号后重新登录。'),
    };
  }

  Future<void> saveCredentials(SchoolCredentials credentials) => _accessStorage(
    () => _secureStorage.write(
      key: _credentialsKey,
      value: jsonEncode({
        'username': credentials.username,
        'password': credentials.password,
      }),
    ),
  );

  Future<List<Cookie>> cookiesFor(SchoolNetwork network, Uri source) async {
    final cookies = await _cookiesFor(network).loadForRequest(source);
    return source.scheme == 'https'
        ? cookies
        : cookies.where((cookie) => !cookie.secure).toList(growable: false);
  }

  Future<void> saveCookies(
    SchoolNetwork network,
    Uri source,
    List<Cookie> cookies,
  ) async {
    for (final cookie in cookies) {
      final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
      if (domain != null &&
          domain.isNotEmpty &&
          (!isSchoolUrl(Uri.https(domain)) ||
              (source.host != domain && !source.host.endsWith('.$domain')))) {
        throw const FormatException('学校会话的 Cookie 域名不匹配');
      }
    }

    await _cookiesFor(network).saveFromResponse(source, cookies);
  }

  Future<void> _deleteWhere(bool Function(String) matches) async {
    await _accessStorage(() async {
      final saved = await _secureStorage.readAll();
      for (final key in saved.keys) {
        if (matches(key)) {
          await _secureStorage.delete(key: key);
        }
      }
    });
  }

  Future<void> clearSession(SchoolNetwork network) async {
    await _deleteWhere(
      (key) => key.startsWith('$_cookiePrefix${network.name}.'),
    );
    _cookies.remove(network);
  }

  Future<void> clear() async {
    await _deleteWhere(
      (key) => key == _credentialsKey || key.startsWith(_cookiePrefix),
    );
    _cookies.clear();
  }
}

Future<T> _accessStorage<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on Exception catch (error) {
    throw SchoolStorageError(
      Platform.isLinux ? '无法访问系统密钥环，请确认密钥环已解锁后重试。' : '无法访问系统安全存储，请稍后重试。',
      error,
    );
  }
}

class _SecureCookieStorage implements Storage {
  const _SecureCookieStorage(this.network);

  final SchoolNetwork network;

  String _key(String key) => '$_cookiePrefix${network.name}.$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) =>
      _accessStorage(() => _secureStorage.read(key: _key(key)));

  @override
  Future<void> write(String key, String value) =>
      _accessStorage(() => _secureStorage.write(key: _key(key), value: value));

  @override
  Future<void> delete(String key) =>
      _accessStorage(() => _secureStorage.delete(key: _key(key)));

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}
