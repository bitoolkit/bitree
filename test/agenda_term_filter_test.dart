import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/period.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/agenda/view_mode.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/l10n/schedule.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

final _now = DateTime.utc(2026, 11, 3, 12);
final _currentSchedule = SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: DateTime.utc(2026, 8, 31),
  courses: const [],
  firstWeek: 1,
  lastWeek: 20,
);
final _pastSchedule = SemesterSchedule(
  term: '2025-2026-2',
  firstMonday: DateTime.utc(2026, 2, 23),
  courses: const [],
  firstWeek: 1,
  lastWeek: 20,
);

AgendaEntry _event({
  required String id,
  required String title,
  required DateTime startsAt,
  String? term,
}) => AgendaEntry(
  id: id,
  title: title,
  kind: AgendaKind.event,
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(hours: 1)),
  term: term,
);

Future<void> _pumpAgenda(
  WidgetTester tester,
  List<AgendaEntry> entries, {
  Size size = const Size(390, 844),
  double scale = 1,
  AgendaViewMode viewMode = AgendaViewMode.list,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = TestAppController(
    schedule: _currentSchedule,
    schedules: [_currentSchedule, _pastSchedule],
    entries: entries,
  );
  await controller.initialize();
  await controller.settings.setAgendaViewMode(viewMode);

  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: CalendarScreen(controller: controller, now: _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAgendaMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppLocalizationsZh().more));
  await tester.pumpAndSettle();
}

void main() {
  test('Entries without a stored term use the saved semester dates', () {
    final inferred = _event(
      id: 'inferred',
      title: '历史学期活动',
      startsAt: DateTime.utc(2026, 3, 14, 10),
    );
    expect(
      agendaEntryMatchesTerm(inferred, _pastSchedule.term, [
        _currentSchedule,
        _pastSchedule,
      ]),
      isTrue,
    );
    expect(
      agendaEntryMatchesTerm(inferred, _currentSchedule.term, [
        _currentSchedule,
        _pastSchedule,
      ]),
      isFalse,
    );
  });

  testWidgets('The current semester is selected by default and terms switch', (
    tester,
  ) async {
    final l10n = AppLocalizationsZh();
    final current = _event(
      id: 'current',
      title: '本学期活动',
      startsAt: DateTime.utc(2026, 11, 5, 10),
      term: _currentSchedule.term,
    );
    final past = _event(
      id: 'past',
      title: '历史学期活动',
      startsAt: DateTime.utc(2026, 11, 5, 11),
      term: _pastSchedule.term,
    );
    final allOnly = _event(
      id: 'all-only',
      title: '未归属活动',
      startsAt: DateTime.utc(2030, 11, 5, 12),
    );
    await _pumpAgenda(tester, [current, past, allOnly]);

    expect(find.byTooltip(l10n.more), findsOneWidget);
    expect(find.text(l10n.agendaPendingTab(1)), findsOneWidget);
    expect(find.text(current.title), findsWidgets);
    expect(find.text(past.title), findsNothing);
    expect(find.text(allOnly.title), findsNothing);

    final pastTerm = find.text(localizedTerm(l10n, _pastSchedule.term));
    await _openAgendaMenu(tester);
    await tester.tap(pastTerm.last);
    await tester.pumpAndSettle();
    expect(find.text(current.title), findsNothing);
    expect(find.text(past.title), findsWidgets);
    expect(find.text(allOnly.title), findsNothing);

    final allTerms = find.text(l10n.allSemesters);
    await _openAgendaMenu(tester);
    await tester.tap(allTerms.last);
    await tester.pumpAndSettle();
    expect(find.text(current.title), findsWidgets);
    expect(find.text(past.title), findsWidgets);
    expect(find.text(allOnly.title), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'The period dropdown remains usable on a narrow large-text layout',
    (tester) async {
      final l10n = AppLocalizationsZh();
      await _pumpAgenda(
        tester,
        [
          _event(
            id: 'current',
            title: '本学期活动',
            startsAt: DateTime.utc(2026, 11, 5, 10),
            term: _currentSchedule.term,
          ),
        ],
        size: const Size(320, 640),
        scale: 1.8,
      );

      expect(find.byTooltip(l10n.more).hitTestable(), findsOneWidget);
      await _openAgendaMenu(tester);
      expect(
        find.text(localizedTerm(l10n, _pastSchedule.term)),
        findsOneWidget,
      );
      expect(find.text('本学期活动'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Completion status is only shown in list mode', (tester) async {
    await _pumpAgenda(tester, [
      _event(
        id: 'current',
        title: '本学期活动',
        startsAt: DateTime.utc(2026, 11, 5, 10),
        term: _currentSchedule.term,
      ),
    ], viewMode: AgendaViewMode.timeline);

    expect(find.byType(SegmentedButton<int>), findsNothing);
    await _openAgendaMenu(tester);
    expect(find.text(AppLocalizationsZh().agendaSwitchToList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
