import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:bitree_lua/native_lua_bindings.dart';
import 'package:ffi/ffi.dart';

class NativeLuaError implements Exception {
  const NativeLuaError(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}

typedef NativeLuaHostHandler = Object? Function(
  Pointer<Void> engine,
  String kind,
  String? name,
  List<Object?> arguments,
);

typedef NativeLuaAsyncHostHandler = Future<Object?> Function(
  Pointer<Void> engine,
  Map<String, Object?> request,
);

class NativeLuaInspection {
  const NativeLuaInspection({required this.operations, required this.steps});

  final Set<String> operations;
  final Set<String> steps;
}

class NativeLuaStepResult {
  const NativeLuaStepResult.handled(this.value) : overridden = true;
  const NativeLuaStepResult.notOverridden() : overridden = false, value = null;

  final bool overridden;
  final Object? value;
}

/// One process-wide cancellation flag shared with the native instruction hook.
class NativeLuaCancellation {
  NativeLuaCancellation() : _pointer = calloc<Int32>(), _owned = true {
    _pointer.value = 0;
  }

  NativeLuaCancellation.fromAddress(int address)
    : _pointer = Pointer<Int32>.fromAddress(address),
      _owned = false;

  final Pointer<Int32> _pointer;
  final bool _owned;
  var _disposed = false;

  Pointer<Int32> get pointer => _pointer;

  int get address => _pointer.address;

  void cancel() {
    if (!_disposed) _pointer.value = 1;
  }

  void dispose() {
    if (_disposed || !_owned) return;
    _disposed = true;
    calloc.free(_pointer);
  }
}

/// Thin Dart boundary over C Lua 5.5.1. JSON is the only value protocol; no
/// Lua object, callback, or state pointer escapes the active native call.
class NativeLuaLibrary {
  NativeLuaLibrary._();

  static final _shared = NativeLuaLibrary._();

  factory NativeLuaLibrary.open() => _shared;

  NativeLuaInspection inspect({
    required String source,
    required String fileName,
    Iterable<String> requiredOperations = const [],
    Iterable<String> baseSteps = const [],
    int timeoutMs = 2000,
  }) {
    final sourcePointer = source.toNativeUtf8(allocator: malloc);
    final fileNamePointer = fileName.toNativeUtf8(allocator: malloc);
    final operationsPointer = jsonEncode(requiredOperations.toList())
        .toNativeUtf8(allocator: malloc);
    final stepsPointer = jsonEncode(baseSteps.toList())
        .toNativeUtf8(allocator: malloc);
    final infoPointer = calloc<Pointer<Utf8>>();
    final errorPointer = calloc<Pointer<Utf8>>();
    try {
      final status = bitreeLuaInspect(
        sourcePointer,
        fileNamePointer,
        operationsPointer,
        stepsPointer,
        timeoutMs,
        infoPointer,
        errorPointer,
      );
      final info = _readAndFree(infoPointer.value);
      final error = _readAndFree(errorPointer.value);
      if (status != 0) _throwError(error);
      final decoded = _decodeJson(info);
      if (decoded is! Map) {
        throw const NativeLuaError('script_error', 'Lua 检查结果必须是对象');
      }
      return NativeLuaInspection(
        operations: _strings(decoded['operations']),
        steps: _strings(decoded['steps']),
      );
    } finally {
      malloc.free(sourcePointer);
      malloc.free(fileNamePointer);
      malloc.free(operationsPointer);
      malloc.free(stepsPointer);
      calloc.free(infoPointer);
      calloc.free(errorPointer);
    }
  }

