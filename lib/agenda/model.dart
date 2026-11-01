import '../core/json.dart';
import '../schedule/model.dart';
import 'deadline_source.dart';

enum AgendaKind {
  event('活动'),
  deadline('DDL'),
  exam('考试');

  const AgendaKind(this.label);
  final String label;
}

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
  }) {
    if (id.isEmpty || title.trim().isEmpty) {
      throw const FormatException('日程标题或编号缺失');
    }
    if (kind != AgendaKind.deadline &&
        (endsAt == null || !endsAt!.isAfter(startsAt))) {
      throw const FormatException('结束时间必须晚于开始时间');
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
  }

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

  bool get isDeadline => kind == AgendaKind.deadline;

  DateTime get dueAt =>
      allDay ? calendarDate(startsAt).add(const Duration(days: 1)) : startsAt;

  bool overdue(DateTime now) => isDeadline && !done && dueAt.isBefore(now);

  bool isFinished(DateTime now) => isDeadline ? done : !endsAt!.isAfter(now);

  String get timeLabel {
    if (allDay) return '全天';
    if (isDeadline) return '${clockText(startsAt)} 截止';
    final end = endsAt!;
    final sameDay = calendarDate(startsAt) == calendarDate(end);
    return '${clockText(startsAt)}–'
        '${sameDay ? '' : '${end.month}月${end.day}日 '}${clockText(end)}';
  }

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
    );
  }
}

String clockText(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String agendaDateLabel(DateTime date) {
  final day = calendarDate(date);
  final today = calendarDate(campusNow());
  final relative = switch (day.difference(today).inDays) {
    0 => '今天 ',
    1 => '明天 ',
    -1 => '昨天 ',
    _ => '',
  };
  final year = date.year == today.year ? '' : '${date.year}年';
  return '$relative$year${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}
