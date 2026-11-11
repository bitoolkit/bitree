import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/agenda_list_tile.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/schedule/ui/timetable_header.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _monday = DateTime.utc(2026, 11, 9);
final _tuesday = DateTime.utc(2026, 11, 10);
final _wednesday = DateTime.utc(2026, 11, 11);
final _now = DateTime.utc(2026, 11, 10, 23);
final _l10n = AppLocalizationsZh();
const _overnight = DeadlineCutoffWindow(enabled: true);

AgendaEntry _deadline(
  String id,
  int hour, {
  bool done = false,
  bool deleted = false,
  bool startOnly = false,
}) => AgendaEntry(
  id: id,
  title: '作业 $id',
  kind: AgendaKind.deadline,
  startsAt: _wednesday.add(Duration(hours: hour)),
  done: done,
  deleted: deleted,
  startOnly: startOnly,
);

List<AgendaEntry> _deadlines() => [
  _deadline('morning-07', 7),
  _deadline('morning-08', 8),
  _deadline('midday', 12),
];

/// HomeScreen rebuilds on AgendaController notifications. Keep that same
/// lifecycle here while rendering the real header and opening its real drawer.
Future<TestAppController> _showHeader(
  WidgetTester tester,
  List<AgendaEntry> entries,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final app = TestAppController(
    agenda: AgendaController(MemoryAgendaStore(entries), now: () => _now),
  );
  await app.initialize();
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(Brightness.light),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: app.agenda,
          builder: (context, _) => Column(
            children: [
              TimetableHeader(
                controller: app.agenda,
                monday: _monday,
                now: _now,
                gutterWidth: 40,
                todayBackground: Colors.transparent,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return app;
}

Finder _badges() => find.descendant(
  of: find.byType(TimetableHeader, skipOffstage: false),
  matching: find.byType(Badge, skipOffstage: false),
  skipOffstage: false,
);

void _expectCounts(WidgetTester tester, List<int> expected) {
  final badges = tester.widgetList<Badge>(_badges()).toList();
  expect(badges, hasLength(7));
  expect(expected, hasLength(7));
  for (var index = 0; index < expected.length; index++) {
    expect(
      badges[index].isLabelVisible,
      expected[index] > 0,
      reason: 'Badge visibility for weekday ${index + 1}',
    );
    expect(
      (badges[index].label! as Text).data,
      '${expected[index]}',
      reason: 'Rendered badge count for weekday ${index + 1}',
    );
  }
}

Future<void> _openDay(WidgetTester tester, int weekdayIndex) async {
  await tester.tap(_badges().at(weekdayIndex));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
  expect(tester.takeException(), isNull);
}

List<AgendaListTile> _dayRows(WidgetTester tester) => tester
    .widgetList<AgendaListTile>(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(AgendaListTile),
      ),
    )
    .toList();

Future<void> _closeDay(WidgetTester tester) async {
  await tester.tap(find.byTooltip('关闭'));
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing);
}

void main() {
  testWidgets('Header badges move overnight DDLs and update in place', (
    tester,
  ) async {
    final app = await _showHeader(tester, _deadlines());
    final headerElement = tester.element(find.byType(TimetableHeader));
    _expectCounts(tester, [0, 0, 3, 0, 0, 0, 0]);

    await app.settings.setDeadlineCutoff(_overnight);
    await tester.pumpAndSettle();
    // Both 07:00 and the inclusive 08:00 endpoint become Tuesday 22:00.
    // Wednesday noon is outside the window and stays on Wednesday.
    _expectCounts(tester, [0, 2, 1, 0, 0, 0, 0]);
    expect(tester.element(find.byType(TimetableHeader)), same(headerElement));

    await app.settings.setDeadlineCutoff(
      _overnight.copyWith(endMinute: 7 * 60),
    );
    await tester.pumpAndSettle();
    _expectCounts(tester, [0, 1, 2, 0, 0, 0, 0]);
    expect(tester.element(find.byType(TimetableHeader)), same(headerElement));

    await app.settings.setDeadlineCutoff(
      _overnight.copyWith(enabled: false),
    );
    await tester.pumpAndSettle();
    _expectCounts(tester, [0, 0, 3, 0, 0, 0, 0]);
    expect(tester.element(find.byType(TimetableHeader)), same(headerElement));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Date badges open the same effective-day entries they count', (
    tester,
  ) async {
    final app = await _showHeader(tester, _deadlines());
    await app.settings.setDeadlineCutoff(_overnight);
    await tester.pumpAndSettle();
    _expectCounts(tester, [0, 2, 1, 0, 0, 0, 0]);

    // Drawer membership for DDLs depends on completion, not the real clock
    // used internally by showAgendaDay for its time/status captions.
    await _openDay(tester, 1);
    expect(
      _dayRows(tester).map((row) => row.entry.id),
      unorderedEquals(['morning-07', 'morning-08']),
    );
    expect(find.text(_l10n.agendaCount(2)), findsOneWidget);
    expect(find.text('作业 midday'), findsNothing);
    await _closeDay(tester);

    await _openDay(tester, 2);
    expect(_dayRows(tester).map((row) => row.entry.id), ['midday']);
    expect(find.text(_l10n.agendaCount(1)), findsOneWidget);
    expect(find.text('作业 morning-07'), findsNothing);
    expect(find.text('作业 morning-08'), findsNothing);
    await _closeDay(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Checking a drawer DDL decreases its badge, not merely passing due', (
    tester,
  ) async {
    final app = await _showHeader(tester, _deadlines());
    await app.settings.setDeadlineCutoff(_overnight);
    await tester.pumpAndSettle();
    final projected = app.agenda.entries.firstWhere(
      (entry) => entry.id == 'morning-07',
    );
    expect(projected.dueAt, _tuesday.add(const Duration(hours: 22)));
    expect(projected.overdue(_now), isTrue);
    // An overdue but unfinished DDL must still contribute to the badge.
    _expectCounts(tester, [0, 2, 1, 0, 0, 0, 0]);

    await _openDay(tester, 1);
    final checkbox = find.descendant(
      of: find.byKey(const ValueKey('morning-07')),
      matching: find.byType(Checkbox),
    );
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(
      app.agenda.entries.singleWhere((entry) => entry.id == 'morning-07').done,
      isTrue,
    );
    _expectCounts(tester, [0, 1, 1, 0, 0, 0, 0]);
    expect(_dayRows(tester).map((row) => row.entry.id), ['morning-08']);
    expect(find.text(_l10n.agendaCount(1)), findsOneWidget);
    expect(find.text(_l10n.agendaCompletedCount(1)), findsOneWidget);
    await _closeDay(tester);
    _expectCounts(tester, [0, 1, 1, 0, 0, 0, 0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Only timed DDL badges move; other entries and exclusions persist', (
    tester,
  ) async {
    final entries = [
      _deadline('ordinary-ddl', 7),
      _deadline('open-practice', 7, startOnly: true),
      _deadline('completed-ddl', 7, done: true),
      _deadline('deleted-ddl', 8, deleted: true),
      AgendaEntry(
        id: 'event',
        title: '普通日程',
        kind: AgendaKind.event,
        startsAt: _wednesday.add(const Duration(hours: 7)),
        endsAt: _wednesday.add(const Duration(hours: 9)),
      ),
      AgendaEntry(
        id: 'exam',
        title: '考试',
        kind: AgendaKind.exam,
        startsAt: _wednesday.add(const Duration(hours: 8)),
        endsAt: _wednesday.add(const Duration(hours: 10)),
      ),
    ];
    final app = await _showHeader(tester, entries);
    _expectCounts(tester, [0, 0, 4, 0, 0, 0, 0]);
    await app.settings.setDeadlineCutoff(_overnight);
    await tester.pumpAndSettle();
    _expectCounts(tester, [0, 1, 3, 0, 0, 0, 0]);
    await app.settings.setDeadlineCutoff(_overnight.copyWith(enabled: false));
    await tester.pumpAndSettle();
    _expectCounts(tester, [0, 0, 4, 0, 0, 0, 0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
