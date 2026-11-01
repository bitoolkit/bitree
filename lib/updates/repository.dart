import 'dart:convert';
import 'dart:ffi';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/diagnostics.dart';
import '../core/json.dart';
import 'release.dart';

/// Keeps update results across launches and prompts only for unseen stable releases.
class UpdateRepository {
  UpdateRepository(this._preferences);

  static const _cacheKey = 'updates.cache';
  static const _maxAge = Duration(days: 1);
  final SharedPreferencesAsync _preferences;

  Future<List<AppRelease>> check(
    String installed, {
    DateTime? builtAt,
    bool automatic = false,
  }) async {
    final available = automatic
        ? await _cached(installed, builtAt) ??
              await _refresh(installed, builtAt)
        : await _refresh(installed, builtAt);
    if (!automatic) return available;

    final notifications = <AppRelease>[];
    for (final release in available) {
      if (!release.isDevelopment &&
          await _preferences.getString(_notifiedKey(release)) !=
              release.version) {
        notifications.add(release);
      }
    }
    return notifications;
  }

  Future<void> markNotified(List<AppRelease> releases) async {
    for (final release in releases) {
      await _preferences.setString(_notifiedKey(release), release.version);
    }
  }

  String _notifiedKey(AppRelease release) =>
      'updates.${release.isDevelopment ? 'dev' : 'stable'}.notifiedVersion';

  Future<List<AppRelease>?> _cached(String installed, DateTime? builtAt) async {
    try {
      final text = await _preferences.getString(_cacheKey);
      if (text == null) return null;
      final data = jsonObject(jsonDecode(text), '更新缓存');
      if (data['installed'] != installed ||
          jsonStringFieldOrNull(data, 'builtAt') !=
              builtAt?.toIso8601String() ||
          data['abi'] != Abi.current().toString()) {
        return null;
      }
      final checkedAt = _cacheTime(jsonIntField(data, 'checkedAt'));
      final age = DateTime.now().difference(checkedAt);
      if (age.isNegative || age >= _maxAge) return null;
      return [
        for (final release in jsonListField(data, 'releases'))
          AppRelease.fromJson(jsonObject(release, 'releases[]')),
      ];
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('读取更新缓存', failure, stack);
      return null;
    }
  }

  Future<List<AppRelease>> _refresh(String installed, DateTime? builtAt) async {
    final available = await availableAppReleases(installed, builtAt: builtAt);
    try {
      await _preferences.setString(
        _cacheKey,
        jsonEncode({
          'installed': installed,
          'builtAt': builtAt?.toIso8601String(),
          'abi': Abi.current().toString(),
          'checkedAt': DateTime.now().millisecondsSinceEpoch,
          'releases': available.map((release) => release.toJson()).toList(),
        }),
      );
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('保存更新缓存', failure, stack);
    }
    return available;
  }
}

DateTime _cacheTime(int milliseconds) {
  try {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  } on ArgumentError {
    throw const FormatException('checkedAt 超出有效范围');
  }
}
