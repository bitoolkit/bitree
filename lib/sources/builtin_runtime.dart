import '../agenda/deadline_source.dart';
import '../agenda/model.dart';
import '../core/time.dart';
import '../mooc/controller.dart';
import '../school/controller.dart';
import 'builtin.dart';
import 'course_selection.dart';
import 'legacy.dart';
import 'runtime.dart';
import 'source.dart';

/// Executes built-in Dart source implementations through [SourceRuntime].
class BuiltinSourceRuntime implements SourceRuntime {
  BuiltinSourceRuntime({required this.school, required this.mooc});

  final SchoolController school;
  final MoocController mooc;

  SourceRuntime? runtimeFor(SourceDefinition definition) =>
      _deadlineSource(definition.id) == null ? null : this;

  @override
  Future<Object?> call(
    SourceDefinition definition,
    SourceOperation operation,
    Map<String, Object?> query,
    SourceOperationContext context,
  ) async {
    if (context.isCancelled?.call() ?? false) {
      throw const SourceCancelled();
    }
    final source = _deadlineSource(definition.id);
    if (source == null) {
      throw SourceError(
        'unknown_operation',
        '内置来源 ${definition.id} 没有实现 ${operation.wireName}。',
      );
    }
    final result = switch (operation) {
      SourceOperation.coursesList => [
        for (final course in await _courses(source)) course.toJson(),
      ],
      SourceOperation.coursesResolve => await _resolve(source, query),
      SourceOperation.deadlinesRead => await _deadlines(source, query),
      _ => throw SourceError(
        'unknown_operation',
        '内置来源 ${definition.id} 没有实现 ${operation.wireName}。',
      ),
    };
    if (context.isCancelled?.call() ?? false) {
      throw const SourceCancelled();
    }
    return result;
  }

  Future<List<PlatformCourse>> _courses(DeadlineSource source) async {
    if (source == DeadlineSource.mooc) {
      return mooc.discoverCourses();
    }
    final courses = await school.discoverCourses(source);
    if (courses == null) {
      throw SourceError(
        'source_error',
        school.error ?? '无法读取 ${_sourceName(source)} 课程。',
      );
    }
    return courses;
  }

  Future<Map<String, Object?>> _resolve(
    DeadlineSource source,
    Map<String, Object?> query,
  ) async {
    final raw = query['input'] ?? query['remoteId'] ?? query['url'];
    if (raw is! String || raw.trim().isEmpty) {
      throw const SourceError('invalid_argument', '请输入课程链接或编号。');
    }
    final input = raw.trim();
    final remoteId = _remoteId(source, input);
    final courses = await _courses(source);
    for (final course in courses) {
      if (course.remoteId == remoteId || course.url?.toString() == input) {
        return course.toJson();
      }
    }
    throw SourceError(
      'course_not_found',
      '${_sourceName(source)} 中找不到课程 $input。',
    );
  }

  Future<List<Map<String, Object?>>> _deadlines(
    DeadlineSource source,
    Map<String, Object?> query,
  ) async {
    final raw = query['course'];
    if (raw is! Map) {
      throw const SourceError('invalid_argument', '缺少平台课程。');
    }
    final course = PlatformCourse.fromJson(Map<String, dynamic>.from(raw));
    final List<AgendaEntry>? entries;
    if (source == DeadlineSource.mooc) {
      entries = await mooc.readCourseDeadlines(course);
    } else {
      entries = await school.readCourseDeadlines(source, course: course);
    }
    if (entries == null) {
      throw SourceError(
        'source_error',
        school.error ?? '无法读取 ${_sourceName(source)} 课程 DDL。',
      );
    }
    return [for (final entry in entries) _deadline(entry)];
  }

  String? _remoteId(DeadlineSource source, String input) {
    final url = Uri.tryParse(input);
    if (url == null) return input;
    if (source == DeadlineSource.lexue) {
      final id = url.queryParameters['id'];
      if (id != null && id.isNotEmpty) return id;
    }
    final segments = url.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? input : segments.last;
  }

  Map<String, Object?> _deadline(AgendaEntry entry) {
    final remoteId =
        entry.origin?.remoteId ??
        LegacyRecordIds.deadlineRemoteId(
          id: entry.id,
          source: entry.source?.name,
          url: entry.url,
        );
    return {
      'remoteId': remoteId,
      'title': entry.title,
      'course': entry.course,
      'notes': entry.notes,
      'location': entry.location,
      if (entry.url != null) 'url': entry.url.toString(),
      'completion': entry.done ? 'done' : 'pending',
      if (entry.allDay)
        'dueDate': dateText(entry.startsAt)
      else
        'dueAt': _wireTime(entry.startsAt),
    };
  }

  String _wireTime(DateTime value) {
    final campus = DateTime.utc(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return campus.subtract(const Duration(hours: 8)).toIso8601String();
  }

  DeadlineSource? _deadlineSource(String definitionId) =>
      switch (definitionId) {
        BuiltinSources.lexue => DeadlineSource.lexue,
        BuiltinSources.eclass => DeadlineSource.eclass,
        BuiltinSources.mooc => DeadlineSource.mooc,
        _ => null,
      };

  String _sourceName(DeadlineSource source) => switch (source) {
    DeadlineSource.lexue => '乐学',
    DeadlineSource.eclass => '新延河课堂',
    DeadlineSource.mooc => '中国大学 MOOC',
  };
}
