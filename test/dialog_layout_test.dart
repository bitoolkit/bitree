import 'dart:math' as math;

import 'package:bitree/agenda/ui/agenda_color_picker.dart';
import 'package:bitree/classrooms/ui/classroom_time_field.dart';
import 'package:bitree/schedule/ui/week_range_dialog.dart';
import 'package:bitree/school/ui/school_verification_dialog.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/ui/app_dialog.dart';
import 'package:bitree/ui/app_pickers.dart';
import 'package:bitree/ui/external_link.dart';
import 'package:bitree/ui/theme.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _surface = find.byWidgetPredicate(
  (widget) => widget is Material && widget.type == MaterialType.card,
);

Future<void> _host(
  WidgetTester tester,
  Size size,
  Widget Function(BuildContext context) child, {
  double textScale = 1,
  TargetPlatform? platform,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: bitreeTheme(brightness).copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: child)),
    ),
  );
}

void _expectDialogSurface(WidgetTester tester, Size size, Finder surface) {
  final material = tester.widget<Material>(surface);
  final context = tester.element(surface);
  expect(tester.getSize(surface).width, math.min(360, size.width - 48));
  expect(material.color, Theme.of(context).colorScheme.surfaceContainerLow);
  expect(material.shape, DialogTheme.of(context).shape);
  expect(ModalRoute.of(context)?.barrierColor, Colors.black54);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final (size, scale, platform) in [
    (const Size(390, 844), 1.0, TargetPlatform.android),
    (const Size(320, 640), 1.8, TargetPlatform.android),
    (const Size(844, 390), 1.0, TargetPlatform.android),
    (const Size(1440, 900), 1.0, TargetPlatform.linux),
  ]) {
    testWidgets('Color picker fits $platform at $size, scale=$scale', (
      tester,
    ) async {
      await _host(
        tester,
        size,
        (context) => TextButton(
          onPressed: () => showAgendaColorPicker(context),
          child: const Text('打开'),
        ),
        textScale: scale,
        platform: platform,
        brightness: platform == TargetPlatform.linux
            ? Brightness.dark
            : Brightness.light,
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final surface = find.ancestor(
        of: find.byType(ColorPicker),
        matching: _surface,
      );
      expect(surface, findsOneWidget);
      _expectDialogSurface(tester, size, surface);
      final dialog = tester.getRect(surface);
      final title = tester.getRect(find.text('选择颜色'));
      expect(title.left - dialog.left, greaterThanOrEqualTo(8));
      expect(title.top - dialog.top, greaterThanOrEqualTo(8));
      final toolbarButton = find
          .descendant(
            of: find.byType(ColorPicker),
            matching: find.byType(IconButton),
          )
          .first;
      expect(
        tester.getRect(toolbarButton).center.dy,
        closeTo(title.center.dy, .01),
      );
      final apply = find.widgetWithText(FilledButton, '应用');
      expect(apply.hitTestable(), findsOneWidget);
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(size.height - 24));
      if (size.height >= 800) {
        final code = tester.getRect(find.byType(ColorCodeField));
        expect(
          tester.getRect(apply).top - code.bottom,
          inInclusiveRange(0, 48),
        );
      }
      await tester.tap(find.text('自定义颜色'));
      await tester.pumpAndSettle();
      expect(find.byType(ColorWheelPicker), findsOneWidget);
      if (platform == TargetPlatform.android && size.height > size.width) {
        const keyboardHeight = 240.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(apply).bottom,
          lessThanOrEqualTo(size.height - keyboardHeight),
        );
      }
      expect(apply.hitTestable(), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    for (final picker in ['date', 'time']) {
      testWidgets('$picker picker uses the shared surface at $size', (
        tester,
      ) async {
        Object? picked;
        await _host(
          tester,
          size,
          (context) => TextButton(
            onPressed: () async {
              if (picker == 'date') {
                picked = await showAppDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 10, 27),
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2027),
                );
              } else {
                picked = await showAppTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 18, minute: 30),
                );
              }
            },
            child: const Text('打开'),
          ),
          brightness: size.width == 1440 ? Brightness.dark : Brightness.light,
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        _expectDialogSurface(tester, size, _surface);
        if (picker == 'time') {
          for (final element in find.byType(Scrollable).evaluate()) {
            final state = (element as StatefulElement).state as ScrollableState;
            if (axisDirectionToAxis(state.widget.axisDirection) ==
                Axis.horizontal) {
              expect(state.position.maxScrollExtent, 0);
            }
          }
        } else {
          await tester.tap(find.text('28').hitTestable());
        }
        final useKeyboard = picker == 'time' && size.width == 390;
        if (useKeyboard) {
          await tester.tap(find.byIcon(Icons.keyboard_outlined));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).last, '45');
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
        }
        final confirm = find.text('OK');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(
          picked,
          picker == 'date'
              ? DateTime(2026, 10, 28)
              : TimeOfDay(hour: 18, minute: useKeyboard ? 45 : 30),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Week management uses the shared dialog at $size', (
      tester,
    ) async {
      ({int first, int last})? saved;
      await _host(
        tester,
        size,
        (context) => TextButton(
          onPressed: () async =>
              saved = await showWeekRangeDialog(context, first: -3, last: 25),
          child: const Text('打开'),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byTooltip('增加一周').first);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(saved, (first: -2, last: 25));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Custom classroom times use the shared dialog at $size', (
      tester,
    ) async {
      ({int start, int end})? selected;
      await _host(
        tester,
        size,
        (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: ClassroomTimeField(
            value: null,
            date: DateTime.utc(2026, 10, 27),
            now: DateTime.utc(2026, 10, 27, 10),
            onChanged: (period) => selected = period,
          ),
        ),
      );
      await tester.tap(find.byType(ClassroomTimeField));
      await tester.pumpAndSettle();
      final custom = find.text('自选课次');
      await tester.ensureVisible(custom);
      await tester.tap(custom);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('第3节'));
      await tester.tap(find.text('第4节'));
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(selected, (start: 3, end: 4));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Confirmations use the shared surface and dismiss on outside tap',
    (tester) async {
      const size = Size(390, 844);
      bool? confirmed;
      await _host(
        tester,
        size,
        (context) => TextButton(
          onPressed: () async => confirmed = await showAppConfirmDialog(
            context,
            title: '确认',
            body: '内容',
            confirmLabel: '确定',
          ),
          child: const Text('提示'),
        ),
      );
      await tester.tap(find.text('提示'));
      await tester.pumpAndSettle();
      _expectDialogSurface(tester, size, _surface);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    },
  );

  testWidgets('School verification uses the shared dialog with large text', (
    tester,
  ) async {
    var sends = 0;
    String? checkedCode;
    String? result;
    await _host(
      tester,
      const Size(320, 640),
      (context) => TextButton(
        onPressed: () async {
          result = await verifySchoolLogin(
            context,
            SchoolSmsVerification(
              phone: '138****0000',
              sendCode: () async {
                sends++;
                return const Duration(seconds: 60);
              },
              submitCode: (code) async {
                checkedCode = code;
              },
            ),
          );
        },
        child: const Text('开始验证'),
      ),
      textScale: 1.8,
    );
    await tester.tap(find.text('开始验证'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sends, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('短信验证'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(checkedCode, '1234');
    expect(result, '1234');
    expect(tester.takeException(), isNull);
  });

  testWidgets('External link failures use a recoverable dialog', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await _host(
      tester,
      const Size(390, 844),
      (context) => TextButton(
        onPressed: () => openExternalLink(
          context,
          Uri.parse('https://example.com'),
          failureTitle: '无法打开链接',
        ),
        child: const Text('打开链接'),
      ),
    );

    await tester.tap(find.text('打开链接'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('无法打开链接'), findsOneWidget);
    expect(find.textContaining('https://example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
