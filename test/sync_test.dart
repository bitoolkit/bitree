import 'dart:async';
import 'dart:io';

import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/l10n/app_localizations_zh.dart';
import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/school/service.dart';
import 'package:bitree/school/session.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/sync/controller.dart';
import 'package:bitree/sync/ui/sync.dart';
import 'package:bitree/sync/ui/sync_button.dart';
import 'package:bitree/sync/ui/sync_text.dart';
import 'package:bitree/ui/selection_controls.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

class _SchoolService extends SchoolService {
  final began = Completer<void>();
  final release = Completer<void>();
  final reads = <SyncTarget>[];
  bool smsRequired = false;
  @override
  Future<({SemesterSchedule schedule, List<String> terms})> synchronize(
    SchoolSession session, {
    required String account,
    String? term,
  }) async {
    reads.add(SyncTarget.schedule);
    if (!began.isCompleted) began.complete();
    await release.future;
    if (smsRequired) {
      throw const SchoolVerificationRequired(SchoolVerificationKind.sms);
    }
    final selected = term ?? '2026-2027-1';
    return (
      schedule: SemesterSchedule(
        term: selected,
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: [
          Course(
            id: 'lab',
            name: '大物实验',
            room: '物理实验306',
            weekday: 1,
            startSection: 1,
            endSection: 2,
            weeks: [1],
          ),
        ],
      ),
      terms: [selected],
    );
  }

  @override
  Future<({String term, List<AgendaEntry> exams})> exams(
    SchoolSession session, {
    required String account,
    String? term,
  }) async {
    reads.add(SyncTarget.exams);
    return (term: term ?? '2026-2027-1', exams: <AgendaEntry>[]);
  }
}

class _SlowAgendaStore extends MemoryAgendaStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(List<AgendaEntry> entries) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.write(entries);
  }
}

