import 'package:bitree/agenda/model.dart';
import 'package:bitree/app/ui/app_screen.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'The complete navigation shell remains usable on a narrow screen with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final schedule = SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 8, 31),
        courses: [
          Course(
            id: 'course',
            name: '概率论与数理统计',
            weekday: 2,
            startSection: 3,
            endSection: 4,
            weeks: [1, 2, 3, 4, 5, 6, 7, 8],
            room: '文萃楼F704',
          ),
        ],
      );
      final controller = TestAppController(
        schedule: schedule,
        initialWeek: 6,
        entries: [
          AgendaEntry(
            id: 'deadline',
            title: '完成概率论章节练习',
            kind: AgendaKind.deadline,
            startsAt: DateTime.utc(2026, 11, 3, 23, 59),
            notes: '提交到乐学平台',
          ),
        ],
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
          home: AppScreen(
            controller: controller,
            updateChecker: (_, {silent = false}) async {},
          ),
        ),
      );
      await tester.pump();

      final navigation = find.byType(NavigationBar);
      for (final label in ['首页', '日程', '工具', '设置']) {
        final destination = find.descendant(
          of: navigation,
          matching: find.text(label),
        );
        expect(destination.hitTestable(), findsOneWidget);
        await tester.tap(destination);
        await tester.pump();
        expect(tester.takeException(), isNull);

        switch (label) {
          case '首页':
            final sync = find.byTooltip('同步').hitTestable();
            expect(sync, findsOneWidget);
            await tester.tap(sync);
            await tester.pumpAndSettle();
            expect(find.text('同步全部').hitTestable(), findsOneWidget);
            expect(find.text('自定义同步').hitTestable(), findsOneWidget);
            expect(find.text('学分进度').hitTestable(), findsNothing);
            await tester.tap(find.byTooltip('同步').hitTestable());
            await tester.pumpAndSettle();
          case '日程':
            final add = find.byTooltip('添加').hitTestable();
            expect(add, findsOneWidget);
            await tester.tap(add);
            await tester.pumpAndSettle();
            expect(find.text('添加日程').hitTestable(), findsOneWidget);
            expect(find.text('添加 DDL').hitTestable(), findsOneWidget);
            await tester.tap(find.byTooltip('添加').hitTestable());
            await tester.pumpAndSettle();
          case '工具':
            expect(find.text('成绩与学业').hitTestable(), findsOneWidget);
          case '设置':
            final settingsList = find.byType(Scrollable).hitTestable().first;
            await tester.scrollUntilVisible(
              find.text('本地日程'),
              240,
              scrollable: settingsList,
            );
            await tester.pumpAndSettle();
            expect(find.text('本地日程').hitTestable(), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('应用'),
              240,
              scrollable: settingsList,
            );
            await tester.pumpAndSettle();
            expect(find.text('应用').hitTestable(), findsOneWidget);
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
