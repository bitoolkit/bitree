import 'dart:convert';
import 'dart:io';

import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/timetable.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
    final flutter = packages.cast<Map>().firstWhere(
      (item) => item['name'] == 'flutter',
    );
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final font = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
  });

  testWidgets('A near-fitting timetable compresses instead of scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 660);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = TestAppController(
      schedule: SemesterSchedule(
        term: '2026-2027-1',
        firstMonday: DateTime.utc(2026, 10, 26),
        courses: const [],
      ),
      initialWeek: 1,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: bitreeTheme(Brightness.light).copyWith(
          textTheme: bitreeTheme(Brightness.light).textTheme
              .apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(
          body: Timetable(
            controller: controller,
            week: 1,
            initialScrollOffset: 0,
            onScroll: (_) {},
            active: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(Timetable),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });
}
