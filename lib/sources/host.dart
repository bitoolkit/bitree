import '../agenda/model.dart';
import '../schedule/model.dart';
import 'course_selection.dart';
import 'registry.dart';
import 'results.dart';
import 'runtime.dart';
import 'source.dart';
import 'transport.dart';

/// Owns the boundary between a source instance and its runtime.
/// Runtime state is created for each call; the host only supplies instance
/// scope, permissions and result validation.
class SourceHost {
  SourceHost({
    required this.registry,
    required this.runtimeFor,
    SourceHttpTransport? httpTransport,
    this.secrets,
    this.data = const {},
  }) : httpTransport = httpTransport ?? SourceHttpTransport();

  final SourceRegistry registry;
  final SourceRuntimeResolver runtimeFor;
  final SourceHttpTransport httpTransport;
  final SourceSecretStore? secrets;
  final Map<String, Object? Function(Map<String, Object?> query)> data;

  Future<SourceReadResult<PlatformCourse>> courses(
    SourceInstance instance, {
    Map<String, Object?> query = const {},
    SourceOperationContext? context,
  }) => _run(
    instance,
    SourceOperation.coursesList,
    query,
    context,
    (reader, value) => reader.courses(value),
  );

  Future<PlatformCourse> resolveCourse(
    SourceInstance instance, {
    required Map<String, Object?> query,
    SourceOperationContext? context,
  }) async {
    final output = await _call(
      instance,
      SourceOperation.coursesResolve,
      query,
      context,
    );
    final reader = _reader(instance, query);
    return reader.course(output);
  }

  Future<SourceReadResult<AgendaEntry>> deadlines(
    SourceInstance instance, {
    required Map<String, Object?> query,
    SourceOperationContext? context,
  }) => _run(
    instance,
    SourceOperation.deadlinesRead,
    query,
    context,
    (reader, value) =>
        reader.agenda(value, operation: SourceOperation.deadlinesRead),
  );

  Future<SourceReadResult<AgendaEntry>> accountDeadlines(
    SourceInstance instance, {
    required Map<String, Object?> query,
    SourceOperationContext? context,
  }) => _run(
    instance,
    SourceOperation.deadlinesReadAccount,
    query,
    context,
    (reader, value) =>
        reader.agenda(value, operation: SourceOperation.deadlinesReadAccount),
  );

  Future<SourceReadResult<AgendaEntry>> agenda(
    SourceInstance instance, {
    Map<String, Object?> query = const {},
    SourceOperationContext? context,
  }) => _run(
    instance,
    SourceOperation.agendaRead,
    query,
    context,
    (reader, value) =>
        reader.agenda(value, operation: SourceOperation.agendaRead),
  );

  Future<SourceReadResult<Course>> timetable(
    SourceInstance instance, {
    required Map<String, Object?> query,
    SourceOperationContext? context,
  }) => _run(
    instance,
    SourceOperation.timetableRead,
    query,
    context,
    (reader, value) => reader.timetable(value),
  );

  Future<T> _run<T>(
    SourceInstance instance,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext? context,
    T Function(SourceResultReader reader, Object? value) parse,
  ) async {
    final output = await _call(instance, operation, query, context);
    return parse(_reader(instance, query), output);
  }

  Future<Object?> _call(
    SourceInstance instance,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext? context,
  ) async {
    final definition = registry.definitionFor(instance);
    if (!definition.supports(operation)) {
      throw SourceError(
        'unknown_operation',
        '来源 ${definition.id} 未声明 ${operation.wireName}。',
      );
    }
    if (!instance.enabled) {
      throw SourceError('source_disabled', '来源 ${definition.id} 已停用。');
    }
    return _invoke(
      instance,
      definition,
      operation,
      query,
      context ?? SourceOperationContext(config: instance.settings),
      definition.permissions,
    );
  }

