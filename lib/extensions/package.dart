import 'dart:convert';
import 'dart:io';

import '../sources/source.dart';

/// API major version understood by this build. A package declaring another
/// major version is rejected before any Lua code runs.
const supportedExtensionApiVersion = 1;

class ExtensionManifest {
  ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.sources,
  }) {
    if (id.trim().isEmpty || version.trim().isEmpty) {
      throw const FormatException('扩展包缺少编号或版本');
    }
    if (apiVersion != supportedExtensionApiVersion) {
      throw FormatException(
        '扩展需要 API $apiVersion，当前仅支持 $supportedExtensionApiVersion。',
      );
    }
    if (sources.isEmpty) {
      throw const FormatException('扩展包没有来源');
    }
    final ids = <String>{};
    for (final source in sources) {
      if (!ids.add(source.id)) {
        throw FormatException('扩展包来源编号重复：${source.id}');
      }
    }
  }

  factory ExtensionManifest.parse(Object? value) {
    if (value is! Map) throw const FormatException('manifest.json 格式不正确');
    final json = Map<String, dynamic>.from(value);
    final rawSources = json['sources'];
    if (rawSources is! List || rawSources.isEmpty) {
      throw const FormatException('扩展包没有来源');
    }
    final packageId = _requiredString(json, 'id');
    final apiVersion = json['apiVersion'];
    if (apiVersion is! int) {
      throw const FormatException('manifest.json 缺少 apiVersion');
    }
    final packagePermissions = SourcePermissions.parse(json['permissions']);
    final fallbackName = LocalizedSourceName.parse(json['name']);
    final version = _requiredString(json, 'version');
    return ExtensionManifest(
      id: packageId,
      name: fallbackName,
      version: version,
      apiVersion: apiVersion,
      sources: [
        for (final raw in rawSources)
          ExtensionSourceDeclaration.parse(
            raw,
            packageId: packageId,
            packageVersion: version,
            packageName: fallbackName,
            packagePermissions: packagePermissions,
          ),
      ],
    );
  }

  final String id;
  final LocalizedSourceName name;
  final String version;
  final int apiVersion;
  final List<ExtensionSourceDeclaration> sources;

  List<SourceDefinition> get definitions => [
    for (final source in sources) source.toDefinition(id, apiVersion),
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'version': version,
    'apiVersion': apiVersion,
    'sources': [for (final source in sources) source.toJson()],
  };
}

class ExtensionSourceDeclaration {
  ExtensionSourceDeclaration({
    required this.id,
    required this.name,
    required this.entry,
    this.extendsId,
    this.baseVersion,
    this.version = '1.0.0',
    this.operations = const {},
    this.permissions,
    this.settings = const [],
    this.actions = const [],
    this.courseInput = const [],
    this.inputResources = const {},
    this.auth = SourceAuthMode.none,
  }) {
    if (id.trim().isEmpty) throw const FormatException('来源缺少编号');
    _validateRelativeLuaPath(entry);
    if (extendsId != null && (baseVersion == null || baseVersion!.isEmpty)) {
      throw const FormatException('继承来源必须声明 baseVersion');
    }
    if (extendsId == null && operations.isEmpty) {
      throw FormatException('来源 $id 没有声明任何操作');
    }
  }

  factory ExtensionSourceDeclaration.parse(
    Object? value, {
    required String packageId,
    required String packageVersion,
    required LocalizedSourceName packageName,
    required SourcePermissions packagePermissions,
  }) {
    if (value is! Map) throw const FormatException('来源声明格式不正确');
    final json = Map<String, dynamic>.from(value);
    final id = _requiredString(json, 'id');
    final entry = _requiredString(json, 'entry');
    final rawOperations = json['operations'];
    final operations = rawOperations == null
        ? <SourceOperation>{}
        : {
            for (final operation in _list(rawOperations, 'operations'))
              SourceOperation.parse(operation),
          };
    final sourcePermissions = json['permissions'] == null
        ? packagePermissions
        : SourcePermissions.parse(json['permissions']);
    return ExtensionSourceDeclaration(
      id: id,
      name: json['name'] == null
          ? packageName
          : LocalizedSourceName.parse(json['name'], field: 'name'),
      entry: entry,
      extendsId: json['extends'] == null
          ? null
          : _requiredString(json, 'extends'),
      baseVersion: json['baseVersion'] == null
          ? null
          : _requiredString(json, 'baseVersion'),
      version: json['version'] == null
          ? packageVersion
          : _requiredString(json, 'version'),
      operations: operations,
      permissions: sourcePermissions,
      settings: [
        for (final field in _listOrEmpty(json['settings'], 'settings'))
          SourceField.parse(field),
      ],
      actions: [
        for (final action in _listOrEmpty(json['actions'], 'actions'))
          SourceAction.parse(action),
      ],
      courseInput: [
        for (final field in _listOrEmpty(json['courseInput'], 'courseInput'))
          SourceField.parse(field),
      ],
      inputResources: {
        for (final resource in _listOrEmpty(json['inputs'], 'inputs'))
          SourceResource.parse(resource),
      },
      auth: json['auth'] == null
          ? SourceAuthMode.none
          : SourceAuthMode.parse(json['auth']),
    );
  }

