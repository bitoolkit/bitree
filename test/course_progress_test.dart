import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitree/agenda/calendar.dart';
import 'package:bitree/core/time.dart';
import 'package:bitree/schedule/layout.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/section_times.dart';
import 'package:bitree/schedule/selection.dart';
import 'package:bitree/schedule/time_position.dart';
import 'package:bitree/schedule/ui/course_tile.dart';
import 'package:bitree/schedule/ui/current_time_indicator.dart';
import 'package:bitree/schedule/ui/timetable_grid.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

typedef _Pixels = ({ByteData bytes, int width});

Future<_Pixels> _capture(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = (bytes: bytes!, width: image.width);
      image.dispose();
      return result;
    }))!;

Color _atPixel(_Pixels pixels, Offset point) {
  final offset =
      ((point.dy * 2).floor() * pixels.width + (point.dx * 2).floor()) * 4;
  final data = pixels.bytes;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

int _difference(Color a, Color b) => [
  for (final shift in [0, 8, 16])
    (((a.toARGB32() >> shift) & 255) - ((b.toARGB32() >> shift) & 255)).abs(),
].reduce(math.max);

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  final date = DateTime.utc(2026, 10, 27);
  DateTime at(int hour, int minute, [int second = 0]) =>
      date.add(Duration(hours: hour, minutes: minute, seconds: second));
  final occurrence = TimetableSelection(
    date: date,
    startSection: 3,
    endSection: 4,
  );

  test('Progress follows section heights, including breaks, only during this occurrence', () {
    expect(occurrence.progressAt(at(9, 54)), isNull);
    expect(occurrence.progressAt(at(9, 55)), 0);
    expect(occurrence.progressAt(at(10, 10)), closeTo(1 / 6, 0.0001));
    expect(occurrence.progressAt(at(10, 42)), 0.5);
    expect(occurrence.progressAt(at(10, 55)), closeTo(0.5 + 1 / 9, 0.0001));
    expect(occurrence.progressAt(at(11, 28)), closeTo(1 - 1 / 45, 0.0001));
    expect(occurrence.progressAt(at(11, 30)), isNull);
    expect(occurrence.progressAt(at(21, 20)), isNull);
    expect(
      occurrence.progressAt(at(10, 10).add(const Duration(days: 7))),
      isNull,
    );
    expect(
      occurrence.progressAt(at(10, 10).subtract(const Duration(days: 7))),
      isNull,
    );
  });

  test('The line and fill share the same grid-edge clamping', () {
    expect(CurrentTimeIndicator.centerAt(0, 64), 1);
    expect(CurrentTimeIndicator.centerAt(2.5, 64), 160);
    expect(
      CurrentTimeIndicator.centerAt(sectionTimes.length.toDouble(), 64),
      831,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'One full-width line crosses cards and class boundaries in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(414, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final course = Course(
          id: 'probability',
          name: '概率论与数理统计',
          room: '文萃楼F704',
          weekday: 2,
          startSection: 3,
          endSection: 4,
          weeks: [1],
        );
        final other = Course(
          id: 'discrete',
          name: '离散数学',
          room: '文萃楼I501',
          weekday: 1,
          startSection: 3,
          endSection: 4,
          weeks: [1],
        );
        final schedule = SemesterSchedule(
          term: '2026-2027-1',
          firstMonday: mondayOf(date),
          courses: [course, other],
        );
        final controller = TestAppController(schedule: schedule);
        await controller.initialize();
        final time = ValueNotifier(at(9, 54));
        addTearDown(time.dispose);
        final key = GlobalKey();
        final theme = bitreeTheme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: TimetableGrid(
                      timetable: controller.timetable,
                      agenda: controller.agenda,
                      monday: mondayOf(date),
                      layouts: [
                        for (var day = 0; day < 7; day++)
                          groupCalendarItems(
                            calendarItemsOn(
                              mondayOf(date).add(Duration(days: day)),
                              schedule,
                              [],
                            ),
                            mondayOf(date).add(Duration(days: day)),
                          ),
                      ],
                      gutterWidth: 64,
                      rowHeight: 64,
                      todayColumn: 1,
                      todayBackground: Colors.transparent,
                      currentTime: time,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final todayCard = find.byWidgetPredicate(
          (widget) => widget is CourseTile && widget.course.id == course.id,
        );
        final otherCard = find.byWidgetPredicate(
          (widget) => widget is CourseTile && widget.course.id == other.id,
        );
        final card = tester.getRect(todayCard);
        final titleWidth = tester.getSize(find.text(course.name)).width;
        final roomWidth = tester.getSize(find.text(course.room)).width;
        final fill = find.descendant(
          of: todayCard,
          matching: find.byType(FractionallySizedBox),
        );
        final line = find.descendant(
          of: find.byType(CurrentTimeIndicator),
          matching: find.byType(CustomPaint),
        );
        double center() => CurrentTimeIndicator.centerAt(
          timeIndicatorPositionAt(time.value).section,
          64,
        );

        for (final clock in [
          (9, 54, 0),
          (9, 55, 0),
          (9, 56, 0),
          (10, 10, 0),
          (10, 42, 0),
          (10, 55, 0),
          (11, 29, 59),
          (11, 30, 0),
        ]) {
          time.value = at(clock.$1, clock.$2, clock.$3);
          await tester.pump();
          expect(line, findsOneWidget);
          final pixels = await _capture(tester, key);
          expect(
            _atPixel(pixels, Offset(115, center())),
            _atPixel(pixels, Offset(65, center())),
          );
          if (occurrence.progressAt(time.value) != null) {
            final layer = find.descendant(
              of: fill,
              matching: find.byType(ColoredBox),
            );
            expect(
              tester.getRect(layer).bottom,
              closeTo(center().clamp(card.top, card.bottom), 0.001),
            );
          } else {
            expect(fill, findsNothing);
          }
          expect(tester.getSize(find.text(course.name)).width, titleWidth);
          expect(tester.getSize(find.text(course.room)).width, roomWidth);
          expect(tester.getRect(todayCard), card);
          expect(tester.takeException(), isNull);
        }

        time.value = at(10, 55);
        await tester.pump();
        var pixels = await _capture(tester, key);
        for (final day in [0, 2, 3, 4, 5, 6]) {
          final x = 64 + day * 50 + 1.0;
          final background = _atPixel(pixels, Offset(x, center() + 3));
          final expected = Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: .42),
            background,
          );
          expect(
            _difference(_atPixel(pixels, Offset(x, center())), expected),
            lessThanOrEqualTo(3),
          );
          expect(_atPixel(pixels, Offset(x, center() + 1.5)), background);
        }
        final last = _atPixel(pixels, Offset(413, center()));
        expect(last, _atPixel(pixels, Offset(365, center())));
        final previous = tester.getRect(otherCard);
        final onCard = Offset(previous.right - 4, center());
        expect(
          _difference(
            _atPixel(pixels, onCard),
            _atPixel(pixels, onCard + const Offset(0, 3)),
          ),
          greaterThan(1),
        );
        expect(
          _difference(
            _atPixel(pixels, Offset(card.right - 4, center())),
            theme.colorScheme.primary,
          ),
          greaterThan(10),
        );

        time.value = at(9, 56, 45);
        await tester.pump();
        pixels = await _capture(tester, key);
        expect(
          _difference(
            _atPixel(pixels, Offset(card.left + 1.25, center())),
            theme.colorScheme.primary,
          ),
          lessThanOrEqualTo(2),
        );
        expect(
          _difference(
            _atPixel(pixels, Offset(card.center.dx, center())),
            theme.colorScheme.primary,
          ),
          greaterThan(10),
        );

        time.value = at(11, 25);
        await tester.pump();
        pixels = await _capture(tester, key);
        expect(
          _contrast(
            _atPixel(pixels, Offset(card.center.dx, center())),
            _atPixel(pixels, Offset(card.center.dx, center() - 3)),
          ),
          greaterThanOrEqualTo(3),
          reason:
              'The current line stays distinct from the elapsed course fill',
        );

        time.value = at(10, 55);
        await tester.pump();
        await tester.tapAt(Offset(card.center.dx, center()));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(course.name),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();

        final material = tester.widget<Material>(
          find.descendant(of: todayCard, matching: find.byType(Material)).first,
        );
        expect((material.shape! as RoundedRectangleBorder).side.width, 1.5);
        time.value = at(21, 20);
        await tester.pump();
        expect(fill, findsNothing);
        pixels = await _capture(tester, key);
        expect(
          _difference(
            _atPixel(pixels, const Offset(169, 1)),
            theme.colorScheme.primary,
          ),
          lessThanOrEqualTo(2),
        );
        time.value = at(10, 55).add(const Duration(days: 7));
        await tester.pump();
        expect(fill, findsNothing);
        expect(line, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
