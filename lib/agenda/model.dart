import '../core/json.dart';
import '../core/time.dart';
import '../sources/legacy.dart';
import '../sources/source.dart';
import 'deadline_source.dart';
import 'details.dart';

export 'details.dart';

enum AgendaKind { event, deadline, exam }

/// Times use the same Beijing wall-clock convention as campusNow().
class AgendaEntry {
  AgendaEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.location = '',
    this.notes = '',
    this.done = false,
    this.deleted = false,
    this.term,
    this.local = true,
    this.source,
    this.course = '',
    this.url,
    this.details,
    this.tailDays = defaultTailDays,
    this.origin,
    Set<String> overrides = const {},
    Map<String, dynamic> sourceValues = const {},
    this.completionOverride,
    this.lastSourceCompletion,
    this.sourceRemoved = false,
  }) : overrides = Set.unmodifiable(overrides),
       sourceValues = Map<String, dynamic>.unmodifiable(sourceValues) {
    if (id.isEmpty || title.trim().isEmpty) {
      throw const FormatException('日程标题或编号缺失');
    }
    if (kind != AgendaKind.deadline &&
        (endsAt == null || !endsAt!.isAfter(startsAt))) {
      throw const FormatException('结束时间必须晚于开始时间');
    }
    if (tailDays < 1 || tailDays > maxTailDays) {
      throw const FormatException('拖尾长度必须为 1–30 天');
    }
    final entryUrl = url;
    final entrySource = source;
    if (entryUrl != null &&
        (entryUrl.scheme != 'https' ||
            entryUrl.userInfo.isNotEmpty ||
            entrySource != null && entryUrl.host != entrySource.host ||
            entrySource == null && origin == null)) {
      throw const FormatException('作业链接不属于对应的来源平台');
    }
    final entryDetails = details;
    final entryTerm = term;
    if (entryDetails case PhysicsLabDeadlineDetails()
        when entrySource != null) {
      throw const FormatException('大物实验日程不能标记学习平台来源');
    }
    if (entryDetails is PhysicsLabDeadlineDetails &&
        (entryTerm == null || entryTerm.trim().isEmpty)) {
      throw const FormatException('大物实验日程缺少学期');
    }
    if (entryDetails case MoocDeadlineDetails()
        when entrySource != DeadlineSource.mooc) {
      throw const FormatException('MOOC 日程必须标记 MOOC 来源');
    }
    final recordOrigin = origin;
    if (recordOrigin != null) {
      final expected = switch (kind) {
        AgendaKind.deadline => SourceResource.deadline,
        AgendaKind.event => SourceResource.event,
        AgendaKind.exam => SourceResource.exam,
      };
      if (recordOrigin.resource != expected) {
        throw const FormatException('日程来源类型与记录类型不一致');
      }
    }
    if (origin == null && overrides.isNotEmpty) {
      throw const FormatException('手动记录不能带有来源字段覆盖');
    }
    if (origin == null && completionOverride != null) {
      throw const FormatException('手动记录不能带有来源完成状态覆盖');
    }
    if (overrides.any((field) => !_editableFields.contains(field))) {
      throw const FormatException('日程包含未知的可覆盖字段');
    }
    if (sourceValues.keys.any((field) => !_editableFields.contains(field))) {
      throw const FormatException('日程来源字段包含未知字段');
    }
  }

  static const defaultTailDays = 4;
  static const maxTailDays = 30;
  static const _editableFields = {
    'title',
    'course',
    'location',
    'notes',
    'startsAt',
    'endsAt',
    'allDay',
    'timing',
  };
  static const _timeFields = {'startsAt', 'endsAt', 'allDay'};

  final String id;
  final String title;
  final AgendaKind kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String location;
  final String notes;
  final bool done;
  final bool deleted;
  final String? term;
  final bool local;
  final DeadlineSource? source;
  final String course;
  final Uri? url;
  final AgendaEntryDetails? details;

  /// Stable remote identity when this record came from a source.
  final RecordOrigin? origin;

  /// Source fields the user fixed. The timing group is stored as `timing`.
  final Set<String> overrides;

  /// Latest values returned by the source, used by "restore source value".
  final Map<String, dynamic> sourceValues;

  /// Explicit completion choice; null follows the source.
  final CompletionOverride? completionOverride;

  /// Last completion state reported by the source.
  final CompletionState? lastSourceCompletion;

  /// The source no longer returns this record in a complete range, but local
  /// edits or state keep it visible.
  final bool sourceRemoved;

  /// Timeline reservation in days; the painted tail leaves a quarter-day gap
  /// at minimum zoom and keeps its screen width as the view zooms in.
  final int tailDays;

  bool get isDeadline => kind == AgendaKind.deadline;

  DateTime get dueAt =>
      allDay ? calendarDate(startsAt).add(const Duration(days: 1)) : startsAt;

  bool overdue(DateTime now) => isDeadline && !done && dueAt.isBefore(now);

  bool isFinished(DateTime now) => isDeadline ? done : !endsAt!.isAfter(now);

  bool occursOn(DateTime date) {
    final day = calendarDate(date);
    if (isDeadline) return calendarDate(startsAt) == day;
    return startsAt.isBefore(day.add(const Duration(days: 1))) &&
        endsAt!.isAfter(day);
  }

  bool get isEdited =>
      overrides.isNotEmpty || completionOverride != null || sourceRemoved;

  bool isOverridden(String field) =>
      overrides.contains(field) ||
      (_timeFields.contains(field) && overrides.contains('timing'));

  AgendaEntry copyWith({
    String? id,
    String? title,
    AgendaKind? kind,
    DateTime? startsAt,
    Object? endsAt = _unset,
    bool? allDay,
    String? location,
    String? notes,
    bool? done,
    bool? deleted,
    Object? term = _unset,
    bool? local,
    Object? source = _unset,
    String? course,
    Object? url = _unset,
    Object? details = _unset,
    int? tailDays,
    Object? origin = _unset,
    Set<String>? overrides,
    Map<String, dynamic>? sourceValues,
    Object? completionOverride = _unset,
    Object? lastSourceCompletion = _unset,
    bool? sourceRemoved,
  }) => AgendaEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    startsAt: startsAt ?? this.startsAt,
    endsAt: identical(endsAt, _unset) ? this.endsAt : endsAt as DateTime?,
    allDay: allDay ?? this.allDay,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    done: done ?? this.done,
    deleted: deleted ?? this.deleted,
    term: identical(term, _unset) ? this.term : term as String?,
    local: local ?? this.local,
    source: identical(source, _unset) ? this.source : source as DeadlineSource?,
    course: course ?? this.course,
    url: identical(url, _unset) ? this.url : url as Uri?,
    details: identical(details, _unset)
        ? this.details
        : details as AgendaEntryDetails?,
    tailDays: tailDays ?? this.tailDays,
    origin: identical(origin, _unset) ? this.origin : origin as RecordOrigin?,
    overrides: overrides ?? this.overrides,
    sourceValues: sourceValues ?? this.sourceValues,
    completionOverride: identical(completionOverride, _unset)
        ? this.completionOverride
        : completionOverride as CompletionOverride?,
    lastSourceCompletion: identical(lastSourceCompletion, _unset)
        ? this.lastSourceCompletion
        : lastSourceCompletion as CompletionState?,
    sourceRemoved: sourceRemoved ?? this.sourceRemoved,
  );

  /// Applies a source record while preserving user overrides and local state.
  AgendaEntry applySource(AgendaEntry incoming) {
    final incomingOrigin = incoming.origin ?? origin;
    if (incomingOrigin == null) return incoming;
    final nextSourceValues = <String, dynamic>{
      ...sourceValues,
      'title': incoming.title,
      'course': incoming.course,
      'location': incoming.location,
      'notes': incoming.notes,
      'startsAt': incoming.startsAt.toIso8601String(),
      'endsAt': incoming.endsAt?.toIso8601String(),
      'allDay': incoming.allDay,
    };
    final legacyLocal =
        local && overrides.isEmpty && completionOverride == null;
    final timingOverridden = legacyLocal || isOverridden('startsAt');
    final sourceCompletion =
        incoming.lastSourceCompletion ??
        (incoming.done ? CompletionState.done : CompletionState.pending);
    final completion = legacyLocal
        ? done || incoming.done
        : switch (completionOverride) {
            CompletionOverride.done => true,
            CompletionOverride.pending => false,
            null => switch (sourceCompletion) {
              CompletionState.done => true,
              CompletionState.pending => false,
              CompletionState.unknown => done,
            },
          };
    return copyWith(
      title: legacyLocal || isOverridden('title') ? title : incoming.title,
      course: legacyLocal || isOverridden('course') ? course : incoming.course,
      location: legacyLocal || isOverridden('location')
          ? location
          : incoming.location,
      notes: legacyLocal || isOverridden('notes') ? notes : incoming.notes,
      startsAt: timingOverridden ? startsAt : incoming.startsAt,
      endsAt: timingOverridden ? endsAt : incoming.endsAt,
      allDay: timingOverridden ? allDay : incoming.allDay,
      done: completion,
      origin: incomingOrigin,
      sourceValues: nextSourceValues,
      lastSourceCompletion: sourceCompletion,
      sourceRemoved: false,
      local: local || overrides.isNotEmpty || completionOverride != null,
    );
  }

  /// Records a user edit. Timing fields are fixed as one group so a source
  /// update cannot produce an invalid start/end pair.
  AgendaEntry withUserEdit({
    String? title,
    String? course,
    String? location,
    String? notes,
    DateTime? startsAt,
    Object? endsAt = _unset,
    bool? allDay,
  }) {
    if (origin == null) {
      return copyWith(
        title: title,
        course: course,
        location: location,
        notes: notes,
        startsAt: startsAt,
        endsAt: endsAt,
        allDay: allDay,
      );
    }
    final nextOverrides = {...overrides};
    final nextSourceValues = {...sourceValues};
    void fix(String field, Object? oldValue, Object? newValue) {
      if (oldValue == newValue) return;
      nextOverrides.add(field);
      nextSourceValues.putIfAbsent(field, () => _jsonValue(field, oldValue));
    }

    if (title != null) fix('title', this.title, title);
    if (course != null) fix('course', this.course, course);
    if (location != null) fix('location', this.location, location);
    if (notes != null) fix('notes', this.notes, notes);
    final nextEndsAt = identical(endsAt, _unset)
        ? this.endsAt
        : endsAt as DateTime?;
    final nextStartsAt = startsAt ?? this.startsAt;
    final nextAllDay = allDay ?? this.allDay;
    if (nextStartsAt != this.startsAt ||
        nextEndsAt != this.endsAt ||
        nextAllDay != this.allDay) {
      nextOverrides.add('timing');
      nextSourceValues.putIfAbsent(
        'startsAt',
        () => this.startsAt.toIso8601String(),
      );
      nextSourceValues.putIfAbsent(
        'endsAt',
        () => this.endsAt?.toIso8601String(),
      );
      nextSourceValues.putIfAbsent('allDay', () => this.allDay);
    }
    return copyWith(
      title: title ?? this.title,
      course: course ?? this.course,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      startsAt: nextStartsAt,
      endsAt: nextEndsAt,
      allDay: nextAllDay,
      overrides: nextOverrides,
      sourceValues: nextSourceValues,
      local: true,
    );
  }

  /// Restores source values for [fields], or every overridden field when null.
  AgendaEntry restoreSource({Set<String>? fields}) {
    if (origin == null) return this;
    final requested = fields == null
        ? {...overrides}
        : {
            for (final field in fields)
              if (_timeFields.contains(field)) 'timing' else field,
          };
    final nextOverrides = {...overrides};
    var nextTitle = title;
    var nextCourse = course;
    var nextLocation = location;
    var nextNotes = notes;
    var nextStartsAt = startsAt;
    var nextEndsAt = endsAt;
    var nextAllDay = allDay;
    if (requested.contains('timing')) {
      nextOverrides.remove('timing');
      nextStartsAt = _dateValue(sourceValues['startsAt']) ?? startsAt;
      nextEndsAt = _dateValue(sourceValues['endsAt']);
      nextAllDay = sourceValues['allDay'] is bool
          ? sourceValues['allDay'] as bool
          : allDay;
    }
    for (final field in requested) {
      nextOverrides.remove(field);
      switch (field) {
        case 'title':
          nextTitle = sourceValues['title'] is String
              ? sourceValues['title'] as String
              : title;
        case 'course':
          nextCourse = sourceValues['course'] is String
              ? sourceValues['course'] as String
              : course;
        case 'location':
          nextLocation = sourceValues['location'] is String
              ? sourceValues['location'] as String
              : location;
        case 'notes':
          nextNotes = sourceValues['notes'] is String
              ? sourceValues['notes'] as String
              : notes;
      }
    }
    return copyWith(
      title: nextTitle,
      course: nextCourse,
      location: nextLocation,
      notes: nextNotes,
      startsAt: nextStartsAt,
      endsAt: nextEndsAt,
      allDay: nextAllDay,
      overrides: nextOverrides,
      local:
          nextOverrides.isNotEmpty ||
          completionOverride != null ||
          sourceRemoved,
    );
  }

  AgendaEntry setCompletionOverride(CompletionOverride? value) {
    if (origin == null) return this;
    final nextDone = switch (value) {
      CompletionOverride.done => true,
      CompletionOverride.pending => false,
      null => switch (lastSourceCompletion) {
        CompletionState.done => true,
        CompletionState.pending => false,
        CompletionState.unknown || null => done,
      },
    };
    return copyWith(
      done: nextDone,
      completionOverride: value,
      local: overrides.isNotEmpty || value != null || sourceRemoved,
    );
  }

  AgendaEntry rebindOrigin(String sourceInstanceId) {
    final current = origin;
    if (current == null || current.sourceInstanceId == sourceInstanceId) {
      return this;
    }
    return copyWith(
      origin: current.copyWith(sourceInstanceId: sourceInstanceId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'allDay': allDay,
    'location': location,
    'notes': notes,
    'done': done,
    'deleted': deleted,
    'term': term,
    'local': local,
    'source': source?.name,
    'course': course,
    'url': url?.toString(),
    'details': details?.toJson(),
    'tailDays': tailDays,
    if (origin != null) 'origin': origin!.toJson(),
    if (overrides.isNotEmpty) 'overrides': overrides.toList()..sort(),
    if (sourceValues.isNotEmpty) 'sourceValues': sourceValues,
    if (completionOverride != null)
      'completionOverride': completionOverride!.name,
    if (lastSourceCompletion != null)
      'lastSourceCompletion': lastSourceCompletion!.name,
    if (sourceRemoved) 'sourceRemoved': true,
  };

  factory AgendaEntry.fromJson(Map<String, dynamic> json) {
    final kindName = jsonStringField(json, 'kind');
    final kind = AgendaKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) throw FormatException('kind 格式不正确');

    final sourceName = jsonStringFieldOrNull(json, 'source');
    final source = sourceName == null
        ? null
        : DeadlineSource.values
              .where((value) => value.name == sourceName)
              .firstOrNull;
    if (sourceName != null && source == null) {
      throw FormatException('source 格式不正确');
    }

    final rawUrl = jsonStringFieldOrNull(json, 'url');
    final rawDetails = json['details'];
    final url = rawUrl == null
        ? null
        : Uri.tryParse(rawUrl) ?? (throw FormatException('url 格式不正确'));
    final details = rawDetails == null
        ? null
        : AgendaEntryDetails.fromJson(jsonObject(rawDetails, 'details'));
    final local = jsonBoolField(json, 'local');
    final origin = json['origin'] == null
        ? _legacyOrigin(
            id: jsonStringField(json, 'id'),
            source: source,
            url: url,
            kind: kind,
          )
        : RecordOrigin.fromJson(jsonObject(json['origin'], 'origin'));
    final rawOverrides = json['overrides'];
    final overrides = rawOverrides == null
        ? <String>{}
        : {
            for (final value in jsonList(rawOverrides, 'overrides'))
              jsonString(value, 'overrides[]'),
          };
    final rawSourceValues = json['sourceValues'];
    final sourceValues = rawSourceValues == null
        ? <String, dynamic>{}
        : jsonObject(rawSourceValues, 'sourceValues');
    final completionOverride = _completionOverride(json['completionOverride']);
    final lastSourceCompletion = _completionState(json['lastSourceCompletion']);
    final legacyEdited = local && origin != null;
    final entry = AgendaEntry(
      id: jsonStringField(json, 'id'),
      title: jsonStringField(json, 'title'),
      kind: kind,
      startsAt: jsonDateTime('startsAt', json['startsAt']),
      endsAt: jsonDateTimeOrNull('endsAt', json['endsAt']),
      allDay: jsonBoolField(json, 'allDay'),
      location: jsonStringField(json, 'location'),
      notes: jsonStringField(json, 'notes'),
      done: jsonBoolField(json, 'done'),
      deleted: jsonBoolField(json, 'deleted', fallback: false),
      term: jsonStringFieldOrNull(json, 'term'),
      local: local,
      source: source,
      course: jsonStringFieldOrNull(json, 'course') ?? '',
      url: url,
      tailDays: jsonIntFieldOrNull(json, 'tailDays') ?? defaultTailDays,
      details: details,
      origin: origin,
      overrides: legacyEdited && overrides.isEmpty
          ? {'title', 'course', 'location', 'notes', 'timing'}
          : overrides,
      sourceValues: legacyEdited && sourceValues.isEmpty
          ? {
              'title': jsonStringField(json, 'title'),
              'course': jsonStringFieldOrNull(json, 'course') ?? '',
              'location': jsonStringField(json, 'location'),
              'notes': jsonStringField(json, 'notes'),
              'startsAt': jsonStringField(json, 'startsAt'),
              'endsAt': jsonStringFieldOrNull(json, 'endsAt'),
              'allDay': jsonBoolField(json, 'allDay'),
            }
          : sourceValues,
      completionOverride:
          completionOverride ??
          (legacyEdited &&
                  kind == AgendaKind.deadline &&
                  jsonBoolField(json, 'done')
              ? CompletionOverride.done
              : null),
      lastSourceCompletion:
          lastSourceCompletion ??
          (kind == AgendaKind.deadline
              ? (jsonBoolField(json, 'done')
                    ? CompletionState.done
                    : CompletionState.pending)
              : null),
      sourceRemoved: json['sourceRemoved'] == true,
    );
    return entry;
  }
}

