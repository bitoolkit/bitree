// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

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

@Native<Void Function(Pointer<Void>)>(symbol: 'bitree_lua_free')
external void bitreeLuaFree(Pointer<Void> value);