  Future<Object?> executeAsync({
    required String source,
    required String fileName,
    required String operation,
    required Object? query,
    required Map<String, Object?> context,
    required NativeLuaHostHandler host,
    required NativeLuaAsyncHostHandler onYield,
    NativeLuaCancellation? cancellation,
    int timeoutMs = 5000,
  }) async {
    final sourcePointer = source.toNativeUtf8(allocator: malloc);
    final fileNamePointer = fileName.toNativeUtf8(allocator: malloc);
    final operationPointer = operation.toNativeUtf8(allocator: malloc);
    final queryPointer = jsonEncode(query).toNativeUtf8(allocator: malloc);
    final contextPointer = jsonEncode(_wireValue(context))
        .toNativeUtf8(allocator: malloc);
    final executionPointer = calloc<Pointer<Void>>();
    final yieldPointer = calloc<Pointer<Utf8>>();
    final resultPointer = calloc<Pointer<Utf8>>();
    final errorPointer = calloc<Pointer<Utf8>>();
    int dispatchHost(
      Pointer<Void> engine,
      Pointer<Utf8> request,
      Pointer<Pointer<Utf8>> result,
      Pointer<Pointer<Utf8>> error,
    ) => _dispatchHost(engine, request, result, error, host);
    final callback = NativeCallable<BitreeLuaHostCallbackNative>.isolateLocal(
      dispatchHost,
      exceptionalReturn: 1,
    );
    final timeout = Duration(milliseconds: timeoutMs);
    final deadline = DateTime.now().add(timeout);
    try {
      var status = bitreeLuaExecuteStart(
        sourcePointer,
        fileNamePointer,
        operationPointer,
        queryPointer,
        contextPointer,
        callback.nativeFunction,
        cancellation?.pointer ?? nullptr.cast<Int32>(),
        timeoutMs,
        executionPointer,
        yieldPointer,
        resultPointer,
        errorPointer,
      );
      while (true) {
        final yielded = _readAndFree(yieldPointer.value);
        final result = _readAndFree(resultPointer.value);
        final error = _readAndFree(errorPointer.value);
        if (status == 2) {
          final decoded = _decodeJson(yielded);
          if (decoded is! Map) {
            throw const NativeLuaError('script_error', 'Lua 异步请求格式不正确');
          }
          final request = Map<String, Object?>.from(decoded);
          String? failureJson;
          Object? value;
          try {
            final remaining = deadline.difference(DateTime.now());
            if (remaining <= Duration.zero) {
              throw TimeoutException('Lua 宿主调用超时');
            }
            value = await onYield(
              executionPointer.value,
              request,
            ).timeout(remaining);
          } on TimeoutException {
            failureJson = jsonEncode({
              'code': 'timeout',
              'message': 'Lua 宿主调用超时',
              'details': null,
            });
          } on NativeLuaError catch (failure) {
            failureJson = jsonEncode({
              'code': failure.code,
              'message': failure.message,
              'details': failure.details,
            });
          } catch (failure) {
            failureJson = jsonEncode({
              'code': 'script_error',
              'message': '$failure',
              'details': null,
            });
          }
          final valuePointer = failureJson != null
              ? nullptr.cast<Utf8>()
              : jsonEncode(_wireValue(value)).toNativeUtf8(allocator: malloc);
          final failurePointer = failureJson == null
              ? nullptr.cast<Utf8>()
              : failureJson.toNativeUtf8(allocator: malloc);
          try {
            status = bitreeLuaExecuteResume(
              executionPointer.value,
              valuePointer,
              failurePointer,
              yieldPointer,
              resultPointer,
              errorPointer,
            );
          } finally {
            if (valuePointer != nullptr) malloc.free(valuePointer);
            if (failurePointer != nullptr) malloc.free(failurePointer);
          }
          continue;
        }
        if (status == 0) return _decodeJson(result);
        _throwError(error);
      }
    } finally {
      if (executionPointer.value != nullptr) {
        bitreeLuaExecutionFree(executionPointer.value);
      }
      callback.close();
      malloc.free(sourcePointer);
      malloc.free(fileNamePointer);
      malloc.free(operationPointer);
      malloc.free(queryPointer);
      malloc.free(contextPointer);
      calloc.free(executionPointer);
      calloc.free(yieldPointer);
      calloc.free(resultPointer);
      calloc.free(errorPointer);
    }
  }

  Object? executeFilter({
    required String source,
    required Map<String, dynamic> data,
    String fileName = '<automation>',
    NativeLuaCancellation? cancellation,
    int timeoutMs = 2000,
  }) {
    final sourcePointer = source.toNativeUtf8(allocator: malloc);
    final fileNamePointer = fileName.toNativeUtf8(allocator: malloc);
    final dataPointer = jsonEncode(data).toNativeUtf8(allocator: malloc);
    final resultPointer = calloc<Pointer<Utf8>>();
    final errorPointer = calloc<Pointer<Utf8>>();
    try {
      final status = bitreeLuaFilter(
        sourcePointer,
        fileNamePointer,
        dataPointer,
        cancellation?.pointer ?? nullptr.cast<Int32>(),
        timeoutMs,
        resultPointer,
        errorPointer,
      );
      final result = _readAndFree(resultPointer.value);
      final error = _readAndFree(errorPointer.value);
      if (status != 0) _throwError(error);
      return _decodeJson(result);
    } finally {
      malloc.free(sourcePointer);
      malloc.free(fileNamePointer);
      malloc.free(dataPointer);
      calloc.free(resultPointer);
      calloc.free(errorPointer);
    }
  }

