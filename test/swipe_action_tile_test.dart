import 'dart:async';
import 'dart:ui' as ui;

import 'package:bitree/ui/swipe_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/row_swipe.dart';

void main() {
  Future<void> showTile(
    WidgetTester tester,
    Future<bool> Function() invoke, {
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('scene'),
            child: Center(
              child: SizedBox(
                width: 390,
                child: SwipeActionTile(
                  enabled: enabled,
                  leftAction: TileSwipeAction(
                    label: '完成',
                    releaseLabel: '松手完成',
                    icon: Icons.check,
                    background: Colors.green,
                    foreground: Colors.white,
                    onInvoke: invoke,
                  ),
                  rightAction: TileSwipeAction(
                    label: '删除',
                    releaseLabel: '松手删除',
                    icon: Icons.delete_outline,
                    background: Colors.red,
                    foreground: Colors.white,
                    onInvoke: invoke,
                  ),
                  child: const SizedBox(
                    key: ValueKey('content'),
                    width: double.infinity,
                    height: 96,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Text('第三章实验报告'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Swiped content stays inside the row in both directions', (
    tester,
  ) async {
    await showTile(tester, () async => false);
    final content = find.byKey(const ValueKey('content'));
    final bounds = tester.getRect(find.byType(SwipeActionTile));
    for (final distance in [-120.0, 120.0]) {
      final gesture = await startRowSwipe(
        tester,
        content,
        Offset(distance.sign * 24 + distance, 0),
      );
      expect(
        tester.getRect(content).left,
        distance < 0 ? lessThan(bounds.left) : greaterThan(bounds.left),
      );
      await tester.runAsync(() async {
        final scene = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('scene')),
        );
        final image = await scene.toImage();
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        Color pixelAt(Offset point) {
          final local = scene.globalToLocal(point);
          final offset =
              (local.dy.floor() * image.width + local.dx.floor()) * 4;
          return Color.fromARGB(
            pixels.getUint8(offset + 3),
            pixels.getUint8(offset),
            pixels.getUint8(offset + 1),
            pixels.getUint8(offset + 2),
          );
        }

        final outsideLeft = pixelAt(Offset(bounds.left - 8, bounds.center.dy));
        final outsideRight = pixelAt(
          Offset(bounds.right + 8, bounds.center.dy),
        );
        final inside = pixelAt(bounds.center);
        image.dispose();
        expect(outsideLeft, Colors.transparent);
        expect(outsideRight, Colors.transparent);
        expect(inside.toARGB32(), Colors.blue.toARGB32());
      });
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getRect(content), bounds);
    }
  });

  testWidgets(
    'A committed swipe continues offscreen and failure restores its size and position',
    (tester) async {
      final saved = Completer<bool>();
      var calls = 0;
      await showTile(tester, () {
        calls++;
        return saved.future;
      });
      final content = find.byKey(const ValueKey('content'));
      final before = tester.getRect(content);
      await swipeRow(tester, content, const Offset(-250, 0));
      await tester.pump();
      final released = tester.getRect(content);
      expect(released.left, lessThan(before.left));
      expect(released.height, before.height);
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(content).left, lessThan(released.left));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.getRect(content).right, lessThanOrEqualTo(before.left));
      saved.complete(false);
      await tester.pumpAndSettle();
      expect(tester.getRect(content), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A short swipe returns without invoking the action', (
    tester,
  ) async {
    var calls = 0;
    await showTile(tester, () async {
      calls++;
      return false;
    });
    final content = find.byKey(const ValueKey('content'));
    final before = tester.getRect(content);
    await swipeRow(tester, content, const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getRect(content), before);
  });

  testWidgets(
    'A short swipe docks at the button, and tapping outside closes it',
    (tester) async {
      var calls = 0;
      await showTile(tester, () async {
        calls++;
        return false;
      });
      final content = find.byKey(const ValueKey('content'));
      final before = tester.getRect(content);
      await swipeRow(tester, content, const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(content).left, closeTo(before.left + 80, 1));
      expect(find.text('删除'), findsOneWidget);
      expect(calls, 0);
      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();
      expect(tester.getRect(content), before);
      expect(find.text('删除'), findsNothing);
    },
  );

  testWidgets(
    'Dragging an open row continues at its current offset and can commit',
    (tester) async {
      var calls = 0;
      await showTile(tester, () async {
        calls++;
        return false;
      });
      final content = find.byKey(const ValueKey('content'));
      final before = tester.getRect(content);
      await swipeRow(tester, content, const Offset(80, 0));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(content));
      await gesture.moveBy(
        const Offset(24, 0),
        timeStamp: const Duration(milliseconds: 30),
      );
      await tester.pump();
      expect(tester.getRect(content).left, closeTo(before.left + 104, 1));
      await gesture.moveBy(
        const Offset(140, 0),
        timeStamp: const Duration(milliseconds: 160),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.getRect(content), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancelling a committed drag restores it without an action', (
    tester,
  ) async {
    var calls = 0;
    await showTile(tester, () async {
      calls++;
      return false;
    });
    final content = find.byKey(const ValueKey('content'));
    final before = tester.getRect(content);
    final gesture = await startRowSwipe(tester, content, const Offset(250, 0));
    expect(find.text('松手删除'), findsOneWidget);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getRect(content), before);
  });

  testWidgets('Dragging back below the threshold cancels the action', (
    tester,
  ) async {
    var calls = 0;
    await showTile(tester, () async {
      calls++;
      return false;
    });
    final content = find.byKey(const ValueKey('content'));
    final before = tester.getRect(content);
    final gesture = await startRowSwipe(tester, content, const Offset(-250, 0));
    expect(find.text('松手完成'), findsOneWidget);
    await gesture.moveBy(
      const Offset(220, 0),
      timeStamp: const Duration(milliseconds: 600),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getRect(content), before);
  });

  testWidgets('Disabling an active row cancels and restores its drag', (
    tester,
  ) async {
    var calls = 0;
    Future<bool> invoke() async {
      calls++;
      return false;
    }

    await showTile(tester, invoke);
    final content = find.byKey(const ValueKey('content'));
    final before = tester.getRect(content);
    final gesture = await startRowSwipe(tester, content, const Offset(-250, 0));
    await showTile(tester, invoke, enabled: false);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.getRect(content), before);
    expect(tester.takeException(), isNull);
  });
}
