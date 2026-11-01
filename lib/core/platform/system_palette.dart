import 'dart:io';

import 'package:flutter/services.dart';

import '../../ui/system_palette.dart';

/// Platform boundary kept injectable for unsupported platforms and tests.
class SystemPaletteSource {
  static const _channel = MethodChannel('dev.so1ve.bitree/theme');
  bool _watching = false;

  Future<SystemPalette?> load() async {
    if (!Platform.isAndroid) return null;
    return SystemPalette.fromPlatform(
      await _channel.invokeMethod<Object?>('getSystemPalette'),
    );
  }

  void watch(VoidCallback onChanged) {
    if (!Platform.isAndroid) return;
    _watching = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') onChanged();
    });
  }

  void dispose() {
    if (_watching) _channel.setMethodCallHandler(null);
  }
}
