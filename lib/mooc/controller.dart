import 'dart:async';

import 'package:flutter/foundation.dart';

import '../agenda/controller.dart';
import '../core/async/cancelable_request.dart';
import '../core/async/serial_queue.dart';
import '../core/diagnostics.dart';
import 'api.dart';
import 'credentials.dart';
import 'errors.dart';
import 'progress.dart';
import 'storage.dart';

enum MoocStatus { connected, signedOut, expired }

class MoocController extends ChangeNotifier {
  MoocController({required this._storage, required this._agenda});

  final MoocStorage _storage;
  final AgendaController _agenda;
  MoocAccount? _account;
  CancellationToken? _request;
  Future<void>? _finished;
  final _lifecycle = SerialQueue();
  int _pendingLifecycle = 0;
  bool _disposed = false;
  bool _expired = false;
  MoocFailure? _error;
  MoocProgress? _progress;

  MoocAccount? get account => _account;
  bool get busy => _request != null || _pendingLifecycle > 0;
  bool get needsLogin => _account == null || _expired;
  MoocFailure? get error => _error;
  MoocProgress? get progress => _progress;
  MoocStatus get status => _expired
      ? MoocStatus.expired
      : _account == null
      ? MoocStatus.signedOut
      : MoocStatus.connected;

  Future<void> load() => _queue(() async {
    try {
      _account = await _storage.read();
      _error = null;
    } on Exception catch (error, stack) {
      _error = const MoocFailure.issue(MoocIssue.readAccountFailed);
      AppDiagnostics.instance.error('读取 MOOC 账号', error, stack);
    }
  });

  Future<void> connect(MoocAccount account) => _queue(
    () => _run('登录 MOOC', (token) async {
      token.check();
      await _storage.write(account);
      _account = account;
      _expired = false;
    }),
  );

  Future<MoocImportResult?> synchronize() async {
    final account = _account;
    if (account == null) throw const MoocLoginRequired();
    if (busy) throw const MoocFailure.issue(MoocIssue.requestBusy);
    return _run('更新 MOOC DDL', (token) async {
      final api = MoocApi(account.credentials, token);
      try {
        final result = await api.readDeadlines(account.id, (progress) {
          _progress = progress;
          _notify();
        });
        token.check();
        final next = MoocAccount(
          id: account.id,
          name: account.name,
          credentials: await api.credentials(),
        );
        token.check();
        await _storage.write(next);
        _account = next;
        _expired = false;
        if (!await _agenda.mergeDeadlines(
          result.entries,
          checkActive: token.check,
        )) {
          _error = const MoocFailure.issue(MoocIssue.saveResultFailed);
          return null;
        }
        return result;
      } finally {
        api.close();
      }
    });
  }

  Future<T> _run<T>(
    String label,
    Future<T> Function(CancellationToken) operation,
  ) async {
    if (_request != null || _disposed) {
      throw const MoocFailure.issue(MoocIssue.requestBusy);
    }
    final token = CancellationToken();
    final finished = Completer<void>();
    _request = token;
    _finished = finished.future;
    _error = null;
    _notify();
    try {
      return await operation(token);
    } on RequestCancelled {
      rethrow;
    } on Exception catch (error, stack) {
      if (error is MoocLoginRequired) _expired = _account != null;
      _error = switch (error) {
        MoocFailure() => error,
        FormatException(:final message) => MoocFailure(message),
        _ => MoocFailure('$label失败，请重试或查看日志。'),
      };
      AppDiagnostics.instance.error(label, error, stack);
      rethrow;
    } finally {
      _request = null;
      _finished = null;
      _progress = null;
      finished.complete();
      _notify();
    }
  }

  void cancel() => _request?.cancel();

  Future<void> disconnect() => _queue(() async {
    final finished = _finished;
    cancel();
    await finished;
    await _storage.clear();
    _account = null;
    _expired = false;
    _error = null;
  });

  Future<T> _queue<T>(Future<T> Function() operation) {
    if (_disposed) {
      throw const MoocFailure('MOOC 状态已关闭。');
    }
    _pendingLifecycle++;
    _notify();
    return _lifecycle.run(operation).whenComplete(() {
      _pendingLifecycle--;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
