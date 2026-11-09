import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'runtime.dart';

/// Stores extension-owned secrets outside the JSON source library. Each
/// package and source instance receives a separate namespace.
class SecureSourceSecrets implements SourceSecretStore {
  const SecureSourceSecrets();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  String _key(String namespace, String key) =>
      'bitree.source.secret.${Uri.encodeComponent(namespace)}.'
      '${Uri.encodeComponent(key)}';

  @override
  Future<Object?> read(String namespace, String key) async {
    final text = await _storage.read(key: _key(namespace, key));
    if (text == null) return null;
    return jsonDecode(text);
  }

  @override
  Future<void> write(String namespace, String key, Object? value) async {
    final encoded = jsonEncode(value);
    if (utf8.encode(encoded).length > 64 * 1024) {
      throw const FormatException('来源秘密值超过 64 KiB');
    }
    await _storage.write(key: _key(namespace, key), value: encoded);
  }

  @override
  Future<void> remove(String namespace, String key) =>
      _storage.delete(key: _key(namespace, key));
}
