// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef BitreeLuaHostCallbackNative = Int32 Function(
  Pointer<Void> engine,
  Pointer<Utf8> request,
  Pointer<Pointer<Utf8>> result,
  Pointer<Pointer<Utf8>> error,
);

@Native<
  Int32 Function(
    Pointer<Utf8> source,
    Pointer<Utf8> fileName,
    Pointer<Utf8> requiredOperations,
    Pointer<Utf8> baseSteps,
    Int32 timeoutMs,
    Pointer<Pointer<Utf8>> info,
    Pointer<Pointer<Utf8>> error,
  )
>(symbol: 'bitree_lua_inspect')
external int bitreeLuaInspect(
  Pointer<Utf8> source,
  Pointer<Utf8> fileName,
  Pointer<Utf8> requiredOperations,
  Pointer<Utf8> baseSteps,
  int timeoutMs,
  Pointer<Pointer<Utf8>> info,
  Pointer<Pointer<Utf8>> error,
);

@Native<
  Int32 Function(
    Pointer<Utf8> source,
    Pointer<Utf8> fileName,
    Pointer<Utf8> operation,
    Pointer<Utf8> query,
    Pointer<Utf8> context,
    Pointer<NativeFunction<BitreeLuaHostCallbackNative>> host,
    Pointer<Int32> cancel,
    Int32 timeoutMs,
    Pointer<Pointer<Void>> execution,
    Pointer<Pointer<Utf8>> yield,
    Pointer<Pointer<Utf8>> result,
    Pointer<Pointer<Utf8>> error,
  )
>(symbol: 'bitree_lua_execute_start')
external int bitreeLuaExecuteStart(
  Pointer<Utf8> source,
  Pointer<Utf8> fileName,
  Pointer<Utf8> operation,
  Pointer<Utf8> query,
  Pointer<Utf8> context,
  Pointer<NativeFunction<BitreeLuaHostCallbackNative>> host,
  Pointer<Int32> cancel,
  int timeoutMs,
  Pointer<Pointer<Void>> execution,
  Pointer<Pointer<Utf8>> yield,
  Pointer<Pointer<Utf8>> result,
  Pointer<Pointer<Utf8>> error,
);

@Native<
  Int32 Function(
    Pointer<Void> execution,
    Pointer<Utf8> value,
    Pointer<Utf8> error,
    Pointer<Pointer<Utf8>> yield,
    Pointer<Pointer<Utf8>> result,
    Pointer<Pointer<Utf8>> errorOut,
  )
>(symbol: 'bitree_lua_execute_resume')
external int bitreeLuaExecuteResume(
  Pointer<Void> execution,
  Pointer<Utf8> value,
  Pointer<Utf8> error,
  Pointer<Pointer<Utf8>> yield,
  Pointer<Pointer<Utf8>> result,
  Pointer<Pointer<Utf8>> errorOut,
);

@Native<
  Int32 Function(
    Pointer<Utf8> source,
    Pointer<Utf8> fileName,
    Pointer<Utf8> data,
    Pointer<Int32> cancel,
    Int32 timeoutMs,
    Pointer<Pointer<Utf8>> result,
    Pointer<Pointer<Utf8>> error,
  )
>(symbol: 'bitree_lua_filter')
external int bitreeLuaFilter(
  Pointer<Utf8> source,
  Pointer<Utf8> fileName,
  Pointer<Utf8> data,
  Pointer<Int32> cancel,
  int timeoutMs,
  Pointer<Pointer<Utf8>> result,
  Pointer<Pointer<Utf8>> error,
);

@Native<
  Int32 Function(
    Pointer<Void> engine,
    Pointer<Utf8> name,
    Pointer<Utf8> arguments,
    Pointer<Pointer<Utf8>> result,
    Pointer<Pointer<Utf8>> error,
  )
>(symbol: 'bitree_lua_call_step')
external int bitreeLuaCallStep(
  Pointer<Void> engine,
  Pointer<Utf8> name,
  Pointer<Utf8> arguments,
  Pointer<Pointer<Utf8>> result,
  Pointer<Pointer<Utf8>> error,
);

@Native<Void Function(Pointer<Void>)>(symbol: 'bitree_lua_execution_free')
external void bitreeLuaExecutionFree(Pointer<Void> execution);

@Native<Void Function(Pointer<Void>)>(symbol: 'bitree_lua_free')
external void bitreeLuaFree(Pointer<Void> value);
