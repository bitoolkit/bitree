import 'dart:convert';

/// Business resources a source can read or write. These names are also used
/// in persisted origins, so they must stay stable.
enum SourceResource {
  course('course'),
  timetable('timetable'),
  deadline('deadline'),
  event('event'),
  exam('exam'),
  grade('grade'),
  studyPlan('studyPlan'),
  classroom('classroom');

  const SourceResource(this.wireName);

  final String wireName;

  static SourceResource parse(Object? value) {
    final name = value is String ? value : null;
    return SourceResource.values.firstWhere(
      (resource) => resource.wireName == name,
      orElse: () => throw FormatException('未知的数据类型：$value'),
    );
  }
}

/// Operations exposed by a source implementation. The wire name is the
/// operation name used from Lua and in manifests.
enum SourceOperation {
  authCheck('auth.check'),
  authLogin('auth.login'),
  authLogout('auth.logout'),
  termsList('terms.list'),
  termsRead('terms.read'),
  coursesList('courses.list'),
  coursesResolve('courses.resolve'),
  timetableRead('timetable.read'),
  deadlinesRead('deadlines.read'),
  deadlinesReadAccount('deadlines.readAccount'),
  agendaRead('agenda.read'),
  examsRead('exams.read'),
  gradesRead('grades.read'),
  studyPlanRead('studyPlan.read'),
  classroomsDirectory('classrooms.directory'),
  classroomsOccupancy('classrooms.occupancy');

  const SourceOperation(this.wireName);

  final String wireName;

  static SourceOperation parse(Object? value) {
    final name = value is String ? value : null;
    return SourceOperation.values.firstWhere(
      (operation) => operation.wireName == name,
      orElse: () => throw FormatException('未知的数据操作：$value'),
    );
  }
}

class LocalizedSourceName {
  const LocalizedSourceName(this.values);

  factory LocalizedSourceName.parse(Object? value, {String field = 'name'}) {
    if (value is String && value.trim().isNotEmpty) {
      return LocalizedSourceName({'zh': value.trim()});
    }
    if (value is Map) {
      final values = <String, String>{};
      for (final entry in value.entries) {
        final key = entry.key;
        final text = entry.value;
        if (key is! String ||
            key.trim().isEmpty ||
            text is! String ||
            text.trim().isEmpty) {
          throw FormatException('$field 的本地化名称格式不正确');
        }
        values[key] = text.trim();
      }
      if (values.isNotEmpty) return LocalizedSourceName(values);
    }
    throw FormatException('$field 名称缺失');
  }

  final Map<String, String> values;

  String resolve(String languageCode) =>
      values[languageCode] ??
      values['zh'] ??
      values['en'] ??
      values.values.first;

  Map<String, Object?> toJson() => Map.unmodifiable(values);
}

/// Limits a source can use. The effective permission set is the intersection
/// of these declarations and the capabilities granted by the user.
class SourcePermissions {
  SourcePermissions({
    Iterable<String> networkHosts = const [],
    Iterable<String> sessionServices = const [],
    Iterable<SourceResource> dataRead = const [],
    Iterable<SourceResource> dataEdit = const [],
    Map<String, Set<String>> cookies = const {},
  }) : networkHosts = Set.unmodifiable(
         networkHosts.map(_normalizeNetworkOrigin),
       ),
       sessionServices = Set.unmodifiable(sessionServices),
       dataRead = Set.unmodifiable(dataRead),
       dataEdit = Set.unmodifiable(dataEdit),
       cookies = Map.unmodifiable({
         for (final entry in cookies.entries)
           entry.key: Set.unmodifiable(entry.value),
       });

