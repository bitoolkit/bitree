import 'dart:async';

import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/store.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/ui/app_page.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

class _BlockingScheduleStore extends MemoryScheduleStore {
  _BlockingScheduleStore({required super.selected});

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(ScheduleLibrary library) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(library);
  }
}

void main() {
  testWidgets('The account row never hides sign-out behind an accidental tap', (
    tester,
  ) async {
    final controller = TestAppController(
      schoolStorage: MemorySchoolStorage(
        credentials: const SchoolCredentials(
          username: '1120252797',
          password: 'stored',
        ),
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('1120252797'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('退出学校账号？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Local schedule writes do not disable school account actions', (
    tester,
  ) async {
    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 10, 26),
      courses: const [],
    );
    final store = _BlockingScheduleStore(selected: schedule);
    final controller = TestAppController(
      scheduleStore: store,
      schoolStorage: MemorySchoolStorage(
        credentials: const SchoolCredentials(
          username: '1120252797',
          password: 'stored',
        ),
      ),
    );
    await controller.initialize();
    final save = controller.timetable.setWeekRange(first: 1, last: 16);
    await store.started.future;

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.logout_rounded),
          )
          .onPressed,
      isNotNull,
    );

    store.release.complete();
    await save;
    await tester.pumpAndSettle();
  });

  testWidgets('Local schedule writes do not block school login', (
    tester,
  ) async {
    final schedule = SemesterSchedule(
      term: '2026-2027-1',
      firstMonday: DateTime.utc(2026, 10, 26),
      courses: const [],
    );
    final store = _BlockingScheduleStore(selected: schedule);
    final controller = TestAppController(scheduleStore: store);
    await controller.initialize();
    final save = controller.timetable.setWeekRange(first: 1, last: 16);
    await store.started.future;

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('登录学校账号'));
    await tester.pumpAndSettle();

    expect(find.byType(AppRoutePage), findsOneWidget);
    expect(find.text('学号'), findsOneWidget);

    store.release.complete();
    await save;
    await tester.pumpAndSettle();
  });

  testWidgets('Settings stay usable on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: const [],
      ),
    );
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: SettingsScreen(
            controller: controller,
            checkingForUpdates: false,
            onCheckForUpdates: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in ['本地日程', '应用']) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
