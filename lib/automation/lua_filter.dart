import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import 'package:puredartlua/lua/visitors/bindings/std.dart';
import 'package:puredartlua/lua/visitors/runtime/base.dart';
import 'package:puredartlua/runner.dart' as lua;

/// A new runtime and data copy are created for every invocation. The worker owns
/// no application objects, persistence, file loader, or network callbacks.
class LuaFilterExecutor {
  LuaFilterExecutor({this.timeout = const Duration(seconds: 2)});

  static const maxScriptBytes = 128 * 1024;
  final Duration timeout;
  void Function()? _cancel;

  Future<Map<String, dynamic>> run(
    String source,
    Map<String, dynamic> data,
  ) async {
    cancel();
    if (utf8.encode(source).length > maxScriptBytes) {
      throw const FormatException('Lua script exceeds 128 KiB.');
    }
    final result = Completer<Map<String, dynamic>>();
    final port = ReceivePort();
    Isolate? worker;
    Timer? timer;
    late final StreamSubscription<dynamic> subscription;
    void finish({Map<String, dynamic>? value, Object? error}) {
      if (result.isCompleted) return;
      timer?.cancel();
      worker?.kill(priority: Isolate.immediate);
      port.close();
      unawaited(subscription.cancel());
      if (error != null) {
        result.completeError(error);
      } else {
        result.complete(value!);
      }
    }

    void cancelRun() => finish(error: const LuaFilterCancelled());
    _cancel = cancelRun;
    subscription = port.listen((message) {
      if (message is Map && message['result'] is Map) {
        finish(value: Map<String, dynamic>.from(message['result'] as Map));
      } else if (message is Map && message['error'] is String) {
        finish(error: FormatException(message['error'] as String));
      } else {
        finish(error: StateError('Lua worker exited unexpectedly: $message'));
      }
    });
    timer = Timer(
      timeout,
      () => finish(error: TimeoutException('Lua filter timed out.')),
    );
    // Do not await spawn before listening: parse/runtime errors and very short
    // scripts may finish before the spawn Future completes.
    unawaited(
      Isolate.spawn(
        _runFilter,
        (port.sendPort, source, data),
        onError: port.sendPort,
        onExit: port.sendPort,
      ).then((isolate) {
        worker = isolate;
        if (result.isCompleted) isolate.kill(priority: Isolate.immediate);
      }, onError: (Object error) => finish(error: error)),
    );
    try {
      return await result.future;
    } finally {
      if (identical(_cancel, cancelRun)) _cancel = null;
    }
  }

  void cancel() {
    _cancel?.call();
    _cancel = null;
  }
}

class LuaFilterCancelled implements Exception {
  const LuaFilterCancelled();
}

void _runFilter((SendPort, String, Map<String, dynamic>) message) {
  final (port, source, data) = message;
  try {
    final errors = <String>[];
    final ast = lua.parse(source, onErrors: errors.addAll);
    if (ast == null) throw FormatException(errors.join('\n'));
    final runtime = _FilterRuntime();
    runtime.visitAST(ast);
    if (runtime.results.errors.isNotEmpty) {
      throw FormatException(runtime.results.errors.join('\n'));
    }
    final filter = runtime.findVar('filter');
    if (filter == null || !filter.isFunc) {
      throw const FormatException(
        'Define function filter(data) and return data.',
      );
    }
    final values = runtime.callLuaFunction(
      filter,
      args: [_toLua('data', data)],
    );
    if (runtime.results.errors.isNotEmpty) {
      throw FormatException(runtime.results.errors.join('\n'));
    }
    if (values.length != 1 || !values.single.isTable) {
      throw const FormatException('filter(data) must return one table.');
    }
    final output = values.single;
    final reader = _ResultReader();
    final result = <String, dynamic>{
      for (final name in ['courses', 'deadlines'])
        name: reader.list(output.readField(name) as lua.LuaObject?, name),
    };
    if (utf8.encode(jsonEncode(result)).length > 2 * 1024 * 1024) {
      throw const FormatException('Lua result exceeds 2 MiB.');
    }
    port.send({'result': result});
  } catch (error) {
    final text = error.toString();
    port.send({'error': text.length > 4096 ? text.substring(0, 4096) : text});
  }
}

/// Register data-processing primitives only. In particular, never register
/// require/include, file APIs, coroutines, or application callbacks.
class _FilterRuntime extends BaseRuntime with Std, ReturnStmtCallStackUnwind {
  _FilterRuntime() : super(lua.StdRuntimeResults()) {
    initStdMetatables();
    initStdStrings();
    initStdIPairs();
    initStdPairs();
    initStdNext();
    initStdTable();
    initStdMath();
    initMiscRuntime();
    initStdPrint(impl: (_) {});
  }
}

lua.LuaObject _toLua(String name, Object? value) => switch (value) {
  final Map map => lua.LuaObject.table(name, {
    for (final entry in map.entries)
      entry.key as String: _toLua(entry.key as String, entry.value),
  }),
  final List list => lua.LuaObject.table(name, {
    for (var i = 0; i < list.length; i++) i + 1: _toLua('$i', list[i]),
  }),
  _ => lua.LuaObject.variable(name, value),
};

class _ResultReader {
  final _path = HashSet<lua.LuaObject>.identity();
  var _nodes = 0;

  void _visit(int depth) {
    if (++_nodes > 100000 || depth > 20) {
      throw const FormatException('Lua result is too large or deeply nested.');
    }
  }

  List<dynamic> list(lua.LuaObject? value, String name, [int depth = 0]) {
    _visit(depth);
    if (value == null || !value.isTable) {
      throw FormatException('$name must be an array table.');
    }
    final table = value.deref();
    if (!_path.add(table)) throw const FormatException('Cyclic Lua result.');
    try {
      final fields = table.fields!;
      if (fields.keys.any(
        (key) => key is! int || key < 1 || key > fields.length,
      )) {
        throw FormatException(
          '$name must use consecutive indices starting at 1.',
        );
      }
      return [
        for (var i = 1; i <= fields.length; i++)
          name == 'weeks'
              ? scalar(fields[i], depth + 1)
              : record(fields[i], '$name[$i]', depth + 1),
      ];
    } finally {
      _path.remove(table);
    }
  }

  Map<String, dynamic> record(lua.LuaObject? value, String name, int depth) {
    _visit(depth);
    if (value == null || !value.isTable) {
      throw FormatException('$name must be a table.');
    }
    final table = value.deref();
    if (!_path.add(table)) throw const FormatException('Cyclic Lua result.');
    try {
      final result = <String, dynamic>{};
      for (final entry in table.fields!.entries) {
        final key = entry.key;
        if (key is! String) {
          throw FormatException('$name must have string field names.');
        }
        // Details are immutable host metadata and are not decoded from Lua.
        if (key == 'details') continue;
        result[key] = key == 'weeks'
            ? list(entry.value, key, depth + 1)
            : scalar(entry.value, depth + 1);
      }
      return result;
    } finally {
      _path.remove(table);
    }
  }

  Object? scalar(lua.LuaObject? value, int depth) {
    _visit(depth);
    if (value == null || value.isNil) return null;
    if (!value.isTable && !value.isFunc && !value.isThread) {
      final raw = value.value;
      if (raw is String && raw.length <= 128 * 1024 ||
          raw is bool ||
          raw is num && raw.isFinite) {
        return raw;
      }
    }
    throw const FormatException(
      'Expected a string, finite number, boolean, or nil.',
    );
  }
}