  factory SourcePermissions.parse(Object? value) {
    if (value == null) return SourcePermissions();
    if (value is! Map) {
      throw const FormatException('permissions 格式不正确');
    }
    return SourcePermissions(
      networkHosts: _strings(value['network'], 'permissions.network'),
      sessionServices: _strings(value['sessions'], 'permissions.sessions'),
      dataRead: [
        for (final resource in _objects(
          value['dataRead'],
          'permissions.dataRead',
        ))
          SourceResource.parse(resource),
      ],
      dataEdit: [
        for (final resource in _objects(
          value['dataEdit'],
          'permissions.dataEdit',
        ))
          SourceResource.parse(resource),
      ],
      cookies: {
        for (final entry in _map(
          value['cookies'],
          'permissions.cookies',
        ).entries)
          entry.key: {
            for (final name in _objects(
              entry.value,
              'permissions.cookies.${entry.key}',
            ))
              if (name is String && name.trim().isNotEmpty) name,
          },
      },
    );
  }

  /// Exact HTTPS origins such as `https://lexue.bit.edu.cn`.
  final Set<String> networkHosts;

  /// Account service names such as `bit.lexue` or `icourse163`.
  final Set<String> sessionServices;

  final Set<SourceResource> dataRead;
  final Set<SourceResource> dataEdit;

  /// Service name to allowed cookie names for authentication implementations.
  final Map<String, Set<String>> cookies;

  bool get isEmpty =>
      networkHosts.isEmpty &&
      sessionServices.isEmpty &&
      dataRead.isEmpty &&
      dataEdit.isEmpty &&
      cookies.isEmpty;

  bool allows(Uri url) {
    if (url.scheme != 'https' || url.userInfo.isNotEmpty || url.port != 443) {
      return false;
    }
    return networkHosts.contains('https://${url.host}');
  }

  SourcePermissions intersect(SourcePermissions other) => SourcePermissions(
    networkHosts: networkHosts.intersection(other.networkHosts),
    sessionServices: sessionServices.intersection(other.sessionServices),
    dataRead: dataRead.intersection(other.dataRead),
    dataEdit: dataEdit.intersection(other.dataEdit),
    cookies: {
      for (final service in cookies.keys)
        if (other.cookies[service] case final otherNames?)
          service: cookies[service]!.intersection(otherNames),
    },
  );

  Map<String, Object?> toJson() => {
    if (networkHosts.isNotEmpty) 'network': networkHosts.toList()..sort(),
    if (sessionServices.isNotEmpty)
      'sessions': sessionServices.toList()..sort(),
    if (dataRead.isNotEmpty)
      'dataRead': [for (final resource in dataRead) resource.wireName],
    if (dataEdit.isNotEmpty)
      'dataEdit': [for (final resource in dataEdit) resource.wireName],
    if (cookies.isNotEmpty)
      'cookies': {
        for (final entry in cookies.entries)
          entry.key: entry.value.toList()..sort(),
      },
  };
}

enum SourceFieldType {
  text('text'),
  multiline('multiline'),
  secret('secret'),
  integer('integer'),
  number('number'),
  toggle('toggle'),
  choice('choice'),
  multiChoice('multiChoice'),
  date('date'),
  time('time'),
  url('url'),
  course('course'),
  term('term'),
  rows('rows');

  const SourceFieldType(this.wireName);

  final String wireName;

  static SourceFieldType parse(Object? value) {
    final name = value is String ? value : null;
    return SourceFieldType.values.firstWhere(
      (type) => type.wireName == name,
      orElse: () => throw FormatException('未知的字段类型：$value'),
    );
  }
}

class SourceFieldOption {
  const SourceFieldOption({required this.value, required this.label});

  factory SourceFieldOption.parse(Object? value) {
    if (value is! Map) throw const FormatException('字段选项格式不正确');
    return SourceFieldOption(
      value: value['value'],
      label: LocalizedSourceName.parse(value['label'], field: 'label'),
    );
  }

  final Object? value;
  final LocalizedSourceName label;

  Map<String, Object?> toJson() => {'value': value, 'label': label.toJson()};
}

/// One host-rendered form field used by settings, authentication, course
/// resolution and extension actions.
class SourceField {
  SourceField({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.required = false,
    this.minimum,
    this.maximum,
    this.options = const [],
    this.help,
  }) {
    if (key.trim().isEmpty) throw const FormatException('字段 key 缺失');
  }

