import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Camera requests remain separate from selecting an object on the map.
class WencuiMapController extends ChangeNotifier {
  Rect? _focus;

  Rect? get focus => _focus;

  void show(Rect? bounds) {
    _focus = bounds;
    notifyListeners();
  }
}
