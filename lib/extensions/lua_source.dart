import 'dart:convert';
import 'dart:ffi';

import '../core/time.dart';
import '../sources/source.dart';
import 'native_lua.dart';

class LuaSourceError implements Exception {
  const LuaSourceError(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

class LuaSourceCancelled implements Exception {
  const LuaSourceCancelled();
}

typedef LuaHttpHandler = Future<Object?> Function(Map<String, Object?> request);

/// Marker for `json.null`. It cannot be represented by Lua nil inside a table.
class SourceJsonNull {
  const SourceJsonNull._();

  static const instance = SourceJsonNull._();
}

/// Host callbacks available to one source operation. Callbacks are synchronous
/// so the Lua stack never crosses an async Dart callback boundary.
class LuaOperationContext {
  LuaOperationContext({
    this.config = const {},
    this.scope = const {},
    this.source = const {},
    this.locale = 'zh',
    this.baseOperations = const {},
    this.baseSteps = const {},
    this.data = const {},
    Map<String, dynamic>? storage,
    this.isCancelled,
    this.logSink,
    this.httpRequest,
  }) : storage = storage ?? <String, dynamic>{};

  final Map<String, Object?> config;
  final Map<String, Object?> scope;
  final Map<String, Object?> source;
  final String locale;

  /// Base operation name to callback. The callback receives the converted
  /// query table and returns a JSON-compatible Dart value.
  final Map<String, Object? Function(Object? query)> baseOperations;

  /// Original built-in steps exposed as `ctx.base.steps`.
  final Map<String, Object? Function(List<Object?> args)> baseSteps;

  /// Data access exposed as `ctx.data.*`.
  final Map<String, Object? Function(Map<String, Object?> query)> data;

  final Map<String, dynamic> storage;
  final bool Function()? isCancelled;
  final void Function(String level, String message)? logSink;
  final LuaHttpHandler? httpRequest;

  /// Set by [LuaSourceModule.callOperation] so a Dart base operation can call
  /// the merged (possibly overridden) step.
  Object? Function(String name, List<Object?> args)? stepDispatcher;

  LuaOperationContext withHttpRequest(LuaHttpHandler? handler) {
    final context = LuaOperationContext(
      config: config,
      scope: scope,
      source: source,
      locale: locale,
      baseOperations: baseOperations,
      baseSteps: baseSteps,
      data: data,
      storage: storage,
      isCancelled: isCancelled,
      logSink: logSink,
      httpRequest: handler,
    );
    context.stepDispatcher = stepDispatcher;
    return context;
  }
}

/// One compiled source module. The C runtime owns parsing and execution;
/// every operation creates a fresh Lua state.
class LuaSourceModule {
  LuaSourceModule._(
    this._native,
    this._operations,
    this._steps,
    this.fileName,
    this._source,
  );

  factory LuaSourceModule.parse(
    String source, {
    String fileName = '<source>',
    Iterable<SourceOperation> requiredOperations = const [],
  }) {
    if (utf8.encode(source).length > 512 * 1024) {
      throw const FormatException('Lua 来源超过 512 KiB。');
    }
    final native = NativeLuaLibrary.open();
    final inspection = native.inspect(
      source: source,
      fileName: fileName,
      requiredOperations: [
        for (final operation in requiredOperations) operation.wireName,
      ],
    );
    return LuaSourceModule._(
      native,
      {
        for (final operation in SourceOperation.values)
          if (inspection.operations.contains(operation.wireName))
            operation.wireName,
      },
      inspection.steps,
      fileName,
      source,
    );
  }

  final NativeLuaLibrary _native;
  final Set<String> _operations;
  final Set<String> _steps;
  final String fileName;
  final String _source;

  Set<SourceOperation> get operations => {
    for (final operation in SourceOperation.values)
      if (_operations.contains(operation.wireName)) operation,
  };

  Set<String> get overriddenSteps => Set.unmodifiable(_steps);

  bool supports(SourceOperation operation) =>
      _operations.contains(operation.wireName);

  /// Verifies that every overridden step exists in the base implementation.
  void validateSteps(Set<String> baseStepNames) {
    for (final step in _steps) {
      if (!baseStepNames.contains(step)) {
        throw FormatException('内置来源没有步骤 $step，无法覆盖。');
      }
    }
  }

  Future<Object?> callOperation(
    SourceOperation operation,
    LuaOperationContext context, [
    Object? query,
  ]) async {
    if (!supports(operation)) {
      throw LuaSourceError(
        'unknown_operation',
        'Lua 来源未实现 ${operation.wireName}。',
      );
    }
    final previous = context.stepDispatcher;
    context.stepDispatcher = (name, args) => _callStep(context, name, args);
    try {
      final result = await _native.executeAsync(
        source: _source,
        fileName: fileName,
        operation: operation.wireName,
        query: _jsonReady(query ?? const <String, Object?>{}),
        context: {
          'config': _jsonReady(context.config),
          'scope': _jsonReady(context.scope),
          'source': _jsonReady(context.source),
          'locale': context.locale,
          'steps': context.baseSteps.keys.toList(),
          'data': context.data.keys.toList(),
          'storage': _jsonReady(context.storage),
        },
        host: (engine, kind, name, args) =>
            _dispatchHost(engine, context, kind, name, args),
        onYield: (engine, request) =>
            _dispatchAsyncHost(engine, context, request),
      );
      return _fromNative(result);
    } on NativeLuaError catch (failure) {
      if (failure.code == 'cancelled') throw const LuaSourceCancelled();
      throw LuaSourceError(failure.code, failure.message, failure.details);
    } finally {
      context.stepDispatcher = previous;
    }
  }

  Object? _dispatchHost(
    Pointer<Void> engine,
    LuaOperationContext context,
    String kind,
    String? name,
    List<Object?> args,
  ) {
    try {
      switch (kind) {
        case 'base.call':
          final operation = context.baseOperations[name];
          if (operation == null) {
            throw LuaSourceError(
              'unknown_operation',
              '内置来源没有操作 ${name ?? ''}。',
            );
          }
          context.stepDispatcher = (step, arguments) =>
              _callStep(context, step, arguments, engine: engine);
          return _jsonReady(operation(args.isEmpty ? null : args.first));
        case 'step':
          final step = context.baseSteps[name];
          if (step == null) {
            throw LuaSourceError('unknown_step', '内置来源没有步骤 ${name ?? ''}。');
          }
          return _jsonReady(step(args));
        case 'data':
          final access = context.data[name];
          if (access == null) {
            throw LuaSourceError('unknown_data', '宿主没有数据接口 ${name ?? ''}。');
          }
          final raw = args.isEmpty ? const <String, Object?>{} : args.first;
          if (raw is! Map) {
            throw const LuaSourceError('invalid_argument', 'data 查询必须是对象。');
          }
          return _jsonReady(access(Map<String, Object?>.from(raw)));
        case 'storage.get':
          return _jsonReady(context.storage[_stringArg(args)]);
        case 'storage.set':
          final key = _stringArg(args);
          final value = args.length > 1 ? _jsonReady(args[1]) : null;
          final encoded = jsonEncode(value);
          if (utf8.encode(encoded).length > 64 * 1024) {
            throw const LuaSourceError('storage_limit', '来源缓存值超过 64 KiB。');
          }
          context.storage[key] = value;
          return true;
        case 'storage.remove':
          context.storage.remove(_stringArg(args));
          return true;
        case 'log':
          if (args.length < 2 || args[0] is! String || args[1] is! String) {
            throw const LuaSourceError('invalid_argument', '日志参数格式不正确。');
          }
          context.logSink?.call(args[0] as String, args[1] as String);
          return null;
        case 'cancel':
          if (context.isCancelled?.call() ?? false) {
            throw const LuaSourceCancelled();
          }
          return false;
        case 'time.localDateTime':
          final date = _stringValue(args, 0);
          final clock = _stringValue(args, 1);
          final parsed = DateTime.tryParse('${date}T$clock:00Z');
          if (parsed == null ||
              dateText(parsed) != date ||
              clockText(parsed) != clock) {
            throw LuaSourceError('invalid_time', '无效的日期或时间：$date $clock');
          }
          return '${dateText(parsed)}T${clockText(parsed)}:00+08:00';
        case 'time.addDays':
          final parsed = DateTime.tryParse(_stringValue(args, 0));
          if (parsed == null) {
            throw LuaSourceError(
              'invalid_time',
              '无效的日期：${_stringValue(args, 0)}',
            );
          }
          return dateText(parsed.add(Duration(days: _integerValue(args, 1))));
        case 'time.parse':
          final parsed = DateTime.tryParse(_stringValue(args, 0));
          if (parsed == null) {
            throw LuaSourceError(
              'invalid_time',
              '无效的时间：${_stringValue(args, 0)}',
            );
          }
          return parsed.toIso8601String();
        case 'url.parse':
          final uri = Uri.tryParse(_stringValue(args, 0));
          if (uri == null) return null;
          return <String, Object?>{
            'scheme': uri.scheme,
            'host': uri.host,
            'path': uri.path,
            'query': uri.queryParameters,
          };
        case 'url.resolve':
          final base = Uri.tryParse(_stringValue(args, 0));
          final reference = Uri.tryParse(_stringValue(args, 1));
          if (base == null || reference == null) return null;
          return base.resolveUri(reference).toString();
        case 'url.encodeQuery':
          final query = args.isEmpty ? null : args.first;
          if (query is! Map) {
            throw const LuaSourceError('invalid_argument', '查询参数必须是对象。');
          }
          return Uri(
            queryParameters: {
              for (final entry in query.entries)
                '${entry.key}': _queryValue(entry.value),
            },
          ).query;
        case 'encoding.base64Encode':
          final value = args.isEmpty ? null : args.first;
          if (value is List) {
            return base64Encode([for (final item in value) _byteValue(item)]);
          }
          return base64Encode(utf8.encode(_stringValue(args, 0)));
        case 'encoding.base64Decode':
          return base64Decode(_stringValue(args, 0));
        case 'encoding.utf8Encode':
          return utf8.encode(_stringValue(args, 0));
        case 'encoding.utf8Decode':
          final value = args.isEmpty ? null : args.first;
          if (value is! List) {
            throw const LuaSourceError('invalid_bytes', 'utf8Decode 需要字节数组。');
          }
          return utf8.decode([for (final item in value) _byteValue(item)]);
        default:
          throw LuaSourceError('unknown_host_call', '未知的宿主调用：$kind');
      }
    } on LuaSourceError catch (failure) {
      throw NativeLuaError(failure.code, failure.message, failure.details);
    } on LuaSourceCancelled {
      throw const NativeLuaError('cancelled', 'Lua 执行已取消');
    }
  }

  Future<Object?> _dispatchAsyncHost(
    Pointer<Void> engine,
    LuaOperationContext context,
    Map<String, Object?> request,
  ) async {
    if (request['kind'] != 'http.request') {
      throw const NativeLuaError('script_error', '未知的 Lua 异步宿主调用');
    }
    final args = request['args'];
    final raw = args is List && args.isNotEmpty ? args.first : null;
    if (raw is! Map) {
      throw const NativeLuaError('invalid_argument', 'HTTP 请求格式不正确');
    }
    final handler = context.httpRequest;
    if (handler == null) {
      throw const NativeLuaError('permission_denied', '该来源没有网络访问权限');
    }
    try {
      return _jsonReady(await handler(Map<String, Object?>.from(raw)));
    } on LuaSourceCancelled {
      throw const NativeLuaError('cancelled', 'Lua 执行已取消');
    } on LuaSourceError catch (failure) {
      throw NativeLuaError(failure.code, failure.message, failure.details);
    }
  }

  Object? _callStep(
    LuaOperationContext context,
    String name,
    List<Object?> args, {
    Pointer<Void>? engine,
  }) {
    if (engine != null) {
      final result = _native.callStep(engine, name, _jsonReady(args) as List);
      if (result.overridden) return result.value;
    }
    final base = context.baseSteps[name];
    if (base == null) {
      throw LuaSourceError('unknown_step', '内置来源没有步骤 $name。');
    }
    return _jsonReady(base(args));
  }
}

String _stringArg(List<Object?> args) {
  if (args.isEmpty || args.first is! String) {
    throw const LuaSourceError('invalid_argument', '需要文本参数。');
  }
  return args.first as String;
}

String _stringValue(List<Object?> args, int index) {
  if (index >= args.length || args[index] is! String) {
    throw const LuaSourceError('invalid_argument', '需要文本参数。');
  }
  return args[index] as String;
}

int _integerValue(List<Object?> args, int index) {
  if (index >= args.length || args[index] is! num) {
    throw const LuaSourceError('invalid_argument', '需要数值参数。');
  }
  final value = args[index] as num;
  if (!value.isFinite) {
    throw const LuaSourceError('invalid_argument', '数值必须有限。');
  }
  return value.toInt();
}

int _byteValue(Object? value) {
  if (value is int && value >= 0 && value <= 255) return value;
  throw const LuaSourceError('invalid_bytes', '字节值必须在 0–255 之间。');
}

String _queryValue(Object? value) => value is List
    ? value.join(',')
    : value == null
    ? ''
    : '$value';

Object? _fromNative(Object? value) {
  if (value == null) return SourceJsonNull.instance;
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        '${entry.key}': _fromNative(entry.value),
    };
  }
  if (value is List) return [for (final item in value) _fromNative(item)];
  return value;
}

Object? _jsonReady(Object? value) => switch (value) {
  null => null,
  SourceJsonNull() => null,
  final bool value => value,
  final num value when value.isFinite => value,
  final String value => value,
  final DateTime value => value.toIso8601String(),
  final List value => [for (final item in value) _jsonReady(item)],
  final Map value => {
    for (final entry in value.entries) '${entry.key}': _jsonReady(entry.value),
  },
  _ => throw LuaSourceError(
    'invalid_result',
    '不能传给 Lua 的值：${value.runtimeType}',
  ),
};
