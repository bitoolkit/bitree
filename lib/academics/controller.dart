import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import 'model.dart';
import 'store.dart';

class AcademicController extends ChangeNotifier {
  AcademicController(this._store);

  final AcademicStore _store;
  final _loads = LatestRequest();
  String? _account;
  AcademicRecord _record = const AcademicRecord();
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  Completer<void>? _writeFinished;

  bool get ready => _ready;
  bool get busy => _busy;

  AcademicRecord get record => _record;

  Future<void> load(String? account) async {
    try {
      await _loads.run((cancellation) async {
        await _writeFinished?.future;
        cancellation.check();
        _account = account;
        _record = const AcademicRecord();
        _ready = false;
        _notify();
        try {
          final record = account == null
              ? const AcademicRecord()
              : await _store.read(account);
          cancellation.check();
          _record = record;
          _ready = true;
        } on RequestCancelled {
          rethrow;
        } on Exception catch (failure, stack) {
          AppDiagnostics.instance.report('读取学业数据', failure, stack);
        } finally {
          if (!cancellation.isCancelled) _notify();
        }
      });
    } on RequestCancelled {
      // A newer account load owns the visible state.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loads.cancel();
    super.dispose();
  }

  Future<bool> save(AcademicRecord next) async {
    if (_disposed) return false;
    if (_busy || !_ready || _account == null) {
      AppDiagnostics.instance.notice(
        _busy ? '学业数据正在保存，请稍后重试。' : '请先登录并重新读取学业数据。',
      );
      return false;
    }
    final finished = Completer<void>();
    _writeFinished = finished;
    _busy = true;
    _notify();
    try {
      await _store.write(_account!, next);
      _record = next;
      return true;
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.report('保存学业数据', failure, stack);
      return false;
    } finally {
      _busy = false;
      _writeFinished = null;
      finished.complete();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
