import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import '../core/diagnostics.dart';
import '../core/json.dart';

sealed class AppReleaseNotes {
  const AppReleaseNotes();

  factory AppReleaseNotes.fromJson(Object? value) {
    final json = jsonObject(value, 'notes');
    return switch (jsonStringField(json, 'type')) {
      'markdown' => ReleaseMarkdownNotes(jsonStringField(json, 'markdown')),
      'changes' => ReleaseChangeNotes.fromJson(json),
      'unchanged' => const ReleaseUnchangedNotes(),
      'unavailable' => const ReleaseUnavailableNotes(),
      final type => throw FormatException('notes.type 格式不正确：$type'),
    };
  }

  Map<String, Object?> toJson();
}

final class ReleaseMarkdownNotes extends AppReleaseNotes {
  const ReleaseMarkdownNotes(this.markdown);

  final String markdown;

  @override
  Map<String, Object?> toJson() => {'type': 'markdown', 'markdown': markdown};
}

final class ReleaseChangeNotes extends AppReleaseNotes {
  ReleaseChangeNotes({
    required List<ReleaseCommit> commits,
    required this.totalCommits,
    required this.comparisonUrl,
  }) : commits = List.unmodifiable(commits) {
    if (totalCommits < this.commits.length) {
      throw const FormatException('更新记录数量不正确');
    }
  }

  factory ReleaseChangeNotes.fromJson(Map<String, dynamic> json) =>
      ReleaseChangeNotes(
        commits: [
          for (final commit in jsonListField(json, 'commits'))
            ReleaseCommit.fromJson(jsonObject(commit, 'commits[]')),
        ],
        totalCommits: jsonIntField(json, 'totalCommits'),
        comparisonUrl: _httpsUri(json['comparisonUrl'], 'comparisonUrl'),
      );

  final List<ReleaseCommit> commits;
  final int totalCommits;
  final Uri comparisonUrl;

  @override
  Map<String, Object?> toJson() => {
    'type': 'changes',
    'commits': [for (final commit in commits) commit.toJson()],
    'totalCommits': totalCommits,
    'comparisonUrl': comparisonUrl.toString(),
  };
}

final class ReleaseCommit {
  ReleaseCommit({required this.message, required this.sha, required this.url}) {
    if (message.trim().isEmpty || sha.length < 7) {
      throw const FormatException('更新提交格式不正确');
    }
  }

  factory ReleaseCommit.fromJson(Map<String, dynamic> json) => ReleaseCommit(
    message: jsonStringField(json, 'message'),
    sha: jsonStringField(json, 'sha'),
    url: _httpsUri(json['url'], 'url'),
  );

  final String message;
  final String sha;
  final Uri url;

  String get shortSha => sha.substring(0, 7);

  Map<String, Object?> toJson() => {
    'message': message,
    'sha': sha,
    'url': url.toString(),
  };
}

final class ReleaseUnchangedNotes extends AppReleaseNotes {
  const ReleaseUnchangedNotes();

  @override
  Map<String, Object?> toJson() => {'type': 'unchanged'};
}

final class ReleaseUnavailableNotes extends AppReleaseNotes {
  const ReleaseUnavailableNotes();

  @override
  Map<String, Object?> toJson() => {'type': 'unavailable'};
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    required this.downloadUrl,
    required this.notes,
    required this.isDevelopment,
  });

  factory AppRelease.fromGitHub(
    Map<String, dynamic> release, {
    required Abi abi,
    String? version,
  }) {
    final url = _httpsUri(release['html_url'], 'html_url');
    final suffixes = switch (abi) {
      Abi.androidArm64 => [
        '-android-arm64-v8a.apk',
        '-android-arm64-v8a-debug-signed.apk',
      ],
      Abi.linuxX64 => ['-linux-x64.tar.xz'],
      Abi.linuxArm64 => ['-linux-arm64.tar.xz'],
      _ => <String>[],
    };
    return AppRelease(
      version: version ?? jsonStringField(release, 'tag_name'),
      url: url,
      downloadUrl: _assetDownload(release, suffixes) ?? url,
      notes: ReleaseMarkdownNotes(jsonStringFieldOrNull(release, 'body') ?? ''),
      isDevelopment: jsonBoolField(release, 'prerelease', fallback: false),
    );
  }

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    version: jsonStringField(json, 'version'),
    url: _httpsUri(json['url'], 'url'),
    downloadUrl: _httpsUri(json['downloadUrl'], 'downloadUrl'),
    notes: AppReleaseNotes.fromJson(json['notes']),
    isDevelopment: jsonBoolField(json, 'isDevelopment'),
  );

  final String version;
  final Uri url;
  final Uri downloadUrl;
  final AppReleaseNotes notes;
  final bool isDevelopment;

  Map<String, dynamic> toJson() => {
    'version': version,
    'url': url.toString(),
    'downloadUrl': downloadUrl.toString(),
    'notes': notes.toJson(),
    'isDevelopment': isDevelopment,
  };
}

