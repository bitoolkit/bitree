import '../agenda/controller.dart';
import '../core/async/cancelable_request.dart';
import 'host.dart';
import 'registry.dart';
import 'runtime.dart';
import 'source.dart';

class SourceSyncFailure {
  const SourceSyncFailure(this.course, this.error);

  final String course;
  final Object error;
}

class SourceSyncResult {
  const SourceSyncResult({
    required this.courseCount,
    required this.deadlineCount,
    this.failures = const [],
  });

  final int courseCount;
  final int deadlineCount;
  final List<SourceSyncFailure> failures;

  bool get complete => failures.isEmpty;
}

/// Discovers the current platform course list, keeps the user's selection and
/// reads deadlines for each selected course into the agenda.
class SourceSync {
  SourceSync({required this.sources, required this.host, required this.agenda});

  final SourceRegistry sources;
  final SourceHost host;
  final AgendaController agenda;

  Future<SourceSyncResult> synchronize(
    SourceInstance instance, {
    String? term,
    bool Function()? isCancelled,
  }) async {
    try {
      return await _synchronize(instance, term: term, isCancelled: isCancelled);
    } on SourceCancelled {
      throw const RequestCancelled();
    }
  }

  Future<SourceSyncResult> _synchronize(
    SourceInstance instance, {
    String? term,
    bool Function()? isCancelled,
  }) async {
    void checkActive() {
      if (isCancelled?.call() ?? false) {
        throw const RequestCancelled();
      }
    }

    final context = SourceOperationContext(
      config: instance.settings,
      isCancelled: isCancelled,
    );
    final discovered = await host.courses(instance, context: context);
    checkActive();
    await sources.mergeDiscoveredCourses(instance.id, discovered.items);
    final definition = sources.definitionFor(instance);
    final selected = sources.selection(instance.id).selectedCourses;
    if (!definition.supports(SourceOperation.deadlinesRead)) {
      return SourceSyncResult(courseCount: selected.length, deadlineCount: 0);
    }

    final failures = <SourceSyncFailure>[];
    var deadlineCount = 0;
    for (final course in selected) {
      checkActive();
      try {
        final result = await host.deadlines(
          instance,
          query: {'course': course.toJson(), 'termId': ?term},
          context: context,
        );
        final saved = await agenda.mergeDeadlines(
          result.items,
          checkActive: checkActive,
          sourceInstanceId: instance.id,
          scope: term,
        );
        if (!saved) {
          failures.add(SourceSyncFailure(course.name, '日程保存失败。'));
        } else {
          deadlineCount += result.items.length;
        }
      } on RequestCancelled {
        rethrow;
      } on SourceCancelled {
        rethrow;
      } catch (error) {
        failures.add(SourceSyncFailure(course.name, error));
      }
    }
    return SourceSyncResult(
      courseCount: selected.length,
      deadlineCount: deadlineCount,
      failures: failures,
    );
  }
}
