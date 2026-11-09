import '../core/json.dart';
import '../core/time.dart';
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
  }) {
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
  final bool deleted;
  final String? term;
  final bool local;
  final DeadlineSource? source;
  final String course;
  final Uri? url;
  final AgendaEntryDetails? details;

  /// Maximum gradient tail in baseline days. Other cards can shorten the tail;
  /// its screen width stays fixed as the view zooms in.
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

  AgendaEntry copyWith({bool? done, bool? deleted}) => AgendaEntry(
    id: id,
    title: title,
    kind: kind,
    startsAt: startsAt,
    endsAt: endsAt,
    allDay: allDay,
    location: location,
    notes: notes,
    done: done ?? this.done,
    deleted: deleted ?? this.deleted,
    term: term,
    local: local,
    source: source,
    course: course,
    url: url,
    details: details,
    tailDays: tailDays,
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
    'deleted': deleted,
    'term': term,
    'local': local,
    'source': source?.name,
    'course': course,
    'url': url?.toString(),
    'details': details?.toJson(),
    'tailDays': tailDays,
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
      deleted: jsonBoolField(json, 'deleted', fallback: false),
      term: jsonStringFieldOrNull(json, 'term'),
      local: jsonBoolField(json, 'local'),
      source: source,
      course: jsonStringFieldOrNull(json, 'course') ?? '',
      url: rawUrl == null
          ? null
          : Uri.tryParse(rawUrl) ?? (throw FormatException('url 格式不正确')),
      tailDays: jsonIntFieldOrNull(json, 'tailDays') ?? defaultTailDays,
      details: rawDetails == null
          ? null
          : AgendaEntryDetails.fromJson(jsonObject(rawDetails, 'details')),
    );
  }
}