Future<List<AppRelease>> availableAppReleases(
  String installed, {
  DateTime? builtAt,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  try {
    final [stableJson, releasesJson] = await Future.wait([
      _readJson(
        client,
        Uri.https('api.github.com', '/repos/bitoolkit/bitree/releases/latest'),
      ),
      _readJson(
        client,
        Uri.https('api.github.com', '/repos/bitoolkit/bitree/releases'),
      ),
    ]);
    final stable = _optionalObject(stableJson, 'stable release');
    final dev = _objects(releasesJson, 'releases')
        .where(
          (release) =>
              jsonBoolField(release, 'prerelease', fallback: false) &&
              RegExp(r'^v\d+\.\d+\.\d+-dev$')
                  .hasMatch(jsonStringField(release, 'tag_name')),
        )
        .firstOrNull;
    final stableUpdate = _stableUpdate(stable, installed, builtAt: builtAt);
    final developmentUpdate = await _developmentUpdate(
      client,
      dev,
      installed,
      builtAt: builtAt,
    );

    return await Future.wait([
      for (final update in [?stableUpdate, ?developmentUpdate])
        _withUpdateNotes(client, update, installed),
    ]);
  } finally {
    client.close(force: true);
  }
}

AppRelease? _stableUpdate(
  Map<String, dynamic>? release,
  String installed, {
  DateTime? builtAt,
}) {
  final normalized = installed.replaceFirst(RegExp(r'^v'), '');
  final current = Version.parse(normalized.split('-').first);
  if (release == null ||
      jsonBoolField(release, 'draft', fallback: false) ||
      jsonBoolField(release, 'prerelease', fallback: false)) {
    return null;
  }

  final tag = jsonStringField(release, 'tag_name');
  final version = Version.parse(tag.replaceFirst(RegExp(r'^v'), ''));
  final development = normalized.contains('-');
  final publishedAt = jsonDateTimeOrNull(
    'published_at',
    release['published_at'],
  );
  final releasedAfterBuild =
      development &&
      builtAt != null &&
      publishedAt != null &&
      publishedAt.isAfter(builtAt);
  final newer =
      version > current ||
      (development && version == current) ||
      releasedAfterBuild;
  if (version.isPreRelease || !newer) return null;

  return AppRelease.fromGitHub(release, abi: Abi.current());
}

Future<AppRelease?> _developmentUpdate(
  HttpClient client,
  Map<String, dynamic>? release,
  String installed, {
  DateTime? builtAt,
}) async {
  if (release == null || jsonBoolField(release, 'draft', fallback: false)) {
    return null;
  }

  final platform = Abi.current() == Abi.linuxArm64
      ? 'linux-arm64'
      : Platform.operatingSystem;
  final suffix = '-$platform-update.json';
  final assetUrl = _assetDownload(release, [suffix]);
  if (assetUrl == null) return null;

  final metadata = _optionalObject(
    await _readJson(client, assetUrl),
    'update metadata',
  );
  if (metadata == null) return null;

  final version = jsonStringField(metadata, 'version');
  final publishedBuildTime = jsonDateTime('builtAt', metadata['builtAt']);
  final newer = builtAt == null
      ? version != installed
      : publishedBuildTime.isAfter(builtAt);
  if (!newer) return null;

  return AppRelease.fromGitHub(release, abi: Abi.current(), version: version);
}

String _revision(String version) =>
    RegExp(r'-(?:dev\.)?([0-9a-f]{7,40})$').firstMatch(version)?[1] ??
    (version.startsWith('v') ? version : 'v$version');

Future<AppRelease> _withUpdateNotes(
  HttpClient client,
  AppRelease release,
  String installed,
) async {
  late AppReleaseNotes notes;
  try {
    notes = await _updateNotes(
      client,
      _revision(installed),
      _revision(release.version),
    );
  } on Exception catch (failure, stack) {
    AppDiagnostics.instance.error('读取 ${release.version} 更新日志', failure, stack);
    notes = const ReleaseUnavailableNotes();
  }
  return AppRelease(
    version: release.version,
    url: release.url,
    downloadUrl: release.downloadUrl,
    notes: notes,
    isDevelopment: release.isDevelopment,
  );
}

Future<AppReleaseNotes> _updateNotes(
  HttpClient client,
  String base,
  String head,
) async {
  const previewCount = 6;
  const pageSize = 100;
  if (base == head) return const ReleaseUnchangedNotes();

  Future<Map<String, dynamic>> readPage(int page) async {
    final url = Uri.https(
      'api.github.com',
      '/repos/bitoolkit/bitree/compare/$base...$head',
      {'per_page': '$pageSize', 'page': '$page'},
    );
    final comparison = _optionalObject(
      await _readJson(client, url),
      'comparison',
    );
    if (comparison == null) {
      throw HttpException('找不到版本比较记录。', uri: url);
    }
    return comparison;
  }

  final first = await readPage(1);
  final total = jsonIntField(first, 'total_commits');
  if (total < 0) throw const FormatException('total_commits 格式不正确');
  if (total == 0) return const ReleaseUnchangedNotes();

  var commits = _commits(first);
  if (total > pageSize) {
    final lastPage = (total + pageSize - 1) ~/ pageSize;
    final last = await readPage(lastPage);
    commits = _commits(last);
    if (commits.length < previewCount) {
      final previous = lastPage == 2 ? first : await readPage(lastPage - 1);
      commits = [..._commits(previous), ...commits];
    }
  }

  final preview = commits.reversed.take(previewCount).toList();
  return ReleaseChangeNotes(
    commits: preview.map(_releaseCommit).toList(),
    totalCommits: total,
    comparisonUrl: Uri.https(
      'github.com',
      '/bitoolkit/bitree/compare/$base...$head',
    ),
  );
}

Future<Object?> _readJson(HttpClient client, Uri url) async {
  final request = await client.getUrl(url).timeout(const Duration(seconds: 15));
  request.headers
    ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
    ..set(HttpHeaders.userAgentHeader, 'BITree')
    ..set('X-GitHub-Api-Version', '2022-11-28');

  final response = await request.close().timeout(const Duration(seconds: 15));
  if (response.statusCode == HttpStatus.notFound) return null;
  if (response.statusCode == HttpStatus.forbidden ||
      response.statusCode == HttpStatus.tooManyRequests) {
    throw const HttpException('检查更新次数过多，请稍后重试。');
  }
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('GitHub 暂时无法提供更新信息（${response.statusCode}）。');
  }

  final text = await response
      .transform(utf8.decoder)
      .join()
      .timeout(const Duration(seconds: 15));
  try {
    return jsonDecode(text);
  } on FormatException catch (failure) {
    throw FormatException('GitHub 返回了无法解析的数据：${failure.message}');
  }
}