  factory SourceField.parse(Object? value) {
    if (value is! Map) throw const FormatException('字段声明格式不正确');
    final key = value['key'];
    final type = SourceFieldType.parse(value['type']);
    return SourceField(
      key: key is String ? key : throw const FormatException('字段 key 缺失'),
      label: LocalizedSourceName.parse(value['label'], field: 'label'),
      type: type,
      defaultValue: value['default'],
      required: value['required'] == true,
      minimum: _nullableNumber(value['minimum']),
      maximum: _nullableNumber(value['maximum']),
      options: [
        for (final option in _objects(value['options'], 'options'))
          SourceFieldOption.parse(option),
      ],
      help: value['help'] == null
          ? null
          : LocalizedSourceName.parse(value['help'], field: 'help'),
    );
  }

  final String key;
  final LocalizedSourceName label;
  final SourceFieldType type;
  final Object? defaultValue;
  final bool required;
  final num? minimum;
  final num? maximum;
  final List<SourceFieldOption> options;
  final LocalizedSourceName? help;

  Object? validate(Object? value) {
    if (value == null) {
      if (required) throw FormatException('$key 为必填项');
      return null;
    }
    switch (type) {
      case SourceFieldType.text ||
          SourceFieldType.multiline ||
          SourceFieldType.secret ||
          SourceFieldType.url ||
          SourceFieldType.course ||
          SourceFieldType.term ||
          SourceFieldType.date ||
          SourceFieldType.time:
        if (value is! String) throw FormatException('$key 应为文本');
        if (type == SourceFieldType.url) {
          final url = Uri.tryParse(value);
          if (url == null || url.scheme != 'https') {
            throw FormatException('$key 应为 HTTPS 地址');
          }
        }
      case SourceFieldType.integer:
        if (value is! int) throw FormatException('$key 应为整数');
        _checkRange(value);
      case SourceFieldType.number:
        if (value is! num || !value.isFinite) {
          throw FormatException('$key 应为有限数值');
        }
        _checkRange(value);
      case SourceFieldType.toggle:
        if (value is! bool) throw FormatException('$key 应为开关值');
      case SourceFieldType.choice:
        if (!options.any((option) => option.value == value)) {
          throw FormatException('$key 的选项无效');
        }
      case SourceFieldType.multiChoice:
        if (value is! List ||
            !value.every(
              (item) => options.any((option) => option.value == item),
            )) {
          throw FormatException('$key 的选项无效');
        }
      case SourceFieldType.rows:
        if (value is! List) throw FormatException('$key 应为列表');
    }
    return value;
  }

  void _checkRange(num value) {
    if (minimum case final minimum? when value < minimum) {
      throw FormatException('$key 不能小于 $minimum');
    }
    if (maximum case final maximum? when value > maximum) {
      throw FormatException('$key 不能大于 $maximum');
    }
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label.toJson(),
    'type': type.wireName,
    if (defaultValue != null) 'default': defaultValue,
    if (required) 'required': true,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (options.isNotEmpty)
      'options': [for (final option in options) option.toJson()],
    if (help case final help?) 'help': help.toJson(),
  };
}

enum SourceActionLocation {
  source('source'),
  course('course'),
  selectedCourses('selectedCourses'),
  agendaEntry('agendaEntry'),
  selectedAgenda('selectedAgenda'),
  tools('tools');

  const SourceActionLocation(this.wireName);

  final String wireName;

  static SourceActionLocation parse(Object? value) => values.firstWhere(
    (location) => location.wireName == value,
    orElse: () => throw FormatException('未知的动作位置：$value'),
  );
}

enum SourceAuthMode {
  none('none'),
  inherit('inherit'),
  browser('browser'),
  script('script');

  const SourceAuthMode(this.wireName);

  final String wireName;

  static SourceAuthMode parse(Object? value) => values.firstWhere(
    (mode) => mode.wireName == value,
    orElse: () => throw FormatException('未知的认证方式：$value'),
  );
}