const _unset = Object();

RecordOrigin? _legacyOrigin({
  required String id,
  required DeadlineSource? source,
  required Uri? url,
  required AgendaKind kind,
}) {
  final resource = switch (kind) {
    AgendaKind.deadline => SourceResource.deadline,
    AgendaKind.event => SourceResource.event,
    AgendaKind.exam => SourceResource.exam,
  };
  if (source != null) {
    return LegacyRecordIds.deadlineOrigin(
      id: id,
      source: source.name,
      url: url,
      resource: resource,
    );
  }
  if (kind == AgendaKind.deadline && id.startsWith('physics-lab:')) {
    return LegacyRecordIds.physicsLabOrigin(id);
  }
  if (kind == AgendaKind.exam && id.startsWith('exam-')) {
    return LegacyRecordIds.schoolExamOrigin(id);
  }
  return null;
}

CompletionOverride? _completionOverride(Object? value) => value == null
    ? null
    : CompletionOverride.values.firstWhere(
        (item) => item.name == value,
        orElse: () => throw const FormatException('完成状态覆盖格式不正确'),
      );

CompletionState? _completionState(Object? value) => value == null
    ? null
    : CompletionState.values.firstWhere(
        (item) => item.name == value,
        orElse: () => throw const FormatException('来源完成状态格式不正确'),
      );

DateTime? _dateValue(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Object? _jsonValue(String field, Object? value) => switch (field) {
  'startsAt' => (value as DateTime).toIso8601String(),
  'endsAt' => (value as DateTime?)?.toIso8601String(),
  _ => value,
};
