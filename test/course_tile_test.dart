import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/agenda/ui/calendar_block.dart';
import 'package:bitree/core/time.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/section_times.dart';
import 'package:bitree/schedule/ui/course_colors.dart';
import 'package:bitree/schedule/ui/course_tile.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

// Rendering the card never calls the controller; opening details is separate.
void main() {
  final course = Course(
    id: 'course',
    name: '概率论与数理统计',
    room: '物理实验楼309-310',
    weekday: DateTime.monday,
    startSection: 3,
    endSection: 4,
    weeks: [1],
  );

  Future<void> showCard(
    WidgetTester tester, {
    required double width,
    required double height,
    double scale = 1,
    bool bold = false,
    Course? shownCourse,
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale), boldText: bold),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: CourseTile(
                  course: shownCourse ?? course,
                  controller: TestAppController(),
                  isToday: false,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void expectFullText(WidgetTester tester) {
    final card = tester.getRect(find.byType(CourseTile));
    for (final text in [course.name, course.room]) {
      final finder = find.text(text);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      expect(tester.getRect(finder).bottom, lessThanOrEqualTo(card.bottom - 6));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('All today courses keep their outline regardless of class time', (
    tester,
  ) async {
    final today = calendarDate(campusNow());
    for (final brightness in Brightness.values) {
      for (final dayOffset in [0, 7]) {
        for (final section in [1, sectionTimes.length]) {
          final date = today.add(Duration(days: dayOffset));
          final shownCourse = Course(
            id: 'section-$section',
            name: '数据结构',
            room: '综教B103',
            weekday: date.weekday,
            startSection: section,
            endSection: section,
            weeks: [1],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: bitreeTheme(brightness),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 70,
                    height: 160,
                    child: CalendarBlockTile(
                      items: [CalendarItem.course(shownCourse, date)],
                      controller: TestAppController(),
                      isToday: dayOffset == 0,
                    ),
                  ),
                ),
              ),
            ),
          );
          final tile = find.byType(CourseTile);
          final material = tester.widget<Material>(
            find.descendant(of: tile, matching: find.byType(Material)).first,
          );
          final side = (material.shape! as RoundedRectangleBorder).side;
          if (dayOffset == 0) {
            expect(side.style, BorderStyle.solid);
            expect(side.width, 1.5);
            expect(
              side.color,
              courseColors(tester.element(tile), shownCourse).accent,
            );
          } else {
            expect(side, BorderSide.none);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('Narrow cards show all wrapped text when it fits', (
    tester,
  ) async {
    await showCard(tester, width: 52, height: 180);
    expectFullText(tester);
    expect(tester.getSize(find.text(course.name)).height, greaterThan(20));
    expect(tester.getSize(find.text(course.room)).height, greaterThan(20));
  });

  testWidgets('Text reflows after resizing and accessibility changes', (
    tester,
  ) async {
    await showCard(tester, width: 42, height: 360);
    expectFullText(tester);
    await showCard(tester, width: 86, height: 360, scale: 1.6, bold: true);
    expectFullText(tester);
    await showCard(tester, width: 52, height: 180);
    expectFullText(tester);
  });

  testWidgets('Two-section cards retain the room below a three-line title', (
    tester,
  ) async {
    final probability = Course(
      id: 'probability',
      name: '概率论与数理统计',
      room: '文萃楼F704',
      weekday: DateTime.monday,
      startSection: 3,
      endSection: 4,
      weeks: [1],
    );
    await showCard(tester, width: 52, height: 92, shownCourse: probability);
    for (final text in [probability.name, probability.room]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      expect(
        tester.getRect(find.text(text)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(CourseTile)).bottom),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Short cards ellipsize without overflowing', (tester) async {
    await showCard(tester, width: 52, height: 48);
    final title = tester.renderObject<RenderParagraph>(find.text(course.name));
    expect(title.didExceedMaxLines, isTrue);
    final card = tester.getRect(find.byType(CourseTile));
    expect(
      tester.getRect(find.text(course.room)).bottom,
      lessThanOrEqualTo(card.bottom - 6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Course cards follow the building after renaming and moving', (
    tester,
  ) async {
    Course at(String name, String room) => Course(
      id: 'moved-course',
      name: name,
      room: room,
      campus: '良乡校区',
      weekday: 1,
      startSection: 3,
      endSection: 4,
      weeks: [1],
    );
    Color? fill() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(CourseTile),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    for (final brightness in Brightness.values) {
      await showCard(
        tester,
        width: 70,
        height: 210,
        brightness: brightness,
        shownCourse: at('数据结构', '文萃F704'),
      );
      final original = fill();
      await showCard(
        tester,
        width: 70,
        height: 210,
        brightness: brightness,
        shownCourse: at('高等数学', '文萃楼F705'),
      );
      expect(fill(), original);
      await showCard(
        tester,
        width: 70,
        height: 210,
        brightness: brightness,
        shownCourse: at('高等数学', '理教105'),
      );
      expect(fill(), isNot(original));
      expect(tester.takeException(), isNull);
    }
  });
}
