import 'source.dart';

/// Definition ids are persisted in record origins. Do not rename them.
abstract final class BuiltinSources {
  static const school = 'builtin.bit.school';
  static const lexue = 'builtin.bit.lexue';
  static const eclass = 'builtin.bit.eclass';
  static const mooc = 'builtin.icourse163.mooc';
  static const physicsLab = 'builtin.bit.physics-lab';

  static final List<SourceDefinition> all = [
    SourceDefinition(
      id: school,
      packageId: 'builtin',
      sourceId: 'school',
      name: const LocalizedSourceName({'zh': '教学中心', 'en': 'Teaching Center'}),
      permissions: SourcePermissions(
        networkHosts: const {
          'https://jxzxehall.bit.edu.cn',
          'https://jxzxehallapp.bit.edu.cn',
          'https://jwms.bit.edu.cn',
          'https://webvpn.bit.edu.cn',
        },
        sessionServices: const {'bit.school'},
      ),
      builtin: true,
    ),
    SourceDefinition(
      id: lexue,
      packageId: 'builtin',
      sourceId: 'lexue',
      name: const LocalizedSourceName({'zh': '乐学', 'en': 'Lexue'}),
      operations: const {
        SourceOperation.coursesList,
        SourceOperation.coursesResolve,
        SourceOperation.deadlinesRead,
        SourceOperation.deadlinesReadAccount,
      },
      permissions: SourcePermissions(
        networkHosts: const {'https://lexue.bit.edu.cn'},
        sessionServices: const {'bit.lexue'},
      ),
      builtin: true,
    ),
    SourceDefinition(
      id: eclass,
      packageId: 'builtin',
      sourceId: 'eclass',
      name: const LocalizedSourceName({'zh': '新延河课堂', 'en': 'Eclass'}),
      operations: const {
        SourceOperation.coursesList,
        SourceOperation.coursesResolve,
        SourceOperation.deadlinesRead,
      },
      permissions: SourcePermissions(
        networkHosts: const {'https://zy-eclass.bit.edu.cn'},
        sessionServices: const {'bit.eclass'},
      ),
      builtin: true,
    ),
    SourceDefinition(
      id: mooc,
      packageId: 'builtin',
      sourceId: 'mooc',
      name: const LocalizedSourceName({'zh': '中国大学 MOOC', 'en': 'ICourse163'}),
      operations: const {
        SourceOperation.coursesList,
        SourceOperation.coursesResolve,
        SourceOperation.deadlinesRead,
      },
      permissions: SourcePermissions(
        networkHosts: const {'https://www.icourse163.org'},
        sessionServices: const {'icourse163'},
      ),
      builtin: true,
    ),
    SourceDefinition(
      id: physicsLab,
      packageId: 'builtin',
      sourceId: 'physics-lab',
      name: const LocalizedSourceName({
        'zh': '物理实验报告',
        'en': 'Physics lab reports',
      }),
      permissions: SourcePermissions(
        dataRead: const {SourceResource.timetable},
      ),
      inputResources: const {SourceResource.timetable},
      builtin: true,
    ),
  ];

  static final Map<String, SourceDefinition> byId = {
    for (final definition in all) definition.id: definition,
  };

  static const Map<String, String> _legacyInstances = {
    'lexue': lexue,
    'eclass': eclass,
    'mooc': mooc,
    'physics-lab': physicsLab,
    'school': school,
  };

  static String? definitionForLegacySource(String? source) =>
      _legacyInstances[source];

  static String instanceIdForDefinition(String definitionId) =>
      'instance:$definitionId';
}

class SourceCatalog {
  SourceCatalog(Iterable<SourceDefinition> definitions)
    : _definitions = {
        for (final definition in definitions) definition.id: definition,
      };

  factory SourceCatalog.builtin() => SourceCatalog(BuiltinSources.all);

  final Map<String, SourceDefinition> _definitions;

  Iterable<SourceDefinition> get definitions => _definitions.values;

  SourceDefinition? operator [](String id) => _definitions[id];

  /// Resolves an inheritance chain from the requested source to its base.
  /// Built-in packages and user fixes may form one chain, so the catalog
  /// applies every declaration in order instead of limiting inheritance to a
  /// single level.
  SourceDefinition require(String id) {
    final chain = <SourceDefinition>[];
    final seen = <String>{};
    var definition = _definitions[id];
    if (definition == null) {
      throw FormatException('未知的来源定义：$id');
    }
    while (true) {
      if (!seen.add(definition!.id)) {
        throw FormatException('来源继承出现循环：$id');
      }
      chain.add(definition);
      final baseId = definition.extendsId;
      if (baseId == null) break;
      definition = _definitions[baseId];
      if (definition == null) {
        throw FormatException('来源 ${chain.last.id} 继承的定义不存在：$baseId');
      }
    }
    var effective = chain.removeLast();
    for (final derived in chain.reversed) {
      effective = derived.effectiveFrom(effective);
    }
    return effective;
  }

  SourceCatalog withDefinitions(Iterable<SourceDefinition> definitions) =>
      SourceCatalog([..._definitions.values, ...definitions]);
}