  Future<Object?> _invoke(
    SourceInstance instance,
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
    SourcePermissions permissions,
  ) async {
    final runtime = await runtimeFor(definition);
    if (runtime == null) {
      throw SourceError('unknown_operation', '来源 ${definition.id} 没有可用的运行时。');
    }
    var effectiveContext = context.withSource({
      'id': definition.id,
      'baseId': instance.definitionId,
      'instanceId': instance.id,
      'accountId': ?instance.accountId,
    });
    effectiveContext = effectiveContext.withHostServices(
      secrets: secrets,
      secretNamespace: '${definition.packageId}:${instance.id}',
      sessionCookie: (name, rawUrl) async {
        final url = Uri.tryParse(rawUrl);
        if (url == null) {
          throw const SourceError('invalid_argument', 'Cookie 地址无效。');
        }
        if (context.isCancelled?.call() ?? false) {
          throw const SourceCancelled();
        }
        return httpTransport.cookie(
          instance.id,
          permissions,
          name: name,
          url: url,
          isCancelled: context.isCancelled,
        );
      },
    );
    final dataHandlers = <String, Object? Function(Map<String, Object?> query)>{
      for (final entry in data.entries)
        if (_allowsData(permissions, entry.key)) entry.key: entry.value,
      if (_allowsData(permissions, 'courseLinks'))
        'courseLinks': (query) => [
          for (final link
              in registry.storedSelection(instance.id)?.links ??
                  const <CourseLink>[])
            link.toJson(),
        ],
    };
    if (dataHandlers.isNotEmpty) {
      effectiveContext = effectiveContext.withData(dataHandlers);
    }
    effectiveContext = effectiveContext.httpRequest != null
        ? effectiveContext
        : effectiveContext.withHttpRequest((request) async {
            if (effectiveContext.isCancelled?.call() ?? false) {
              throw const SourceCancelled();
            }
            try {
              final result = await httpTransport.request(
                instance.id,
                permissions,
                request,
                isCancelled: effectiveContext.isCancelled,
              );
              if (effectiveContext.isCancelled?.call() ?? false) {
                throw const SourceCancelled();
              }
              return result;
            } on SourceHttpException catch (failure) {
              if (failure.code == 'cancelled') {
                throw const SourceCancelled();
              }
              throw SourceError(failure.code, failure.message, failure.details);
            }
          });
    final baseId = definition.extendsId;
    if (baseId != null) {
      final baseDefinition = registry.catalog.require(baseId);
      effectiveContext = effectiveContext.withBaseOperationHandler((
        name,
        rawQuery,
      ) async {
        final SourceOperation baseOperation;
        try {
          baseOperation = SourceOperation.parse(name);
        } on FormatException catch (failure) {
          throw SourceError('unknown_operation', failure.message);
        }
        if (!baseDefinition.supports(baseOperation)) {
          throw SourceError(
            'unknown_operation',
            '基础来源 ${baseDefinition.id} 未声明 $name。',
          );
        }
        if (rawQuery != null && rawQuery is! Map) {
          throw const SourceError('invalid_argument', '基础操作参数必须是对象。');
        }
        return _invoke(
          instance,
          baseDefinition,
          baseOperation,
          rawQuery == null
              ? const <String, Object?>{}
              : Map<String, Object?>.from(rawQuery as Map),
          context,
          permissions,
        );
      });
    }
    return runtime.call(definition, operation, query, effectiveContext);
  }

  SourceResultReader _reader(
    SourceInstance instance,
    Map<String, Object?> query,
  ) {
    final definition = registry.definitionFor(instance);
    return SourceResultReader(
      sourceInstanceId: instance.id,
      permissions: definition.permissions,
      definitionId: instance.definitionId,
      term: query['termId'] as String? ?? query['term'] as String?,
    );
  }
}

bool _allowsData(SourcePermissions permissions, String name) {
  final resource = switch (name) {
    'courses' || 'courseOccurrences' || 'courseLinks' => SourceResource.course,
    'agenda' => null,
    'grades' => SourceResource.grade,
    'studyPlan' => SourceResource.studyPlan,
    'classrooms' => SourceResource.classroom,
    _ => null,
  };
  return resource == null
      ? switch (name) {
          'agenda' =>
            permissions.dataRead.contains(SourceResource.deadline) ||
                permissions.dataRead.contains(SourceResource.event) ||
                permissions.dataRead.contains(SourceResource.exam),
          _ => false,
        }
      : permissions.dataRead.contains(resource);
}