  final String id;
  final LocalizedSourceName name;
  final String entry;
  final String? extendsId;
  final String? baseVersion;
  final String version;
  final Set<SourceOperation> operations;
  final SourcePermissions? permissions;
  final List<SourceField> settings;
  final List<SourceAction> actions;
  final List<SourceField> courseInput;
  final Set<SourceResource> inputResources;
  final SourceAuthMode auth;

  String definitionId(String packageId) => '$packageId/$id';

  SourceDefinition toDefinition(String packageId, int apiVersion) =>
      SourceDefinition(
        id: definitionId(packageId),
        packageId: packageId,
        sourceId: id,
        name: name,
        version: version,
        apiVersion: apiVersion,
        extendsId: extendsId,
        baseVersion: baseVersion,
        entry: entry,
        operations: operations,
        permissions: permissions ?? SourcePermissions(),
        settings: settings,
        actions: actions,
        courseInput: courseInput,
        inputResources: inputResources,
        auth: auth,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'entry': entry,
    if (extendsId != null) 'extends': extendsId,
    if (baseVersion != null) 'baseVersion': baseVersion,
    'version': version,
    'operations': [for (final operation in operations) operation.wireName],
    if (permissions case final permissions?)
      'permissions': permissions.toJson(),
    if (settings.isNotEmpty)
      'settings': [for (final field in settings) field.toJson()],
    if (actions.isNotEmpty)
      'actions': [for (final action in actions) action.toJson()],
    if (courseInput.isNotEmpty)
      'courseInput': [for (final field in courseInput) field.toJson()],
    if (inputResources.isNotEmpty)
      'inputs': [for (final resource in inputResources) resource.wireName],
    if (auth != SourceAuthMode.none) 'auth': auth.wireName,
  };
}

class ExtensionPackage {
  ExtensionPackage({
    required this.manifest,
    required this.location,
    this.installedAt,
  }) {
    if (location.trim().isEmpty) {
      throw const FormatException('扩展包缺少安装位置');
    }
  }

  factory ExtensionPackage.fromJson(Map<String, dynamic> json) =>
      ExtensionPackage(
        manifest: ExtensionManifest.parse(json['manifest']),
        location: _requiredString(json, 'location'),
        installedAt: json['installedAt'] is String
            ? DateTime.tryParse(json['installedAt'] as String)
            : null,
      );

  final ExtensionManifest manifest;
  final String location;
  final DateTime? installedAt;

  ExtensionPackage installed(DateTime at) =>
      ExtensionPackage(manifest: manifest, location: location, installedAt: at);

  Map<String, Object?> toJson() => {
    'manifest': manifest.toJson(),
    'location': location,
    if (installedAt != null) 'installedAt': installedAt!.toIso8601String(),
  };
}

class ExtensionPackageLoader {
  const ExtensionPackageLoader({this.maxManifestBytes = 256 * 1024});

  final int maxManifestBytes;

  Future<ExtensionPackage> readDirectory(String path) async {
    final directory = Directory(path);
    _checkRealDirectory(directory);
    final manifestFile = File('${directory.path}/manifest.json');
    _checkRegularFile(manifestFile, maxBytes: maxManifestBytes);
    final text = await manifestFile.readAsString();
    final manifest = ExtensionManifest.parse(jsonDecode(text));
    for (final source in manifest.sources) {
      final file = File('${directory.path}/${source.entry}');
      _checkRegularFile(file, maxBytes: 512 * 1024);
    }
    return ExtensionPackage(manifest: manifest, location: directory.path);
  }

  Future<Map<String, String>> readSources(ExtensionPackage package) async {
    final result = <String, String>{};
    for (final source in package.manifest.sources) {
      final file = File('${package.location}/${source.entry}');
      _checkRegularFile(file, maxBytes: 512 * 1024);
      result[source.entry] = await file.readAsString();
    }
    return result;
  }
}

void _validateRelativeLuaPath(String value) {
  if (!value.endsWith('.lua') ||
      value.startsWith('/') ||
      value.contains('\\') ||
      value.split('/').any((part) => part.isEmpty || part == '..')) {
    throw FormatException('扩展脚本路径无效：$value');
  }
}

void _checkRealDirectory(Directory directory) {
  final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
  if (type != FileSystemEntityType.directory) {
    throw const FormatException('扩展目录不存在或不是普通目录');
  }
}

void _checkRegularFile(File file, {required int maxBytes}) {
  final type = FileSystemEntity.typeSync(file.path, followLinks: false);
  if (type != FileSystemEntityType.file) {
    throw FormatException('扩展文件不存在或不是普通文件：${file.path}');
  }
  final size = file.lengthSync();
  if (size > maxBytes) {
    throw FormatException('扩展文件过大：${file.path}');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('manifest.json 缺少 $key');
}

List<Object?> _list(Object? value, String field) {
  if (value is List) return value;
  throw FormatException('$field 格式不正确');
}

List<Object?> _listOrEmpty(Object? value, String field) =>
    value == null ? const [] : _list(value, field);