class SourceAction {
  SourceAction({
    required this.id,
    required this.name,
    required this.location,
    required this.entry,
    this.resources = const {},
    this.inputs = const [],
  }) {
    if (id.trim().isEmpty || entry.trim().isEmpty) {
      throw const FormatException('动作 id 或入口缺失');
    }
  }

  factory SourceAction.parse(Object? value) {
    if (value is! Map) throw const FormatException('动作声明格式不正确');
    final id = value['id'];
    final entry = value['entry'];
    if (id is! String || entry is! String) {
      throw const FormatException('动作 id 或入口缺失');
    }
    return SourceAction(
      id: id,
      name: LocalizedSourceName.parse(value['name'], field: 'name'),
      location: SourceActionLocation.parse(value['location']),
      entry: entry,
      resources: {
        for (final resource in _objects(value['resources'], 'resources'))
          SourceResource.parse(resource),
      },
      inputs: [
        for (final field in _objects(value['inputs'], 'inputs'))
          SourceField.parse(field),
      ],
    );
  }

  final String id;
  final LocalizedSourceName name;
  final SourceActionLocation location;
  final String entry;
  final Set<SourceResource> resources;
  final List<SourceField> inputs;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name.toJson(),
    'location': location.wireName,
    'entry': entry,
    if (resources.isNotEmpty)
      'resources': [for (final resource in resources) resource.wireName],
    if (inputs.isNotEmpty)
      'inputs': [for (final field in inputs) field.toJson()],
  };
}

/// A source implementation declaration. Built-in Dart sources use the same
/// shape as sources supplied by an extension package.
class SourceDefinition {
  SourceDefinition({
    required this.id,
    required this.packageId,
    required this.sourceId,
    required this.name,
    this.version = '1.0.0',
    this.apiVersion = 1,
    this.extendsId,
    this.baseVersion,
    this.entry,
    this.operations = const {},
    SourcePermissions? permissions,
    this.auth = SourceAuthMode.none,
    this.settings = const [],
    this.actions = const [],
    this.courseInput = const [],
    this.inputResources = const {},
    this.builtin = false,
  }) {
    if (id.trim().isEmpty ||
        packageId.trim().isEmpty ||
        sourceId.trim().isEmpty) {
      throw const FormatException('来源定义缺少编号');
    }
    this.permissions = permissions ?? SourcePermissions();
  }

  final String id;
  final String packageId;
  final String sourceId;
  final LocalizedSourceName name;
  final String version;
  final int apiVersion;
  final String? extendsId;
  final String? baseVersion;
  final String? entry;
  final Set<SourceOperation> operations;
  late final SourcePermissions permissions;
  final SourceAuthMode auth;
  final List<SourceField> settings;
  final List<SourceAction> actions;
  final List<SourceField> courseInput;
  final Set<SourceResource> inputResources;
  final bool builtin;

  bool supports(SourceOperation operation) => operations.contains(operation);

  bool supportsResource(SourceResource resource) =>
      operations.any((operation) => operation.resultResource == resource);

