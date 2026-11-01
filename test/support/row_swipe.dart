import 'package:flutter_test/flutter_test.dart';

Future<TestGesture> startRowSwipe(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await gesture.moveBy(
    Offset(offset.dx.sign * 24, 0),
    timeStamp: const Duration(milliseconds: 40),
  );
  await tester.pump();
  await gesture.moveBy(
    offset - Offset(offset.dx.sign * 24, 0),
    timeStamp: const Duration(milliseconds: 160),
  );
  await tester.pump();
  return gesture;
}

Future<void> swipeRow(WidgetTester tester, Finder finder, Offset offset) async {
  final gesture = await startRowSwipe(tester, finder, offset);
  await gesture.up(timeStamp: const Duration(milliseconds: 240));
}
