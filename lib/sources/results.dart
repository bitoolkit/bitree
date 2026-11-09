import '../agenda/deadline_source.dart';
import '../agenda/model.dart';
import '../schedule/model.dart';
import 'builtin.dart';
import 'course_selection.dart';
import 'source.dart';

class SourceResultException implements Exception {
  const SourceResultException(this.message, [this.details]);

  final String message;
  final Object? details;

  @override
  String toString() => message;
}

enum SourceReadMode { upsert, replace }

class SourceReadResult<T> {
  const SourceReadResult({
    required this.items,
    this.mode = SourceReadMode.upsert,
    this.removedRemoteIds = const {},
  });

  final List<T> items;
  final SourceReadMode mode;
  final Set<String> removedRemoteIds;
}

/// Converts the public Lua result contract into domain objects and validates
/// the boundary once. A nil or missing collection is a protocol error; an
/// empty collection is a successful read with no records.
class SourceResultReader {
  const SourceResultReader({
    required this.sourceInstanceId,
    required this.permissions,
    this.definitionId,
    this.term,
    this.courseNames = const {},
  });

  final String sourceInstanceId;
  final SourcePermissions permissions;
  final String? definitionId;
  final String? term;
  final Map<String, String> courseNames;

  SourceReadResult<PlatformCourse> courses(Object? value) {
    final rows = _rows(value, 'courses');
    return SourceReadResult(
      items: [for (final row in rows) course(row)],
    );
  }

  PlatformCourse course(Object? value) {
    final row = _map(value, 'course');
    final remoteId = _requiredString(row, 'remoteId');
    final name = _requiredString(row, 'name');
    final url = _optionalUrl(row['url'], 'course.url');
    return PlatformCourse(
      remoteId: remoteId,
      name: name,
      url: url,
      remoteTermId: _optionalString(row['remoteTermId'], 'remoteTermId'),
      params: _optionalMap(row['params'], 'params'),
    );
  }

  SourceReadResult<AgendaEntry> agenda(
    Object? value, {
    required SourceOperation operation,
  }) {
    final result = _collection(value, 'agenda');
    final defaultKind = switch (operation) {
      SourceOperation.deadlinesRead ||
      SourceOperation.deadlinesReadAccount => 'deadline',
      _ => null,
    };
    return SourceReadResult(
      items: [
        for (final row in result.rows)
          _agendaEntry(
            row,
            operation: operation,
            defaultKind: defaultKind,
          ),
      ],
      mode: result.mode,
      removedRemoteIds: result.removedRemoteIds,
    );
  }

  SourceReadResult<Course> timetable(Object? value) {
    final result = _collection(value, 'timetable');
    return SourceReadResult(
      items: [for (final row in result.rows) _course(row)],
      mode: result.mode,
      removedRemoteIds: result.removedRemoteIds,
    );
  }

  AgendaEntry _agendaEntry(
    Map<String, Object?> row, {
    required SourceOperation operation,
    required String? defaultKind,
  }) {
    final remoteId = _requiredString(row, 'remoteId');
    final title = _requiredString(row, 'title');
    final kindName = _optionalString(row['kind'], 'kind') ?? defaultKind;
    final kind = switch (kindName) {
      'deadline' => AgendaKind.deadline,
      'event' => AgendaKind.event,
      'exam' => AgendaKind.exam,
      _ => throw SourceResultException('无效的日程类型：$kindName'),
    };
    final url = _optionalUrl(row['url'], 'url');
    final course = _courseLabel(row);
    final completion = _completion(row);
    final origin = RecordOrigin(
      sourceInstanceId: sourceInstanceId,
      resource: switch (kind) {
        AgendaKind.deadline => SourceResource.deadline,
        AgendaKind.event => SourceResource.event,
        AgendaKind.exam => SourceResource.exam,
      },
      remoteId: remoteId,
      scope: term,
    );

    if (kind == AgendaKind.deadline) {
      final dueDate = row['dueDate'];
      final dueAt = row['dueAt'];
      final allDay = dueDate != null;
      final startsAt = allDay
          ? _date(dueDate, 'dueDate')
          : _time(dueAt ?? row['startsAt'], 'dueAt');
      return AgendaEntry(
        id: _recordId(origin),
        title: title,
        kind: kind,
        startsAt: startsAt,
        allDay: allDay,
        location: _optionalString(row['location'], 'location') ?? '',
        notes: _optionalString(row['notes'], 'notes') ?? '',
        course: course,
        url: url,
        term: term,
        local: false,
        source: _deadlineSource(),
        origin: origin,
        done: completion == CompletionState.done,
        lastSourceCompletion: completion,
      );
    }

    final allDay = row['allDay'] == true;
    final startsAt = _time(row['startsAt'], 'startsAt');
    final endsAt = _time(row['endsAt'], 'endsAt');
    if (!endsAt.isAfter(startsAt)) {
      throw const SourceResultException('日程结束时间必须晚于开始时间');
    }
    return AgendaEntry(
      id: _recordId(origin),
      title: title,
      kind: kind,
      startsAt: startsAt,
      endsAt: endsAt,
      allDay: allDay,
      location: _optionalString(row['location'], 'location') ?? '',
      notes: _optionalString(row['notes'], 'notes') ?? '',
      course: course,
      url: url,
      term: term,
      local: false,
      source: _deadlineSource(),
      origin: origin,
      done: completion == CompletionState.done,
      lastSourceCompletion: completion,
    );
  }