  SourceDefinition effectiveFrom(SourceDefinition base) {
    final settingsByKey = {
      for (final field in base.settings) field.key: field,
      for (final field in settings) field.key: field,
    };
    final actionsById = {
      for (final action in base.actions) action.id: action,
      for (final action in actions) action.id: action,
    };
    return SourceDefinition(
      id: id,
      packageId: packageId,
      sourceId: sourceId,
      name: name,
      version: version,
      apiVersion: apiVersion,
      extendsId: extendsId,
      baseVersion: baseVersion,
      entry: entry,
      operations: {...base.operations, ...operations},
      permissions: permissions.isEmpty
          ? base.permissions
          : permissions.intersect(base.permissions),
      auth: auth == SourceAuthMode.none ? base.auth : auth,
      settings: settingsByKey.values.toList(),
      actions: actionsById.values.toList(),
      courseInput: courseInput.isEmpty ? base.courseInput : courseInput,
      inputResources: {...base.inputResources, ...inputResources},
      builtin: builtin,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'packageId': packageId,
    'sourceId': sourceId,
    'name': name.toJson(),
    'version': version,
    'apiVersion': apiVersion,
    if (extendsId != null) 'extends': extendsId,
    if (baseVersion != null) 'baseVersion': baseVersion,
    if (entry != null) 'entry': entry,
    'operations': [for (final operation in operations) operation.wireName],
    'permissions': permissions.toJson(),
    if (auth != SourceAuthMode.none) 'auth': auth.wireName,
    if (settings.isNotEmpty)
      'settings': [for (final field in settings) field.toJson()],
    if (actions.isNotEmpty)
      'actions': [for (final action in actions) action.toJson()],
    if (courseInput.isNotEmpty)
      'courseInput': [for (final field in courseInput) field.toJson()],
    if (inputResources.isNotEmpty)
      'inputs': [for (final resource in inputResources) resource.wireName],
    if (builtin) 'builtin': true,
  };
}

extension SourceOperationResources on SourceOperation {
  SourceResource? get resultResource => switch (this) {
    SourceOperation.coursesList ||
    SourceOperation.coursesResolve => SourceResource.course,
    SourceOperation.timetableRead => SourceResource.timetable,
    SourceOperation.deadlinesRead ||
    SourceOperation.deadlinesReadAccount => SourceResource.deadline,
    SourceOperation.examsRead => SourceResource.exam,
    SourceOperation.gradesRead => SourceResource.grade,
    SourceOperation.studyPlanRead => SourceResource.studyPlan,
    SourceOperation.classroomsDirectory ||
    SourceOperation.classroomsOccupancy => SourceResource.classroom,
    SourceOperation.agendaRead ||
    SourceOperation.authCheck ||
    SourceOperation.authLogin ||
    SourceOperation.authLogout ||
    SourceOperation.termsList ||
    SourceOperation.termsRead => null,
  };
}

class SourceInstance {
  SourceInstance({
    required this.id,
    required this.definitionId,
    this.accountId,
    this.implementationId,
    this.settings = const {},
    this.enabled = true,
    this.createdAt,
  }) {
    if (id.trim().isEmpty || definitionId.trim().isEmpty) {
      throw const FormatException('来源实例缺少编号');
    }
  }

  factory SourceInstance.fromJson(Map<String, dynamic> json) => SourceInstance(
    id: _stringField(json, 'id'),
    definitionId: _stringField(json, 'definitionId'),
    accountId: _stringFieldOrNull(json, 'accountId'),
    implementationId: _stringFieldOrNull(json, 'implementationId'),
    settings: json['settings'] is Map
        ? Map<String, dynamic>.from(json['settings'] as Map)
        : const {},
    enabled: json['enabled'] != false,
    createdAt: json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
  );

  final String id;
  final String definitionId;
  final String? accountId;

  /// The selected extension source that replaces or extends [definitionId].
  final String? implementationId;
  final Map<String, dynamic> settings;
  final bool enabled;
  final DateTime? createdAt;

