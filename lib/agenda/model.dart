import '../core/json.dart';
import '../core/time.dart';
import 'deadline_cutoff.dart';
import 'deadline_source.dart';
import 'details.dart';

export 'deadline_cutoff.dart';
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
    this.examAutoCompletionHandled = false,
    this.completionSchemaVersion = currentCompletionSchemaVersion,
    this.deleted = false,
    this.term,
    this.local = true,
    this.source,
    this.course = '',
    this.url,
    this.details,
    this.tailDays = defaultTailDays,
    this.startOnly = false,
    this.deadlineCutoffWindow = const DeadlineCutoffWindow(),
  }) {
    if (id.isEmpty || title.trim().isEmpty) {
      throw const FormatException('日程标题或编号缺失');
    }
    if (startOnly && kind != AgendaKind.deadline) {
      throw const FormatException('只有截止日期可以只标记开放时间');
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
        (entrySource == null ||
            entryUrl.scheme != 'https' ||
            entryUrl.host != entrySource.host ||
            entryUrl.userInfo.isNotEmpty)) {
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
  }

  static const currentCompletionSchemaVersion = 1;
  static const defaultTailDays = 4;
  static const maxTailDays = 30;

  final String id;
  final String title;
  final AgendaKind kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String location;
  final String notes;
  final bool done;

  /// True after an exam's one automatic opportunity or a manual completion
  /// choice. Undoing completion never resets this durable marker.
  final bool examAutoCompletionHandled;

  /// Zero means an old record still needs its one-time, clock-aware migration.
  /// Parsing JSON itself deliberately has no dependence on the current time.
  final int completionSchemaVersion;
  final bool deleted;
  final String? term;
  final bool local;
  final DeadlineSource? source;
  final String course;
  final Uri? url;
  final AgendaEntryDetails? details;

  /// Timeline reservation in days; the painted tail leaves a quarter-day gap
  /// at minimum zoom and keeps its screen width as the view zooms in.
  final int tailDays;

  /// A deadline that only knows when it opened, with no due date at all —
  /// an open-ended quiz, for instance. It can never be overdue, and the
  /// timeline anchors its card at [startsAt] and grows it to the right instead
  /// of hanging a tail to the left of a due time. Labels must not present it
  /// as due.
  final bool startOnly;

  /// Presentation-only state. It is deliberately absent from [toJson], so
  /// changing the window or syncing can never overwrite the original deadline.
  final DeadlineCutoffWindow deadlineCutoffWindow;

  bool get isDeadline => kind == AgendaKind.deadline;

  DateTime get realDueAt =>
      allDay ? calendarDate(startsAt).add(const Duration(days: 1)) : startsAt;

  DateTime get dueAt => isDeadline && !startOnly
      ? deadlineCutoffWindow.apply(realDueAt)
      : realDueAt;

  /// Includes a deadline exactly at the window start: its two markers still
  /// overlap and the real marker must paint above the effective one.
  bool get hasDeadlineCutoff =>
      isDeadline && !startOnly && deadlineCutoffWindow.contains(realDueAt);

  bool get hasAdjustedDeadline =>
      hasDeadlineCutoff && dueAt.isBefore(realDueAt);

  /// Day grouping and labels follow the derived deadline only when adjusted.
  /// Keep unadjusted all-day entries on their original calendar date.
  DateTime get scheduledAt => hasAdjustedDeadline ? dueAt : startsAt;
  bool get effectiveAllDay => allDay && !hasAdjustedDeadline;

  AgendaEntry withDeadlineCutoff(DeadlineCutoffWindow window) =>
      window == deadlineCutoffWindow
      ? this
      : copyWith(deadlineCutoffWindow: window);

  bool overdue(DateTime now) {
    if (done || (isDeadline && startOnly)) return false;
    // An unhandled exam is awaiting its one automatic completion, not overdue.
    // Only an explicitly reopened exam may become overdue after its real end.
    if (kind == AgendaKind.exam && !examAutoCompletionHandled) return false;
    return isDeadline ? dueAt.isBefore(now) : hasEnded(now);
  }

  /// Time passing and completion are separate. In particular, reopening an
  /// ended exam must not make it completed again during a widget rebuild.
  bool hasEnded(DateTime now) => isDeadline
      ? !startOnly && !dueAt.isAfter(now)
      : !endsAt!.isAfter(now);

  bool isFinished(DateTime now) => done;

  bool occursOn(DateTime date) {
    final day = calendarDate(date);
    if (isDeadline) return calendarDate(scheduledAt) == day;
    return startsAt.isBefore(day.add(const Duration(days: 1))) &&
        endsAt!.isAfter(day);
  }

  AgendaEntry copyWith({
    bool? done,
    bool? examAutoCompletionHandled,
    int? completionSchemaVersion,
    bool? deleted,
    DeadlineCutoffWindow? deadlineCutoffWindow,
  }) => AgendaEntry(
    id: id,
    title: title,
    kind: kind,
    startsAt: startsAt,
    endsAt: endsAt,
    allDay: allDay,
    location: location,
    notes: notes,
    done: done ?? this.done,
    examAutoCompletionHandled:
        examAutoCompletionHandled ?? this.examAutoCompletionHandled,
    completionSchemaVersion:
        completionSchemaVersion ?? this.completionSchemaVersion,
    deleted: deleted ?? this.deleted,
    term: term,
    local: local,
    source: source,
    course: course,
    url: url,
    details: details,
    tailDays: tailDays,
    startOnly: startOnly,
    deadlineCutoffWindow: deadlineCutoffWindow ?? this.deadlineCutoffWindow,
  );

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
    'examAutoCompletionHandled': examAutoCompletionHandled,
    'completionSchemaVersion': completionSchemaVersion,
    'deleted': deleted,
    'term': term,
    'local': local,
    'source': source?.name,
    'course': course,
    'url': url?.toString(),
    'details': details?.toJson(),
    'tailDays': tailDays,
    'startOnly': startOnly,
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
    return AgendaEntry(
      id: jsonStringField(json, 'id'),
      title: jsonStringField(json, 'title'),
      kind: kind,
      startsAt: jsonDateTime('startsAt', json['startsAt']),
      endsAt: jsonDateTimeOrNull('endsAt', json['endsAt']),
      allDay: jsonBoolField(json, 'allDay'),
      location: jsonStringField(json, 'location'),
      notes: jsonStringField(json, 'notes'),
      done: jsonBoolField(json, 'done'),
      examAutoCompletionHandled:
          jsonBoolField(json, 'examAutoCompletionHandled', fallback: false),
      completionSchemaVersion:
          jsonIntFieldOrNull(json, 'completionSchemaVersion') ?? 0,
      deleted: jsonBoolField(json, 'deleted', fallback: false),
      term: jsonStringFieldOrNull(json, 'term'),
      local: jsonBoolField(json, 'local'),
      source: source,
      course: jsonStringFieldOrNull(json, 'course') ?? '',
      url: rawUrl == null
          ? null
          : Uri.tryParse(rawUrl) ?? (throw FormatException('url 格式不正确')),
      tailDays: jsonIntFieldOrNull(json, 'tailDays') ?? defaultTailDays,
      // Entries written before this flag existed simply had no open-ended
      // deadlines, so a missing key means an ordinary deadline.
      startOnly: jsonBoolField(json, 'startOnly', fallback: false),
      details: rawDetails == null
          ? null
          : AgendaEntryDetails.fromJson(jsonObject(rawDetails, 'details')),
    );
  }
}
