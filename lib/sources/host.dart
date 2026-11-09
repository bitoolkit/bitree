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
  }) : httpTransport = httpTransport ?? SourceHttpTransport();

  final SourceRegistry registry;
  final SourceRuntimeResolver runtimeFor;
  final SourceHttpTransport httpTransport;

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
    final runtime = await runtimeFor(definition);
    if (runtime == null) {
      throw SourceError('unknown_operation', '来源 ${definition.id} 没有可用的运行时。');
    }
    final baseContext =
        (context ?? SourceOperationContext(config: instance.settings))
            .withSource({
              'id': definition.id,
              'baseId': instance.definitionId,
              'instanceId': instance.id,
              'accountId': ?instance.accountId,
            });
    final effectiveContext = baseContext.httpRequest != null
        ? baseContext
        : baseContext.withHttpRequest((request) async {
            if (baseContext.isCancelled?.call() ?? false) {
              throw const SourceCancelled();
            }
            try {
              final result = await httpTransport.request(
                instance.id,
                definition.permissions,
                request,
                isCancelled: baseContext.isCancelled,
              );
              if (baseContext.isCancelled?.call() ?? false) {
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