void main() {
  final l10n = AppLocalizationsZh();
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late HttpServer server;
  HttpOverrides? previous;
  var moocRequests = 0;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('bitree-sync-tests-');
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
  });
  tearDownAll(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  setUp(() async {
    moocRequests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path.startsWith('/www.icourse163.org/')) {
        moocRequests++;
        return;
      }
      request.response.write('ok');
      await request.response.close();
    });
    previous = HttpOverrides.current;
    HttpOverrides.global = LocalHttpOverrides(server.port);
  });
  tearDown(() async {
    HttpOverrides.global = previous;
    await server.close(force: true);
  });

  TestAppController app(_SchoolService service, {bool mooc = false}) =>
      TestAppController(
        school: service,
        schoolStorage: MemorySchoolStorage(
          credentials: const SchoolCredentials(
            username: 'student',
            password: 'test',
          ),
        ),
        moocStorage: mooc
            ? (MemoryMoocStorage()
                ..account = MoocAccount(
                  id: '8',
                  name: '测试账号',
                  credentials: MoocCredentials(
                    userAgent: 'test',
                    cookies: [Cookie('NTESSTUDYSI', 'csrf')],
                  ),
                ))
            : null,
      );

  test('Sync targets keep session dependencies separate from UI groups', () {
    expect(
      {
        for (final target in SyncTarget.values)
          target: (
            category: target.category,
            usesSchoolSession: target.usesSchoolSession,
          ),
      },
      {
        SyncTarget.schedule: (
          category: SyncCategory.schoolData,
          usesSchoolSession: true,
        ),
        SyncTarget.exams: (
          category: SyncCategory.schoolData,
          usesSchoolSession: true,
        ),
        SyncTarget.grades: (
          category: SyncCategory.schoolData,
          usesSchoolSession: true,
        ),
        SyncTarget.studyPlan: (
          category: SyncCategory.schoolData,
          usesSchoolSession: true,
        ),
        SyncTarget.lexue: (
          category: SyncCategory.deadlineData,
          usesSchoolSession: true,
        ),
        SyncTarget.eclass: (
          category: SyncCategory.deadlineData,
          usesSchoolSession: true,
        ),
        SyncTarget.mooc: (
          category: SyncCategory.deadlineData,
          usesSchoolSession: false,
        ),
        SyncTarget.physicsLab: (
          category: SyncCategory.deadlineData,
          usesSchoolSession: false,
        ),
      },
    );
  });

  test('One round shares repeated starts, preserves its semester and generates labs after timetable import', () async {
    final service = _SchoolService();
    final model = app(service);
    await model.initialize();
    expect(model.sync.defaultTargets, isNot(contains(SyncTarget.mooc)));
    final selected = {
      SyncTarget.schedule,
      SyncTarget.exams,
      SyncTarget.physicsLab,
    };
    final syncing = model.sync.synchronize(
      selected,
      term: '2025-2026-1',
      l10n: l10n,
    );
    expect(
      model.sync.synchronize(selected, term: '2025-2026-1', l10n: l10n),
      same(syncing),
    );
    await service.began.future;
    expect(service.reads, [SyncTarget.schedule]);
    expect(model.agenda.entries, isEmpty);
    service.release.complete();
    expect(await syncing, isTrue);
    expect(model.timetable.schedule!.term, '2025-2026-1');
    expect(model.agenda.entries, hasLength(2));
    expect(model.sync.results.keys.toSet(), selected);
    expect(model.sync.incompleteTargets, isEmpty);
  });

  test('Cancelling a round stops running and unstarted content', () async {
    final service = _SchoolService();
    final model = app(service);
    await model.initialize();
    final syncing = model.sync.synchronize({
      SyncTarget.schedule,
      SyncTarget.exams,
    }, l10n: l10n);
    await service.began.future;
    model.sync.cancel();
    service.release.complete();
    expect(await syncing, isFalse);
    expect(service.reads, [SyncTarget.schedule]);
    expect(
      model.sync.results.values.map((result) => result.outcome),
      everyElement(SyncOutcome.cancelled),
    );
    expect(model.timetable.schedule, isNull);
  });

  test('Cancelling while waiting for an unrelated school query leaves that query intact', () async {
    final service = _SchoolService();
    final model = app(service);
    await model.initialize();
    final entered = Completer<void>();
    final answer = Completer<int>();
    final query = model.school.read('查询', (_) {
      entered.complete();
      return answer.future;
    }, verify: (_) async => null);
    await entered.future;
    final syncing = model.sync.synchronize({SyncTarget.schedule}, l10n: l10n);
    model.sync.cancel();
    expect(await syncing, isFalse);
    expect(model.school.busy, isTrue);
    answer.complete(7);
    expect(await query, 7);
    expect(service.reads, isEmpty);
  });

  test('Verification ends the affected reads, then one retry handles only incomplete content', () async {
    final service = _SchoolService()..smsRequired = true;
    service.release.complete();
    final model = app(service);
    await model.initialize();
    expect(
      await model.sync.synchronize({
        SyncTarget.schedule,
        SyncTarget.exams,
      }, l10n: l10n),
      isFalse,
    );
    expect(
      model.sync.results.values.map((result) => result.outcome),
      everyElement(SyncOutcome.needsVerification),
    );
    expect(service.reads, [SyncTarget.schedule]);
    service.smsRequired = false;
    await model.school.read(
      '手动验证',
      (_) async => true,
      verify: (_) async => null,
    );
    expect(
      await model.sync.synchronize(model.sync.incompleteTargets, l10n: l10n),
      isTrue,
    );
    expect(service.reads, [
      SyncTarget.schedule,
      SyncTarget.schedule,
      SyncTarget.exams,
    ]);
  });

  test('MOOC login failures identify the MOOC account', () async {
    final model = app(_SchoolService());
    await model.initialize();

    expect(
      await model.sync.synchronize({SyncTarget.mooc}, l10n: l10n),
      isFalse,
    );
    expect(
      model.sync.results[SyncTarget.mooc]?.outcome,
      SyncOutcome.needsLogin,
    );
    expect(
      syncProgressText(l10n, model.sync, SyncTarget.mooc),
      '需要登录中国大学MOOC账号',
    );
  });

  test('Concurrent imports preserve both platforms and do not save a cancelled waiting result', () async {
    final store = _SlowAgendaStore();
    final agenda = AgendaController(store);
    addTearDown(agenda.dispose);
    await agenda.load();
    AgendaEntry entry(String id) => AgendaEntry(
      id: id,
      title: id,
      kind: AgendaKind.deadline,
      startsAt: DateTime.utc(2026, 11),
    );
    final first = agenda.mergeDeadlines([entry('school')]);
    await store.started.future;
    final second = agenda.mergeDeadlines([entry('mooc')]);
    final token = CancellationToken();
    final cancelled = expectLater(
      agenda.mergeDeadlines([entry('cancelled')], checkActive: token.check),
      throwsA(isA<RequestCancelled>()),
    );
    token.cancel();
    store.release.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    await cancelled;
    expect(store.entries.map((entry) => entry.id), ['school', 'mooc']);
  });

  test(
    'A local edit queues behind an import instead of being dropped',
    () async {
      final store = _SlowAgendaStore();
      final agenda = AgendaController(store);
      addTearDown(agenda.dispose);
      await agenda.load();
      AgendaEntry entry(String id) => AgendaEntry(
        id: id,
        title: id,
        kind: AgendaKind.deadline,
        startsAt: DateTime.utc(2026, 11),
      );

      final imported = agenda.mergeDeadlines([entry('school')]);
      await store.started.future;
      final edited = agenda.save(entry('local'));
      store.release.complete();

      expect(await imported, isTrue);
      expect(await edited, isTrue);
      expect(store.entries.map((entry) => entry.id), ['school', 'local']);
    },
  );

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    final elapsed = Stopwatch()..start();
    while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(ready(), isTrue);
  }

  Future<void> openCustom(WidgetTester tester) async {
    await tester.tap(find.byTooltip('同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pump();
  }

  testWidgets(
    'Default sync includes all available sources without presenting progress or requesting MOOC login',
    (tester) async {
      final service = _SchoolService();
      final model = app(service);
      await model.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(body: SyncButton(controller: model)),
        ),
      );
      await tester.tap(find.byTooltip('同步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同步全部'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(tester, () => service.began.isCompleted);
      expect(model.sync.targets.toSet(), model.sync.defaultTargets);
      expect(find.byType(BottomSheet), findsNothing);
      expect(moocRequests, 0);
      model.sync.cancel();
      service.release.complete();
      await waitFor(tester, () => !model.sync.busy);
    },
  );

  testWidgets(
    'Custom sync groups sources semantically and shares all and clear controls',
    (tester) async {
      final model = app(_SchoolService());
      await model.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Scaffold(body: SyncButton(controller: model)),
        ),
      );

      await tester.tap(find.byTooltip('同步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义同步'));
      await tester.pumpAndSettle();

      expect(find.text('学校数据'), findsOneWidget);
      expect(find.text('DDL 与课业'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('学校数据')).dy,
        lessThan(tester.getTopLeft(find.text('DDL 与课业')).dy),
      );
      expect(find.widgetWithText(AppSelectionButton, '课表'), findsOneWidget);
      expect(find.widgetWithText(AppSelectionButton, '乐学 DDL'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pump();
      expect(
        tester
            .widgetList<AppSelectionButton>(find.byType(AppSelectionButton))
            .every((button) => !button.selected),
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '同步所选内容'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        tester
            .widgetList<AppSelectionButton>(find.byType(AppSelectionButton))
            .every((button) => button.selected),
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '同步所选内容'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Custom sync stays active after progress is collapsed and the page changes',
    (tester) async {
      final service = _SchoolService();
      final model = app(service);
      await model.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: bitreeTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(actions: [SyncButton(controller: model)]),
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        Scaffold(appBar: AppBar(title: const Text('其他页面'))),
                  ),
                ),
                child: const Text('切换页面'),
              ),
            ),
          ),
        ),
      );
      await openCustom(tester);
      await tester.tap(find.widgetWithText(AppSelectionButton, '课表'));
      await tester.pump();
      await tester.tap(find.text('同步所选内容'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(tester, () => service.began.isCompleted);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byTooltip('查看同步进度'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('收起'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(model.sync.busy, isTrue);
      await tester.tap(find.text('切换页面'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      service.release.complete();
      await waitFor(tester, () => !model.sync.busy);
      expect(model.timetable.schedule, isNotNull);
      expect(find.text('其他页面'), findsOneWidget);
      expect(find.text('同步完成'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Retry keeps the explicitly selected historical semester', (
    tester,
  ) async {
    final service = _SchoolService()..smsRequired = true;
    service.release.complete();
    final model = app(service);
    await model.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => startSync(
                context,
                model,
                targets: {SyncTarget.schedule},
                term: '2025-2026-1',
              ),
              child: const Text('同步历史学期'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('同步历史学期'));
    await tester.pump();
    await waitFor(tester, () => !model.sync.busy);
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.text('2025-2026-1'), findsOneWidget);
    service.smsRequired = false;
    final verification = model.school.read(
      '手动验证',
      (_) async => true,
      verify: (_) async => null,
    );
    await waitFor(tester, () => !model.school.busy);
    expect(await verification, isTrue);
    await tester.tap(find.text('重试未完成的内容'));
    await tester.pump();
    await waitFor(tester, () => !model.sync.busy);
    expect(model.timetable.schedule!.term, '2025-2026-1');
    expect(model.sync.incompleteTargets, isEmpty);
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Custom and progress sheets fit a narrow $brightness screen and cancel school and MOOC together',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _SchoolService();
        final model = app(service, mooc: true);
        await model.initialize();
        await tester.pumpWidget(
          MaterialApp(
            theme: bitreeTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!,
            ),
            home: Scaffold(body: SyncButton(controller: model)),
          ),
        );
        await openCustom(tester);
        for (final title in ['课表', '考试安排', '中国大学MOOC DDL']) {
          final choice = find.widgetWithText(AppSelectionButton, title);
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pump();
        }
        await tester.tap(find.text('同步所选内容'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await waitFor(
          tester,
          () => moocRequests > 0 && service.began.isCompleted,
        );
        expect(model.sync.isRunning(SyncTarget.schedule), isTrue);
        expect(model.sync.isRunning(SyncTarget.mooc), isTrue);
        expect(service.reads, [SyncTarget.schedule]);
        await tester.tap(find.byTooltip('查看同步进度'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('同步进度'), findsOneWidget);
        expect(find.text('取消全部'), findsNothing);
        expect(find.byTooltip('添加同步任务'), findsNothing);
        await tester.tap(find.text('取消同步'));
        service.release.complete();
        await waitFor(tester, () => !model.sync.busy);
        expect(find.text('同步已取消'), findsOneWidget);
        expect(model.timetable.schedule, isNull);
        expect(service.reads, [SyncTarget.schedule]);
        await tester.tap(find.text('收起'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