Uri _httpsUri(Object? value, String field) {
  final text = jsonString(value, field);
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw FormatException('$field 不是有效的 HTTPS 地址');
  }
  return uri;
}

Map<String, dynamic>? _optionalObject(Object? value, String field) =>
    value == null ? null : jsonObject(value, field);

List<Map<String, dynamic>> _objects(Object? value, String field) {
  final values = value == null ? const [] : jsonList(value, field);
  return [for (final item in values) jsonObject(item, '$field[]')];
}

List<Map<String, dynamic>> _assets(Map<String, dynamic> release) {
  final value = release['assets'];
  return value == null ? const [] : _objects(value, 'assets');
}

Uri? _assetDownload(Map<String, dynamic> release, List<String> suffixes) {
  final assets = _assets(release);
  for (final suffix in suffixes) {
    for (final asset in assets) {
      if (jsonStringField(asset, 'name').endsWith(suffix)) {
        return _httpsUri(
          asset['browser_download_url'],
          'assets[].browser_download_url',
        );
      }
    }
  }
  return null;
}

List<Map<String, dynamic>> _commits(Map<String, dynamic> comparison) => [
  for (final commit in jsonListField(comparison, 'commits'))
    jsonObject(commit, 'commits[]'),
];

ReleaseCommit _releaseCommit(Map<String, dynamic> commit) {
  final commitData = jsonObjectField(commit, 'commit');
  final message = jsonStringField(commitData, 'message').split('\n').first;
  return ReleaseCommit(
    message: message,
    sha: jsonStringField(commit, 'sha'),
    url: _httpsUri(commit['html_url'], 'commits[].html_url'),
  );
}