  Course _course(Map<String, Object?> row) {
    final remoteId = _requiredString(row, 'remoteId');
    final name = _requiredString(row, 'name');
    final origin = RecordOrigin(
      sourceInstanceId: sourceInstanceId,
      resource: SourceResource.timetable,
      remoteId: remoteId,
      scope: term,
    );
    final weeksValue = row['weeks'];
    final weeks = weeksValue == null
        ? <int>[]
        : _intList(weeksValue, 'weeks');
    final weekday = _optionalInt(row['weekday'], 'weekday');
    final startSection = _optionalInt(row['startSection'], 'startSection');
    final endSection = _optionalInt(row['endSection'], 'endSection');
    return Course(
      id: _recordId(origin),
      name: name,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      weeks: weeks,
      teacher: _optionalString(row['teacher'], 'teacher') ?? '',
      room: _optionalString(row['room'], 'room') ?? '',
      campus: _optionalString(row['campus'], 'campus') ?? '',
      number: _optionalString(row['number'], 'number') ?? '',
      description: _optionalString(row['description'], 'description') ?? '',
      origin: origin,
    );
  }

  CompletionState _completion(Map<String, Object?> row) {
    final value = row['completion'];
    if (value == null) return CompletionState.unknown;
    if (value is bool) {
      return value ? CompletionState.done : CompletionState.pending;
    }
    return switch (value) {
      'done' => CompletionState.done,
      'pending' => CompletionState.pending,
      'unknown' => CompletionState.unknown,
      _ => throw SourceResultException('无效的完成状态：$value'),
    };
  }

  String _courseLabel(Map<String, Object?> row) {
    final course = row['course'];
    if (course is Map) {
      final name = course['name'];
      if (name is String && name.trim().isNotEmpty) return name;
      final remoteId = course['remoteId'];
      if (remoteId is String) return courseNames[remoteId] ?? '';
    }
    final text = row['course'];
    if (text is String) return text;
    final ref = row['courseRef'];
    if (ref is String) return courseNames[ref] ?? '';
    if (ref is Map) {
      final remoteId = ref['remoteId'];
      if (remoteId is String) return courseNames[remoteId] ?? '';
    }
    return '';
  }

  DeadlineSource? _deadlineSource() =>
      deadlineSourceForDefinition(definitionId ?? sourceInstanceId);

  String _recordId(RecordOrigin origin) =>
      'source:${origin.sourceInstanceId}:${origin.resource.wireName}:'
      '${origin.remoteId}';

  _Collection _collection(Object? value, String name) {
    if (value is List) {
      return _Collection(rows: _rows(value, name));
    }
    final map = _map(value, name);
    final rows = _rows(map['items'], name);
    final mode = switch (map['mode']) {
      null || 'upsert' => SourceReadMode.upsert,
      'replace' => SourceReadMode.replace,
      _ => throw SourceResultException('$name.mode 只能为 upsert 或 replace'),
    };
    final removed = map['removed'] == null
        ? <String>{}
        : {
            for (final item in _list(map['removed'], '$name.removed'))
              if (item is String)
                item
              else
                throw SourceResultException('$name.removed 必须是文本编号'),
          };
    return _Collection(
      rows: rows,
      mode: mode,
      removedRemoteIds: removed,
    );
  }

  List<Map<String, Object?>> _rows(Object? value, String name) {
    final list = _list(value, name);
    return [for (final row in list) _map(row, '$name[]')];
  }

  List<Object?> _list(Object? value, String name) {
    if (value is! List) {
      throw SourceResultException('$name 必须是数组');
    }
    return value;
  }

  Map<String, Object?> _map(Object? value, String name) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw SourceResultException('$name 必须是 table');
    }
    return Map<String, Object?>.from(value);
  }

  Map<String, dynamic> _optionalMap(Object? value, String name) {
    if (value == null) return const {};
    return Map<String, dynamic>.from(_map(value, name));
  }

  List<int> _intList(Object? value, String name) {
    final list = _list(value, name);
    return [
      for (final item in list)
        if (item is int) item else throw SourceResultException('$name 必须是整数数组'),
    ];
  }

  String _requiredString(Map<String, Object?> row, String name) {
    final value = row[name];
    if (value is String && value.trim().isNotEmpty) return value;
    throw SourceResultException('缺少必填字段 $name');
  }

  String? _optionalString(Object? value, String name) {
    if (value == null) return null;
    if (value is String) return value;
    throw SourceResultException('$name 必须是文本');
  }

  int? _optionalInt(Object? value, String name) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value == value.toInt()) return value.toInt();
    throw SourceResultException('$name 必须是整数');
  }

  Uri? _optionalUrl(Object? value, String name) {
    if (value == null) return null;
    if (value is! String) {
      throw SourceResultException('$name 必须是 HTTPS 地址');
    }
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        !permissions.allows(url)) {
      throw SourceResultException('$name 不属于来源的授权网站');
    }
    return url;
  }

  DateTime _time(Object? value, String name) {
    if (value is! String) {
      throw SourceResultException('缺少必填时间字段 $name');
    }
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw SourceResultException('$name 必须包含时区');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw SourceResultException('$name 不是有效时间');
    }
    return parsed.toUtc().add(const Duration(hours: 8));
  }

  DateTime _date(Object? value, String name) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw SourceResultException('$name 必须是 YYYY-MM-DD');
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null) throw SourceResultException('$name 不是有效日期');
    return parsed;
  }
}

class _Collection {
  const _Collection({
    required this.rows,
    this.mode = SourceReadMode.upsert,
    this.removedRemoteIds = const {},
  });

  final List<Map<String, Object?>> rows;
  final SourceReadMode mode;
  final Set<String> removedRemoteIds;
}

/// Maps a definition id to the legacy enum used by existing agenda styling.
DeadlineSource? deadlineSourceForDefinition(String definitionId) =>
    switch (definitionId) {
      BuiltinSources.lexue => DeadlineSource.lexue,
      BuiltinSources.eclass => DeadlineSource.eclass,
      BuiltinSources.mooc => DeadlineSource.mooc,
      _ => null,
    };
