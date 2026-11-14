# Native Lua display filter

`bitree_lua` embeds official C Lua 5.5.1 for the application's local
`filter(data)` function. It does not discover courses or provide source modules,
HTTP, sessions, storage, extension loading, or host callbacks.

The application passes a JSON snapshot of already saved timetable courses,
deadlines, events and exams. The filter returns JSON display data; the
application validates it and leaves the saved records unchanged. The Dart
wrapper lives in `lib/automation/native_lua.dart`.

Each call creates and closes a Lua state with a 32 MiB heap limit, an instruction
budget, a wall-clock deadline and a shared cancellation flag. Only base,
`string`, `table`, `math` and `utf8` libraries are exposed. File access, system
commands, dynamic code loading, `require` and coroutines are unavailable.
JSON conversion uses the bundled, unmodified dkjson 2.7 module.

Flutter native assets compile the bridge and vendored Lua sources through
`hook/build.dart`, then bundle the library on supported target platforms. There
is no runtime system-Lua dependency. The C ABI exports only
`bitree_lua_filter` and `bitree_lua_free`. Errors cross the FFI boundary as a
status code and plain UTF-8 text, without JSON encoding.

The Lua source version and archive checksum are recorded in
`third_party/lua/SOURCE.json`; `tool/update_lua.py` updates the vendored sources.
Tests run with `flutter test --no-pub test/native_lua_test.dart
test/lua_filter_test.dart` after dependencies have been resolved.
