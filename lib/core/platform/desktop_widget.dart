import 'dart:io';

import 'package:flutter/services.dart';

import '../async/serial_queue.dart';
import '../diagnostics.dart';
import '../storage/json_file.dart';

/// Refreshes the native widget without making a failed refresh fail a save.
/// Supply course colour maps to persist palettes, or empty maps to restore
/// native default colours. Content-only refreshes leave appearance unchanged.
Future<void> updateDesktopWidget({
  Map<String, List<int>>? lightCourseColors,
  Map<String, List<int>>? darkCourseColors,
  bool? useSystemPalette,
}) async {
  if (!Platform.isAndroid) return;
  try {
    await const MethodChannel('dev.so1ve.bitree/widget').invokeMethod<void>(
      'update',
      lightCourseColors == null &&
              darkCourseColors == null &&
              useSystemPalette == null
          ? null
          : {
              'lightCourseColors': ?lightCourseColors,
              'darkCourseColors': ?darkCourseColors,
              'useSystemPalette': ?useSystemPalette,
            },
    );
  } catch (failure, stack) {
    AppDiagnostics.instance.report('更新桌面组件', failure, stack);
  }
}

final _widgetWrites = SerialQueue();

/// Rebuilds the widget's display JSON from the current presentation.
Future<void> publishDesktopWidgetData(Map<String, dynamic> data) async {
  if (!Platform.isAndroid) return;
  try {
    await _widgetWrites.run(() async {
      await const JsonFile('widget.json').write(data);
      await updateDesktopWidget();
    });
  } catch (failure, stack) {
    AppDiagnostics.instance.report('更新桌面组件展示', failure, stack);
  }
}
