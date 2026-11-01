import 'dart:async';

import '../core/async/cancelable_request.dart';
import '../core/diagnostics.dart';
import 'errors.dart';
import 'network.dart';
import 'session.dart';
import 'storage.dart';

/// Selects a reachable route for one operation and owns all of its connections.
class SchoolConnection {
  SchoolConnection(this._storage);

  final SchoolStorage _storage;
  final _sessions = <SchoolSession>{};
  final _cancellation = CancellationToken();
  static const _probeTimeout = Duration(seconds: 8);

  Future<T> run<T>(
    Uri service,
    Future<T> Function(SchoolSession) operation,
  ) async {
    try {
      final networks = {
        SchoolNetwork.campus,
        if (SchoolNetwork.webvpn.route(service) != service)
          SchoolNetwork.webvpn,
      };
      final parallel = networks.length > 1;
      if (parallel) {
        AppDiagnostics.instance.info(
          '学校请求并行探测校内直连和 WebVPN：${service.origin}${service.path}',
        );
      }
      var session = networks.length == 1
          ? _open(networks.single)
          : await _connect(service, networks);
      var reason = parallel ? '并行探测胜出' : '该服务直接访问，无需 WebVPN';
      while (true) {
        _cancellation.check();
        networks.remove(session.network);
        final url = session.network.route(service);
        AppDiagnostics.instance.info(
          '学校请求使用${session.network.label}（$reason）：${url.origin}${url.path}',
        );
        try {
          final result = await operation(session);
          _cancellation.check();
          return result;
        } on SchoolConnectionError catch (failure) {
          _cancellation.check();
          if (networks.isEmpty) rethrow;
          _close(session);
          final next = networks.single;
          AppDiagnostics.instance.info(
            '${session.network.label}连接失败，改用${next.label}：'
            '${failure.url.origin}${failure.url.path}（${failure.cause}）',
          );
          reason = '${session.network.label}连接失败后切换';
          session = _open(next);
        }
      }
    } finally {
      close();
    }
  }

  Future<SchoolSession> _connect(
    Uri service,
    Set<SchoolNetwork> networks,
  ) async {
    final ready = Completer<SchoolSession>();
    final sessions = [for (final network in networks) _open(network)];
    var pending = sessions.length;
    final detach = _cancellation.onCancel(() {
      if (!ready.isCompleted) {
        ready.completeError(const RequestCancelled());
      }
    });

    Future<void> probe(SchoolSession session) async {
      final url = session.network.route(service);
      try {
        // Probe only the service entry, without cookies, redirects or login.
        await session
            .request(url, followRedirects: false, anonymous: true)
            .timeout(_probeTimeout);
        _cancellation.check();
        if (!ready.isCompleted) ready.complete(session);
      } on Exception catch (failure, stack) {
        _close(session);
        pending--;
        if (!ready.isCompleted) {
          AppDiagnostics.instance.info(
            '${session.network.label}探测失败：${url.origin}${url.path} '
            '（$failure）',
          );
          if (pending == 0) {
            ready.completeError(
              failure is TimeoutException
                  ? SchoolConnectionError(url, failure)
                  : failure,
              stack,
            );
          }
        }
      }
    }

    for (final session in sessions) {
      unawaited(probe(session));
    }
    SchoolSession? selected;
    try {
      selected = await ready.future;
      return selected;
    } finally {
      detach();
      for (final session in sessions) {
        if (session != selected) _close(session);
      }
    }
  }

  SchoolSession _open(SchoolNetwork network) {
    _cancellation.check();
    final session = SchoolSession(network: network, storage: _storage);
    _sessions.add(session);
    return session;
  }

  void _close(SchoolSession session) {
    if (_sessions.remove(session)) session.close();
  }

  void close() {
    _cancellation.cancel();
    for (final session in _sessions.toList()) {
      _close(session);
    }
  }
}