  SourceInstance copyWith({
    String? definitionId,
    Object? accountId = _unset,
    Object? implementationId = _unset,
    Map<String, dynamic>? settings,
    bool? enabled,
  }) => SourceInstance(
    id: id,
    definitionId: definitionId ?? this.definitionId,
    accountId: identical(accountId, _unset)
        ? this.accountId
        : accountId as String?,
    implementationId: identical(implementationId, _unset)
        ? this.implementationId
        : implementationId as String?,
    settings: settings ?? this.settings,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'definitionId': definitionId,
    if (accountId != null) 'accountId': accountId,
    if (implementationId != null) 'implementationId': implementationId,
    if (settings.isNotEmpty) 'settings': settings,
    'enabled': enabled,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

enum SourceAccountStatus { signedOut, signedIn, expired, verificationRequired }

/// Source-reported completion. `unknown` means the platform did not provide
/// enough information; the host keeps the last known source value or the
/// user's explicit override.
enum CompletionState { unknown, pending, done }

/// Explicit local completion choice. A null override follows the source.
enum CompletionOverride { done, pending }

class SourceAccount {
  SourceAccount({
    required this.id,
    required this.service,
    this.identity,
    this.displayName,
    this.status = SourceAccountStatus.signedOut,
  }) {
    if (id.trim().isEmpty || service.trim().isEmpty) {
      throw const FormatException('账号缺少编号或服务名');
    }
  }

  factory SourceAccount.fromJson(Map<String, dynamic> json) => SourceAccount(
    id: _stringField(json, 'id'),
    service: _stringField(json, 'service'),
    identity: _stringFieldOrNull(json, 'identity'),
    displayName: _stringFieldOrNull(json, 'displayName'),
    status: SourceAccountStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => throw const FormatException('账号状态格式不正确'),
    ),
  );

  final String id;
  final String service;
  final String? identity;
  final String? displayName;
  final SourceAccountStatus status;

  SourceAccount copyWith({
    Object? identity = _unset,
    Object? displayName = _unset,
    SourceAccountStatus? status,
  }) => SourceAccount(
    id: id,
    service: service,
    identity: identical(identity, _unset) ? this.identity : identity as String?,
    displayName: identical(displayName, _unset)
        ? this.displayName
        : displayName as String?,
    status: status ?? this.status,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'service': service,
    if (identity != null) 'identity': identity,
    if (displayName != null) 'displayName': displayName,
    'status': status.name,
  };
}

/// Stable identity for a remote record. The triple
/// `(sourceInstanceId, resource, remoteId)` is the merge key.
class RecordOrigin {
  RecordOrigin({
    required this.sourceInstanceId,
    required this.resource,
    required this.remoteId,
    this.scope,
  }) {
    if (sourceInstanceId.trim().isEmpty || remoteId.trim().isEmpty) {
      throw const FormatException('记录来源缺少实例或远端编号');
    }
  }

  factory RecordOrigin.fromJson(Map<String, dynamic> json) => RecordOrigin(
    sourceInstanceId: _stringField(json, 'sourceInstanceId'),
    resource: SourceResource.parse(json['resource']),
    remoteId: _stringField(json, 'remoteId'),
    scope: _stringFieldOrNull(json, 'scope'),
  );

  final String sourceInstanceId;
  final SourceResource resource;
  final String remoteId;
  final String? scope;

  String get key => jsonEncode([sourceInstanceId, resource.wireName, remoteId]);

  RecordOrigin copyWith({
    String? sourceInstanceId,
    SourceResource? resource,
    String? remoteId,
    Object? scope = _unset,
  }) => RecordOrigin(
    sourceInstanceId: sourceInstanceId ?? this.sourceInstanceId,
    resource: resource ?? this.resource,
    remoteId: remoteId ?? this.remoteId,
    scope: identical(scope, _unset) ? this.scope : scope as String?,
  );

  Map<String, Object?> toJson() => {
    'sourceInstanceId': sourceInstanceId,
    'resource': resource.wireName,
    'remoteId': remoteId,
    if (scope != null) 'scope': scope,
  };
}

const _unset = Object();

String _normalizeNetworkOrigin(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.path.isNotEmpty && uri.path != '/' ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw FormatException('网络授权必须是精确的 HTTPS 来源：$value');
  }
  return Uri(scheme: 'https', host: uri.host).toString();
}

Iterable<Object?> _objects(Object? value, String field) {
  if (value == null) return const [];
  if (value is List) return value;
  throw FormatException('$field 格式不正确');
}

List<String> _strings(Object? value, String field) {
  if (value == null) return const [];
  if (value is List && value.every((item) => item is String)) {
    return [for (final item in value) item as String];
  }
  throw FormatException('$field 格式不正确');
}

Map<String, Object?> _map(Object? value, String field) {
  if (value == null) return const {};
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$field 格式不正确');
}

num? _nullableNumber(Object? value) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value;
  throw const FormatException('数值约束格式不正确');
}

String _stringField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key 缺失');
}

String? _stringFieldOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key 格式不正确');
}
