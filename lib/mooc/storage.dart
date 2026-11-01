import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credentials.dart';

class MoocStorage {
  static const _key = 'bitree.icourse163.account';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  Future<MoocAccount?> read() async {
    final text = await _storage.read(key: _key);
    if (text == null) return null;
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('保存的 MOOC 账号已损坏，请重新登录。');
    }
    return MoocAccount.fromJson(value);
  }

  Future<void> write(MoocAccount account) =>
      _storage.write(key: _key, value: jsonEncode(account.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
