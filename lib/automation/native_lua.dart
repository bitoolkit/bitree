import 'dart:convert';
import 'dart:ffi';

import 'package:bitree_lua/native_lua_bindings.dart';
import 'package:ffi/ffi.dart';

class NativeLuaError implements Exception {
  const NativeLuaError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// A cancellation flag shared with the worker's native instruction hook.
class NativeLuaCancellation {
  NativeLuaCancellation() : _pointer = calloc<Int32>(), _owned = true;

  NativeLuaCancellation.fromAddress(int address)
    : _pointer = Pointer<Int32>.fromAddress(address),
      _owned = false;

  final Pointer<Int32> _pointer;
  final bool _owned;
  var _disposed = false;

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

/// JSON-only boundary to a fresh C Lua state with no host callbacks.
class NativeLuaLibrary {
  NativeLuaLibrary._();

  static final _shared = NativeLuaLibrary._();

  factory NativeLuaLibrary.open() => _shared;

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
        cancellation == null
            ? nullptr.cast<Int32>()
            : Pointer<Int32>.fromAddress(cancellation.address),
        timeoutMs,
        resultPointer,
        errorPointer,
      );
      final result = _readAndFree(resultPointer.value);
      final error = _readAndFree(errorPointer.value);
      if (status != 0) {
        // Status values are declared in bitree_lua.h.
        final code = switch (status) {
          2 => 'cancelled',
          3 => 'timeout',
          4 => 'memory_limit',
          _ => 'script_error',
        };
        throw NativeLuaError(code, error ?? 'Lua 执行失败');
      }
      return result == null ? null : jsonDecode(result);
    } finally {
      malloc.free(sourcePointer);
      malloc.free(fileNamePointer);
      malloc.free(dataPointer);
      calloc.free(resultPointer);
      calloc.free(errorPointer);
    }
  }

  String? _readAndFree(Pointer<Utf8> pointer) {
    if (pointer == nullptr) return null;
    final value = pointer.toDartString();
    bitreeLuaFree(pointer.cast<Void>());
    return value;
  }
}