  NativeLuaStepResult callStep(
    Pointer<Void> engine,
    String name,
    List<Object?> arguments,
  ) {
    final namePointer = name.toNativeUtf8(allocator: malloc);
    final argumentsPointer = jsonEncode(_wireValue(arguments))
        .toNativeUtf8(allocator: malloc);
    final resultPointer = calloc<Pointer<Utf8>>();
    final errorPointer = calloc<Pointer<Utf8>>();
    try {
      final status = bitreeLuaCallStep(
        engine,
        namePointer,
        argumentsPointer,
        resultPointer,
        errorPointer,
      );
      final result = _readAndFree(resultPointer.value);
      final error = _readAndFree(errorPointer.value);
      if (status == 2) return const NativeLuaStepResult.notOverridden();
      if (status != 0) _throwError(error);
      return NativeLuaStepResult.handled(_decodeJson(result));
    } finally {
      malloc.free(namePointer);
      malloc.free(argumentsPointer);
      calloc.free(resultPointer);
      calloc.free(errorPointer);
    }
  }

  int _dispatchHost(
    Pointer<Void> engine,
    Pointer<Utf8> request,
    Pointer<Pointer<Utf8>> result,
    Pointer<Pointer<Utf8>> error,
    NativeLuaHostHandler handler,
  ) {
    try {
      final decoded = jsonDecode(request.toDartString());
      if (decoded is! Map) {
        throw const NativeLuaError('script_error', '宿主请求格式不正确');
      }
      final kind = decoded['kind'];
      final name = decoded['name'];
      final arguments = decoded['args'];
      if (kind is! String) {
        throw const NativeLuaError('script_error', '宿主请求缺少类型');
      }
      if (name != null && name is! String) {
        throw const NativeLuaError('script_error', '宿主请求名称格式不正确');
      }
      if (arguments is! List) {
        throw const NativeLuaError('script_error', '宿主请求参数格式不正确');
      }
      final value = handler(engine, kind, name as String?, arguments);
      _writeCallbackValue(result, jsonEncode(_wireValue(value)));
      return 0;
    } on NativeLuaError catch (failure) {
      _writeCallbackValue(
        error,
        jsonEncode({
          'code': failure.code,
          'message': failure.message,
          'details': failure.details,
        }),
      );
      return 1;
    } catch (failure) {
      _writeCallbackValue(
        error,
        jsonEncode({
          'code': 'script_error',
          'message': '$failure',
          'details': null,
        }),
      );
      return 1;
    }
  }

  void _writeCallbackValue(Pointer<Pointer<Utf8>> target, String value) {
    target.value = value.toNativeUtf8(allocator: malloc);
  }

  Never _throwError(String? raw) {
    if (raw == null) {
      throw const NativeLuaError('script_error', 'Lua 执行失败');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['code'] is! String ||
        decoded['message'] is! String) {
      throw NativeLuaError('script_error', raw);
    }
    throw NativeLuaError(
      decoded['code'] as String,
      decoded['message'] as String,
      decoded['details'],
    );
  }

  Object? _decodeJson(String? value) {
    if (value == null) return null;
    try {
      return jsonDecode(value);
    } on FormatException catch (failure) {
      throw NativeLuaError('script_error', 'Lua 返回了无效 JSON：$failure');
    }
  }

  String? _readAndFree(Pointer<Utf8> pointer) {
    if (pointer == nullptr) return null;
    final value = pointer.toDartString();
    bitreeLuaFree(pointer.cast<Void>());
    return value;
  }
}

Object? _wireValue(Object? value) => switch (value) {
  null => null,
  final bool value => value,
  final num value when value.isFinite => value,
  final String value => value,
  final DateTime value => value.toIso8601String(),
  final List value => [for (final item in value) _wireValue(item)],
  final Map value => {
    for (final entry in value.entries) '${entry.key}': _wireValue(entry.value),
  },
  _ => throw NativeLuaError(
    'invalid_result',
    '不能传给 Lua 的值：${value.runtimeType}',
  ),
};

Set<String> _strings(Object? value) => {
  for (final item in value as List) item as String,
};
