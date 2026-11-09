import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import '../extensions/native_lua.dart';

/// A fresh native Lua state and data copy are created for every invocation.
/// The worker owns no application objects, persistence, or network callbacks.
class LuaFilterExecutor {
  LuaFilterExecutor({this.timeout = const Duration(seconds: 2)});

  static const maxScriptBytes = 128 * 1024;
  final Duration timeout;
  _FilterRun? _active;

  Future<Map<String, dynamic>> run(
    String source,
    Map<String, dynamic> data,
  ) async {
    cancel();
    if (utf8.encode(source).length > maxScriptBytes) {
      throw const FormatException('Lua script exceeds 128 KiB.');
    }
    final cancellation = NativeLuaCancellation();
    final run = _FilterRun(cancellation);
    _active = run;
    final result = Completer<Map<String, dynamic>>();
    final port = ReceivePort();
    Isolate? worker;
    Timer? timer;
    var timedOut = false;
    var finished = false;
    late final StreamSubscription<dynamic> subscription;

    void finish({Map<String, dynamic>? value, Object? error}) {
      if (finished) return;
      finished = true;
      timer?.cancel();
      worker?.kill(priority: Isolate.immediate);
      port.close();
      unawaited(subscription.cancel());
      cancellation.dispose();
      if (identical(_active, run)) _active = null;
      if (error != null) {
        result.completeError(error);
      } else {
        result.complete(value!);
      }
    }

    subscription = port.listen((message) {
      if (message is Map && message['result'] is Map) {
        if (timedOut) {
          finish(error: TimeoutException('Lua filter timed out.'));
        } else {
          finish(value: Map<String, dynamic>.from(message['result'] as Map));
        }
      } else if (message is Map && message['error'] is String) {
        final code = message['code'];
        if (timedOut || code == 'timeout') {
          finish(error: TimeoutException('Lua filter timed out.'));
        } else if (code == 'cancelled') {
          finish(error: const LuaFilterCancelled());
        } else {
          finish(error: FormatException(message['error'] as String));
        }
      } else {
        finish(error: StateError('Lua worker exited unexpectedly: $message'));
      }
    });
    timer = Timer(timeout, () {
      timedOut = true;
      cancellation.cancel();
    });
    unawaited(
      Isolate.spawn(
        _runFilter,
        (
          port.sendPort,
          source,
          data,
          cancellation.address,
          timeout.inMilliseconds,
        ),
        onError: port.sendPort,
        onExit: port.sendPort,
      ).then((isolate) {
        worker = isolate;
        if (finished) isolate.kill(priority: Isolate.immediate);
      }, onError: (Object error) => finish(error: error)),
    );
    return result.future;
  }

  void cancel() {
    _active?.cancellation.cancel();
    _active = null;
  }
}

class _FilterRun {
  const _FilterRun(this.cancellation);

  final NativeLuaCancellation cancellation;
}

class LuaFilterCancelled implements Exception {
  const LuaFilterCancelled();
}

void _runFilter((SendPort, String, Map<String, dynamic>, int, int) message) {
  final (port, source, data, cancelAddress, timeoutMs) = message;
  try {
    final cancellation = NativeLuaCancellation.fromAddress(cancelAddress);
    final value = NativeLuaLibrary.open().executeFilter(
      source: source,
      data: data,
      cancellation: cancellation,
      timeoutMs: timeoutMs,
    );
    if (value is! Map) {
      throw const FormatException('filter(data) must return one table.');
    }
    port.send({'result': _ResultReader(data).read(value)});
  } on NativeLuaError catch (failure) {
    port.send({'error': failure.message, 'code': failure.code});
  } catch (failure) {
    final text = '$failure';
    port.send({
      'error': text.length > 4096 ? text.substring(0, 4096) : text,
      'code': 'script_error',
    });
  }
}

class _ResultReader {
  _ResultReader(this.input);

  final Map<String, dynamic> input;
  final _path = HashSet<Object>.identity();
  var _nodes = 0;

  Map<String, dynamic> read(Map<dynamic, dynamic> value) {
    final output = <String, dynamic>{};
    for (final name in ['courses', 'deadlines', 'events', 'exams']) {
      final present = value.containsKey(name);
      if (!present && (name == 'events' || name == 'exams')) {
        output[name] = input[name] ?? <dynamic>[];
      } else {
        output[name] = list(value[name], name);
      }
    }
    if (utf8.encode(jsonEncode(output)).length > 2 * 1024 * 1024) {
      throw const FormatException('Lua result exceeds 2 MiB.');
    }
    return output;
  }

  void _visit(int depth) {
    if (++_nodes > 100000 || depth > 20) {
      throw const FormatException('Lua result is too large or deeply nested.');
    }
  }

  List<dynamic> list(Object? value, String name, [int depth = 0]) {
    _visit(depth);
    if (value is! List) {
      throw FormatException('$name must be an array table.');
    }
    if (!_path.add(value)) throw const FormatException('Cyclic Lua result.');
    try {
      return [
        for (var index = 0; index < value.length; index++)
          name == 'weeks'
              ? scalar(value[index], depth + 1)
              : record(value[index], '$name[$index]', depth + 1),
      ];
    } finally {
      _path.remove(value);
    }
  }

  Map<String, dynamic> record(Object? value, String name, int depth) {
    _visit(depth);
    if (value is! Map) {
      throw FormatException('$name must be a table.');
    }
    if (!_path.add(value)) throw const FormatException('Cyclic Lua result.');
    try {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw FormatException('$name must have string field names.');
        }
        if (_hostMetadata.contains(key)) continue;
        result[key] = key == 'weeks'
            ? list(entry.value, key, depth + 1)
            : scalar(entry.value, depth + 1);
      }
      return result;
    } finally {
      _path.remove(value);
    }
  }

  Object? scalar(Object? value, int depth) {
    _visit(depth);
    if (value == null || value is bool) return value;
    if (value is String && value.length <= 128 * 1024) return value;
    if (value is num && value.isFinite) {
      return value is double &&
              value == value.truncateToDouble() &&
              value.abs() <= 9007199254740991
          ? value.toInt()
          : value;
    }
    throw const FormatException(
      'Expected a string, finite number, boolean, or nil.',
    );
  }
}

const _hostMetadata = {
  'details',
  'origin',
  'overrides',
  'sourceValues',
  'completionOverride',
  'lastSourceCompletion',
  'sourceRemoved',
};
