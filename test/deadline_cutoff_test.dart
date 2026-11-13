import 'dart:convert';

import 'package:bitree/agenda/model.dart';
import 'package:flutter_test/flutter_test.dart';

const _overnight = DeadlineCutoffWindow(enabled: true);
const _daytime = DeadlineCutoffWindow(
  enabled: true,
  startMinute: 9 * 60,
  endMinute: 17 * 60,
);

AgendaEntry _deadline(DateTime at, {
  bool allDay = false,
  bool startOnly = false,
}) => AgendaEntry(
  id: 'deadline',
  title: '作业',
  kind: AgendaKind.deadline,
  startsAt: at,
  allDay: allDay,
  startOnly: startOnly,
);

void main() {
  group('Daily cutoff window', () {
    test('Disabled windows leave every instant unchanged', () {
      const disabled = DeadlineCutoffWindow();
      for (final actual in [
        DateTime.utc(2026, 11, 11, 0),
        DateTime.utc(2026, 11, 11, 8),
        DateTime.utc(2026, 11, 11, 22),
        DateTime.utc(2026, 11, 11, 23, 59, 59, 999, 999),
      ]) {
        expect(disabled.contains(actual), isFalse);
        expect(disabled.apply(actual), actual);
      }
    });

    test('Same-day windows include both exact endpoints', () {
      final start = DateTime.utc(2026, 11, 11, 9);
      final end = DateTime.utc(2026, 11, 11, 17);
      expect(_daytime.crossesMidnight, isFalse);
      expect(_daytime.contains(start), isTrue);
      expect(_daytime.apply(start), start);
      expect(_daytime.contains(end), isTrue);
      expect(_daytime.apply(end), start);
      expect(_daytime.apply(DateTime.utc(2026, 11, 11, 12, 30)), start);
    });

    test('Containment compares exact instants, not truncated minutes', () {
      final start = DateTime.utc(2026, 11, 11, 9);
      final end = DateTime.utc(2026, 11, 11, 17);
      for (final outside in [
        start.subtract(const Duration(microseconds: 1)),
        end.add(const Duration(microseconds: 1)),
        end.add(const Duration(milliseconds: 1)),
        end.add(const Duration(seconds: 1)),
        DateTime.utc(2026, 11, 11, 18),
      ]) {
        expect(_daytime.contains(outside), isFalse);
        expect(_daytime.apply(outside), outside);
      }
      expect(
        _daytime.apply(end.subtract(const Duration(microseconds: 1))),
        start,
      );
    });

    test('Overnight early hours belong to the previous calendar day', () {
      final previousStart = DateTime.utc(2026, 11, 10, 22);
      final todayStart = DateTime.utc(2026, 11, 11, 22);
      expect(_overnight.crossesMidnight, isTrue);
      for (final actual in [
        DateTime.utc(2026, 11, 11),
        DateTime.utc(2026, 11, 11, 7, 30),
        DateTime.utc(2026, 11, 11, 8),
      ]) {
        expect(_overnight.contains(actual), isTrue);
        expect(_overnight.apply(actual), previousStart);
      }
      expect(_overnight.apply(todayStart), todayStart);
      expect(
        _overnight.apply(DateTime.utc(2026, 11, 11, 23, 59)),
        todayStart,
      );
      for (final outside in [
        DateTime.utc(2026, 11, 11, 8, 0, 0, 0, 1),
        DateTime.utc(2026, 11, 11, 8, 0, 1),
        todayStart.subtract(const Duration(microseconds: 1)),
        DateTime.utc(2026, 11, 11, 12),
      ]) {
        expect(_overnight.contains(outside), isFalse);
        expect(_overnight.apply(outside), outside);
      }
    });

    test('Overnight windows cross month, year and leap-day boundaries', () {
      for (final (actual, expected) in [
        (DateTime.utc(2027, 1, 1, 7), DateTime.utc(2026, 12, 31, 22)),
        (DateTime.utc(2026, 12, 1, 7), DateTime.utc(2026, 11, 30, 22)),
        (DateTime.utc(2028, 3, 1, 7), DateTime.utc(2028, 2, 29, 22)),
      ]) {
        expect(_overnight.apply(actual), expected);
        expect(_overnight.apply(actual).isUtc, isTrue);
      }
    });

    test('Equal times match just one exact instant, not the full day', () {
      const point = DeadlineCutoffWindow(
        enabled: true,
        startMinute: 8 * 60,
        endMinute: 8 * 60,
      );
      final at = DateTime.utc(2026, 11, 11, 8);
      expect(point.isSinglePoint, isTrue);
      expect(point.crossesMidnight, isFalse);
      expect(point.contains(at), isTrue);
      expect(point.apply(at), at);
      for (final outside in [
        at.subtract(const Duration(microseconds: 1)),
        at.add(const Duration(microseconds: 1)),
        DateTime.utc(2026, 11, 11),
        DateTime.utc(2026, 11, 11, 22),
      ]) {
        expect(point.contains(outside), isFalse);
        expect(point.apply(outside), outside);
      }
    });

    test('Midnight equal-time windows still match a single point', () {
      const point = DeadlineCutoffWindow(
        enabled: true,
        startMinute: 0,
        endMinute: 0,
      );
      final at = DateTime.utc(2027, 1, 1);
      expect(point.contains(at), isTrue);
      expect(point.apply(at), at);
      expect(point.contains(at.add(const Duration(microseconds: 1))), isFalse);
      expect(point.contains(at.subtract(const Duration(microseconds: 1))), isFalse);
    });

    test('Serialization, equality and copies preserve the selected window', () {
      const original = DeadlineCutoffWindow(
        enabled: true,
        startMinute: 21 * 60 + 15,
        endMinute: 7 * 60 + 45,
      );
      final json = jsonDecode(jsonEncode(original.toJson()))
          as Map<String, dynamic>;
      final restored = DeadlineCutoffWindow.fromJson(json);
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(original.copyWith(), original);
      final disabled = original.copyWith(enabled: false);
      expect(disabled.enabled, isFalse);
      expect(disabled.startMinute, original.startMinute);
      expect(disabled.endMinute, original.endMinute);
      expect(disabled, isNot(original));
      expect(original.copyWith(startMinute: 123).startMinute, 123);
      expect(original.copyWith(endMinute: 456).endMinute, 456);
    });

    test('Stored minute ranges outside a single day are rejected', () {
      for (final field in ['startMinute', 'endMinute']) {
        for (final invalid in [-1, 24 * 60, 24 * 60 + 1]) {
          final json = _overnight.toJson()..[field] = invalid;
          expect(
            () => DeadlineCutoffWindow.fromJson(json),
            throwsA(isA<FormatException>()),
          );
        }
      }
    });

    test('Malformed stored types and missing fields are rejected', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'enabled': true, 'startMinute': 60},
        {'enabled': 'true', 'startMinute': 60, 'endMinute': 120},
        {'enabled': true, 'startMinute': '60', 'endMinute': 120},
        {'enabled': true, 'startMinute': 60, 'endMinute': 120.5},
      ]) {
        expect(
          () => DeadlineCutoffWindow.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  group('Agenda deadline projection', () {
    test('Effective time changes but the true deadline remains untouched', () {
      final actual = DateTime.utc(2026, 11, 11, 7);
      final raw = _deadline(actual);
      final shown = raw.withDeadlineCutoff(_overnight);
      expect(raw.dueAt, actual);
      expect(raw.hasDeadlineCutoff, isFalse);
      expect(shown.startsAt, actual);
      expect(shown.realDueAt, actual);
      expect(shown.dueAt, DateTime.utc(2026, 11, 10, 22));
      expect(shown.scheduledAt, shown.dueAt);
      expect(shown.hasDeadlineCutoff, isTrue);
      expect(shown.hasAdjustedDeadline, isTrue);
      expect(shown.occursOn(DateTime.utc(2026, 11, 10)), isTrue);
      expect(shown.occursOn(DateTime.utc(2026, 11, 11)), isFalse);
      expect(shown.overdue(shown.dueAt), isFalse);
      expect(
        shown.overdue(shown.dueAt.add(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(raw.overdue(shown.dueAt.add(const Duration(hours: 1))), isFalse);
    });

    test('A matched start or single point has overlapping markers, not a shift', () {
      final actual = DateTime.utc(2026, 11, 11, 22);
      for (final window in [
        _overnight,
        const DeadlineCutoffWindow(
          enabled: true,
          startMinute: 22 * 60,
          endMinute: 22 * 60,
        ),
      ]) {
        final shown = _deadline(actual).withDeadlineCutoff(window);
        expect(shown.hasDeadlineCutoff, isTrue);
        expect(shown.hasAdjustedDeadline, isFalse);
        expect(shown.dueAt, shown.realDueAt);
        expect(shown.scheduledAt, actual);
      }
    });

    test('All-day true midnight derives a timed cutoff without changing raw day', () {
      final rawDay = DateTime.utc(2026, 11, 10);
      final raw = _deadline(rawDay, allDay: true);
      final shown = raw.withDeadlineCutoff(_overnight);
      expect(shown.realDueAt, DateTime.utc(2026, 11, 11));
      expect(shown.dueAt, DateTime.utc(2026, 11, 10, 22));
      expect(shown.scheduledAt, shown.dueAt);
      expect(shown.startsAt, rawDay);
      expect(shown.allDay, isTrue);
      expect(shown.effectiveAllDay, isFalse);
      final restored = shown.withDeadlineCutoff(const DeadlineCutoffWindow());
      expect(restored.realDueAt, shown.realDueAt);
      expect(restored.dueAt, shown.realDueAt);
      expect(restored.scheduledAt, rawDay);
      expect(restored.effectiveAllDay, isTrue);
    });

    test('Unadjusted all-day deadlines keep their original day grouping', () {
      final raw = _deadline(DateTime.utc(2026, 11, 10), allDay: true);
      final outside = raw.withDeadlineCutoff(_daytime);
      expect(outside.hasDeadlineCutoff, isFalse);
      expect(outside.scheduledAt, raw.startsAt);
      expect(outside.effectiveAllDay, isTrue);
      final exactMidnight = raw.withDeadlineCutoff(const DeadlineCutoffWindow(
        enabled: true,
        startMinute: 0,
        endMinute: 0,
      ));
      expect(exactMidnight.hasDeadlineCutoff, isTrue);
      expect(exactMidnight.hasAdjustedDeadline, isFalse);
      expect(exactMidnight.scheduledAt, raw.startsAt);
      expect(exactMidnight.effectiveAllDay, isTrue);
    });

    test('Window changes always derive from real time and never accumulate', () {
      final actual = DateTime.utc(2026, 11, 11, 7);
      final raw = _deadline(actual);
      final first = raw.withDeadlineCutoff(_overnight);
      const changed = DeadlineCutoffWindow(
        enabled: true,
        startMinute: 6 * 60,
        endMinute: 8 * 60,
      );
      final second = first.withDeadlineCutoff(changed);
      expect(second.dueAt, DateTime.utc(2026, 11, 11, 6));
      expect(second.startsAt, actual);
      expect(second.realDueAt, actual);
      expect(second.withDeadlineCutoff(_overnight).dueAt, first.dueAt);
      expect(second.withDeadlineCutoff(_daytime).dueAt, actual);
      final disabled = second.withDeadlineCutoff(changed.copyWith(enabled: false));
      expect(disabled.dueAt, actual);
      expect(disabled.scheduledAt, actual);
      expect(first.withDeadlineCutoff(_overnight), same(first));
    });

    test('Copying completion or deletion preserves the projection and raw JSON', () {
      final raw = _deadline(DateTime.utc(2026, 11, 11, 7), allDay: true);
      final shown = raw.withDeadlineCutoff(_overnight);
      final completed = shown.copyWith(done: true, deleted: true);
      expect(completed.deadlineCutoffWindow, _overnight);
      expect(completed.dueAt, shown.dueAt);
      expect(completed.realDueAt, raw.realDueAt);
      expect(completed.startsAt, raw.startsAt);
      expect(completed.allDay, raw.allDay);
      expect(completed.overdue(DateTime.utc(2030)), isFalse);
      final json = completed.toJson();
      expect(json['startsAt'], raw.startsAt.toIso8601String());
      expect(json['allDay'], isTrue);
      expect(json['done'], isTrue);
      expect(json['deleted'], isTrue);
      expect(json.containsKey('deadlineCutoffWindow'), isFalse);
      expect(json.containsKey('dueAt'), isFalse);
      final restored = AgendaEntry.fromJson(json);
      expect(restored.deadlineCutoffWindow.enabled, isFalse);
      expect(restored.dueAt, raw.realDueAt);
      expect(restored.withDeadlineCutoff(_overnight).dueAt, shown.dueAt);
      expect(restored.done, isTrue);
      expect(restored.deleted, isTrue);
    });

    test('Events, exams and start-only quizzes ignore the cutoff', () {
      final at = DateTime.utc(2026, 11, 11, 7);
      final unaffected = [
        for (final kind in [AgendaKind.event, AgendaKind.exam])
          AgendaEntry(
            id: kind.name,
            title: kind.name,
            kind: kind,
            startsAt: at,
            endsAt: at.add(const Duration(hours: 2)),
          ),
        _deadline(at, startOnly: true),
      ];
      for (final raw in unaffected) {
        final shown = raw.withDeadlineCutoff(_overnight);
        expect(shown.startsAt, raw.startsAt);
        expect(shown.endsAt, raw.endsAt);
        expect(shown.dueAt, raw.realDueAt);
        expect(shown.scheduledAt, raw.startsAt);
        expect(shown.hasDeadlineCutoff, isFalse);
        expect(shown.hasAdjustedDeadline, isFalse);
        final later = DateTime.utc(2030);
        expect(shown.overdue(later), raw.overdue(later));
        expect(shown.overdue(later), raw.kind == AgendaKind.event);
      }
    });
  });
}
